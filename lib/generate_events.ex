defmodule GenerateEvents do
  @moduledoc """
  Loads or generates events and parses all ISO8601 date strings to Date structs
  at ingestion time (before rule evaluation). Uses pattern matching only.
  """

  def from_json_string(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> ingest(data)
      {:error, _} = err -> err
    end
  end

  def from_list(raw_list) when is_list(raw_list), do: ingest(raw_list)

  def from_list(_), do: {:error, :not_a_list}

  def sample_events do
    [
      %{"date" => "2025-02-01", "pic" => "AB123456", "type" => "movement"},
      %{"date" => "2025-02-15", "pic" => "XY987654", "type" => "inspection"},
      %{"date" => "2025-02-26", "pic" => "CD000000", "type" => "movement"}
    ]
    |> ingest()
  end

  defp ingest(raw) when is_list(raw) do
    results =
      Enum.map(raw, &ingest_event/1)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    case errors do
      [] -> {:ok, Enum.map(results, fn {:ok, e} -> e end)}
      _ -> {:error, errors}
    end
  end

  defp ingest(map) when is_map(map) do
    ingest([map])
  end

  defp ingest(_), do: {:error, :invalid_input}

  defp ingest_event(%{"date" => date_str, "pic" => pic, "type" => type})
       when is_binary(date_str) and is_binary(pic) and is_binary(type) do
    date = Date.from_iso8601!(date_str)

    {:ok,
     %{
       date: date,
       pic: pic,
       type: String.to_atom(type)
     }}
  end

  defp ingest_event(%{"date" => date_str, "pic" => pic} = m)
       when is_binary(date_str) and is_binary(pic) do
    date = Date.from_iso8601!(date_str)
    type = (m["type"] || "event") |> to_string() |> String.to_atom()

    {:ok,
     %{
       date: date,
       pic: pic,
       type: type
     }}
  end

  defp ingest_event(%{"date" => date_str} = m) when is_binary(date_str) do
    date = Date.from_iso8601!(date_str)
    type = (m["type"] || "event") |> to_string() |> String.to_atom()

    {:ok,
     %{
       date: date,
       pic: Map.get(m, "pic", ""),
       type: type
     }}
  end

  defp ingest_event(%{"date" => _}), do: {:error, :invalid_date}
  defp ingest_event(%{date: _}), do: {:error, :use_iso8601_strings}
  defp ingest_event(_), do: {:error, :missing_date}
end
