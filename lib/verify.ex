defmodule Verify do
  @moduledoc """
  NLIS rule engine: loads data/events.json, ingests (parses ISO8601 to Date/DateTime),
  evaluates R1.1, R2.4, R2.5, returns list of results per output schema.
  Uses pattern matching and function clauses only.
  """

  @eid_mandate_date ~D[2025-01-01]

  def run do
    raw_events = File.read!("data/events.json") |> Jason.decode!()
    ingested_events = Enum.map(raw_events, &ingest_event/1)
    Enum.map(ingested_events, &evaluate_event/1)
  end

  defp ingest_event(raw) when is_map(raw) do
    timestamp =
      case DateTime.from_iso8601(raw["timestamp"]) do
        {:ok, dt, _offset} -> dt
        {:error, _} -> raise "invalid timestamp: #{raw["timestamp"]}"
      end
    birth_date = raw["stock_details"]["birth_date"] |> Date.from_iso8601!()
    departure_date = raw["movement"]["departure_date"] |> Date.from_iso8601!()

    %{
      event_id: raw["event_id"],
      timestamp: timestamp,
      stock_details: %{
        species: raw["stock_details"]["species"],
        count: raw["stock_details"]["count"],
        birth_date: birth_date,
        bred_on_previous_property: raw["stock_details"]["bred_on_previous_property"]
      },
      identifier: %{
        device_type: raw["identifier"]["device_type"],
        pic_on_device: raw["identifier"]["pic_on_device"],
        is_readable: raw["identifier"]["is_readable"],
        is_working: raw["identifier"]["is_working"],
        is_nlis_accredited: raw["identifier"]["is_nlis_accredited"]
      },
      movement: %{
        departure_date: departure_date,
        previous_property_pic: raw["movement"]["previous_property_pic"],
        destination_property_pic: raw["movement"]["destination_property_pic"],
        movement_document_id: raw["movement"]["movement_document_id"],
        destination_type: raw["movement"]["destination_type"]
      },
      responsible_persons: %{
        owner_name: raw["responsible_persons"]["owner_name"],
        owner_address: raw["responsible_persons"]["owner_address"],
        person_in_charge: raw["responsible_persons"]["person_in_charge"]
      }
    }
  end

  defp evaluate_event(ingested) do
    delivery_info_result = evaluate_delivery_info_rule(ingested)
    pic_attachment_result = evaluate_pic_attachment_rule(ingested)
    eid_mandate_result = evaluate_eid_mandate_rule(ingested)

    rule_outcomes = [delivery_info_result, pic_attachment_result, eid_mandate_result]
    passed_count = Enum.count(rule_outcomes, &match?({:pass, _, _, _}, &1))
    failed_count = Enum.count(rule_outcomes, &match?({:fail, _, _, _, _, _}, &1))
    critical_failures_count = Enum.count(rule_outcomes, &match?({:fail, _, _, _, _, :high}, &1))

    is_compliant = failed_count == 0
    validation_timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    rules_evaluated = Enum.map(rule_outcomes, &rule_result_to_output/1)

    enforcement_flags = build_enforcement_flags(rule_outcomes)

    %{
      "event_id" => ingested.event_id,
      "is_compliant" => is_compliant,
      "validation_timestamp" => validation_timestamp,
      "rules_evaluated" => rules_evaluated,
      "compliance_summary" => %{
        "total_rules_evaluated" => length(rule_outcomes),
        "passed" => passed_count,
        "failed" => failed_count,
        "critical_failures" => critical_failures_count
      },
      "enforcement_flags" => enforcement_flags
    }
  end

  defp rule_result_to_output({:pass, rule_id, _desc, regulatory_source}) do
    %{
      "rule_id" => rule_id,
      "rule_description" => rule_description(rule_id),
      "result" => "PASS",
      "failure_reason" => nil,
      "regulatory_source" => regulatory_source
    }
  end

  defp rule_result_to_output({:fail, rule_id, _desc, regulatory_source, failure_reason, _severity}) do
    %{
      "rule_id" => rule_id,
      "rule_description" => rule_description(rule_id),
      "result" => "FAIL",
      "failure_reason" => failure_reason,
      "regulatory_source" => regulatory_source
    }
  end

  defp rule_result_to_output({:not_applicable, rule_id, _desc, regulatory_source}) do
    %{
      "rule_id" => rule_id,
      "rule_description" => rule_description(rule_id),
      "result" => "NOT_APPLICABLE",
      "failure_reason" => nil,
      "regulatory_source" => regulatory_source
    }
  end

  defp rule_description("R1.1"), do: "Delivery Information Completeness"
  defp rule_description("R2.4"), do: "PIC Attachment Locality"
  defp rule_description("R2.5"), do: "eID Mandate for Sheep/Goats"

  defp build_enforcement_flags(rules_results) do
    has_high = Enum.any?(rules_results, &match?({:fail, _, _, _, _, :high}, &1))
    has_medium = Enum.any?(rules_results, &match?({:fail, _, _, _, _, :medium}, &1))

    flags = []
    flags = case has_high do true -> ["BLOCK_MOVEMENT" | flags]; false -> flags end
    flags = case has_medium do true -> ["LOG_BREACH" | flags]; false -> flags end
    flags = case has_high || has_medium do false -> ["NOTIFY_OPERATOR" | flags]; true -> flags end
    Enum.reverse(flags)
  end

  # --- R1.1 NSW Clause 32(1) — Delivery Information Completeness ---
  defp evaluate_delivery_info_rule(ingested) do
    case delivery_info_complete?(ingested) do
      :ok -> {:pass, "R1.1", "Delivery Information Completeness", "NSW Clause 32(1)"}
      {:fail, reason} -> {:fail, "R1.1", "Delivery Information Completeness", "NSW Clause 32(1)", reason, :medium}
    end
  end

  defp delivery_info_complete?(ingested) do
    stock_details = ingested.stock_details
    movement_details = ingested.movement
    responsible_people = ingested.responsible_persons

    case {non_empty_string?(stock_details.species), is_integer(stock_details.count) and stock_details.count > 0,
          non_empty_string?(movement_details.previous_property_pic), non_empty_string?(movement_details.movement_document_id),
          non_empty_string?(responsible_people.owner_name), non_empty_string?(responsible_people.owner_address)} do
      {true, true, true, true, true, true} -> :ok
      _ -> {:fail, "INCOMPLETE_DELIVERY_INFO"}
    end
  end

  defp non_empty_string?(nil), do: false
  defp non_empty_string?(value) when is_binary(value), do: byte_size(value) > 0
  defp non_empty_string?(_), do: false

  # --- R2.4 NSW Clause 17(3) — PIC Attachment Locality ---
  defp evaluate_pic_attachment_rule(%{identifier: %{pic_on_device: pic_on_device}, movement: %{previous_property_pic: previous_property_pic}}) do
    case {PicValidator.valid?(pic_on_device), PicValidator.valid?(previous_property_pic), pic_on_device == previous_property_pic} do
      {false, _, _} -> {:fail, "R2.4", "PIC Attachment Locality", "NSW Clause 17(3)", "INVALID_PIC_ON_DEVICE", :high}
      {_, false, _} -> {:fail, "R2.4", "PIC Attachment Locality", "NSW Clause 17(3)", "INVALID_PREVIOUS_PROPERTY_PIC", :high}
      {true, true, false} -> {:fail, "R2.4", "PIC Attachment Locality", "NSW Clause 17(3)", "PIC_ATTACHMENT_MISMATCH", :high}
      {true, true, true} -> {:pass, "R2.4", "PIC Attachment Locality", "NSW Clause 17(3)"}
    end
  end

  # --- R2.5 NSW Clause 17(4)(b) — eID Mandate for Sheep/Goats ---
  defp evaluate_eid_mandate_rule(%{stock_details: %{species: species, birth_date: birth_date}, identifier: %{device_type: device_type}}) do
    case {species, Date.compare(birth_date, @eid_mandate_date), device_type} do
      {"sheep", cmp, "electronic_device"} when cmp in [:eq, :gt] -> {:pass, "R2.5", "eID Mandate for Sheep/Goats", "NSW Clause 17(4)(b)"}
      {"goat", cmp, "electronic_device"} when cmp in [:eq, :gt] -> {:pass, "R2.5", "eID Mandate for Sheep/Goats", "NSW Clause 17(4)(b)"}
      {"sheep", cmp, _} when cmp in [:eq, :gt] -> {:fail, "R2.5", "eID Mandate for Sheep/Goats", "NSW Clause 17(4)(b)", "NON_COMPLIANT_EID_MISSING", :high}
      {"goat", cmp, _} when cmp in [:eq, :gt] -> {:fail, "R2.5", "eID Mandate for Sheep/Goats", "NSW Clause 17(4)(b)", "NON_COMPLIANT_EID_MISSING", :high}
      _ -> {:not_applicable, "R2.5", "eID Mandate for Sheep/Goats", "NSW Clause 17(4)(b)"}
    end
  end
end
