defmodule GenerateEvents do
  @moduledoc """
  Generates 100 NSW NLIS movement events: 85 compliant, 15 with injected violations
  (5× R1.1, 5× R2.4, 5× R2.5). Writes data/events.json. Uses pattern matching only.
  """

  @species_list ["sheep", "goat", "cattle", "pig"]
  @device_types ["breeder_device", "post_breeder_device", "electronic_device", "brand"]
  @destination_types ["saleyard", "abattoir", "farm", "depot"]
  @eid_mandate_date ~D[2025-01-01]

  def run do
    File.mkdir_p!("data")

    compliant_events = build_many_compliant_events(85)
    incomplete_delivery_info_events = build_many_r11_violations(5)
    pic_mismatch_events = build_many_r24_violations(5)
    missing_eid_events = build_many_r25_violations(5)

    events =
      compliant_events ++
        incomplete_delivery_info_events ++
        pic_mismatch_events ++
        missing_eid_events

    File.write!("data/events.json", Jason.encode!(events, pretty: true))
    :ok
  end

  defp build_many_compliant_events(0), do: []

  defp build_many_compliant_events(count),
    do: [build_compliant_event() | build_many_compliant_events(count - 1)]

  defp build_many_r11_violations(0), do: []

  defp build_many_r11_violations(count),
    do: [build_r11_violation() | build_many_r11_violations(count - 1)]

  defp build_many_r24_violations(0), do: []

  defp build_many_r24_violations(count),
    do: [build_r24_violation() | build_many_r24_violations(count - 1)]

  defp build_many_r25_violations(0), do: []

  defp build_many_r25_violations(count),
    do: [build_r25_violation() | build_many_r25_violations(count - 1)]

  defp build_compliant_event do
    pic = PicValidator.generate_pic()
    build_event(
      pic_on_device: pic,
      previous_property_pic: pic,
      movement_document_id: "DOC-" <> uuid_fragment(),
      species: Enum.random(@species_list),
      birth_date: random_date_before_or_after(@eid_mandate_date),
      device_type_for_species: :any
    )
  end

  defp build_r11_violation do
    pic = PicValidator.generate_pic()
    build_event(
      pic_on_device: pic,
      previous_property_pic: pic,
      movement_document_id: nil,
      species: Enum.random(@species_list),
      birth_date: random_date_before_or_after(@eid_mandate_date),
      device_type_for_species: :any
    )
  end

  defp build_r24_violation do
    pic_prev = PicValidator.generate_pic()
    pic_device = PicValidator.generate_pic_different_from(pic_prev)
    build_event(
      pic_on_device: pic_device,
      previous_property_pic: pic_prev,
      movement_document_id: "DOC-" <> uuid_fragment(),
      species: Enum.random(@species_list),
      birth_date: random_date_before_or_after(@eid_mandate_date),
      device_type_for_species: :any
    )
  end

  defp build_r25_violation do
    pic = PicValidator.generate_pic()
    species = Enum.random(["sheep", "goat"])
    birth_date = random_date_on_or_after(@eid_mandate_date)
    device_type = Enum.random(["breeder_device", "post_breeder_device", "brand"])
    build_event(
      pic_on_device: pic,
      previous_property_pic: pic,
      movement_document_id: "DOC-" <> uuid_fragment(),
      species: species,
      birth_date: birth_date,
      device_type_for_species: device_type
    )
  end

  defp build_event(opts) do
    pic_on_device = Keyword.fetch!(opts, :pic_on_device)
    previous_property_pic = Keyword.fetch!(opts, :previous_property_pic)
    movement_document_id = Keyword.fetch!(opts, :movement_document_id)
    species = Keyword.fetch!(opts, :species)
    birth_date = Keyword.fetch!(opts, :birth_date)
    device_type_for_species = Keyword.fetch!(opts, :device_type_for_species)

    device_type =
      resolve_device_type(species, birth_date, device_type_for_species)

    departure = Date.utc_today() |> Date.add(-:rand.uniform(30))
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      "event_id" => uuid(),
      "timestamp" => timestamp,
      "stock_details" => %{
        "species" => species,
        "count" => :rand.uniform(50),
        "birth_date" => Date.to_iso8601(birth_date),
        "bred_on_previous_property" => :rand.uniform(2) == 1
      },
      "identifier" => %{
        "device_type" => device_type,
        "pic_on_device" => pic_on_device,
        "is_readable" => true,
        "is_working" => true,
        "is_nlis_accredited" => true
      },
      "movement" => %{
        "departure_date" => Date.to_iso8601(departure),
        "previous_property_pic" => previous_property_pic,
        "destination_property_pic" => PicValidator.generate_pic(),
        "movement_document_id" => movement_document_id,
        "destination_type" => Enum.random(@destination_types)
      },
      "responsible_persons" => %{
        "owner_name" => "Owner " <> uuid_fragment(),
        "owner_address" => "123 Rural Rd, NSW",
        "person_in_charge" => "Driver " <> uuid_fragment()
      }
    }
  end

  defp resolve_device_type("sheep", birth_date, device_type)
       when is_struct(birth_date, Date) do
    resolve_device_type_for_species(birth_date, device_type)
  end

  defp resolve_device_type("goat", birth_date, device_type)
       when is_struct(birth_date, Date) do
    resolve_device_type_for_species(birth_date, device_type)
  end

  defp resolve_device_type(_species, _birth_date, device_type)
       when is_binary(device_type),
       do: device_type

  defp resolve_device_type(_species, _birth_date, :any),
    do: Enum.random(@device_types)

  defp resolve_device_type_for_species(birth_date, :any) do
    case Date.compare(birth_date, @eid_mandate_date) do
      :lt -> Enum.random(@device_types)
      _ -> "electronic_device"
    end
  end

  defp resolve_device_type_for_species(_birth_date, device_type)
       when is_binary(device_type),
       do: device_type

  defp random_date_before_or_after(cutoff) do
    case :rand.uniform(2) do
      1 -> Date.add(cutoff, -:rand.uniform(365))
      2 -> Date.add(cutoff, :rand.uniform(365))
    end
  end

  defp random_date_on_or_after(cutoff), do: Date.add(cutoff, :rand.uniform(60))

  defp uuid do
    b = :crypto.strong_rand_bytes(16)
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = b
    [
      Integer.to_string(u0, 16) |> String.pad_leading(8, "0"),
      Integer.to_string(u1, 16) |> String.pad_leading(4, "0"),
      Integer.to_string(u2, 16) |> String.pad_leading(4, "0"),
      Integer.to_string(u3, 16) |> String.pad_leading(4, "0"),
      Integer.to_string(u4, 16) |> String.pad_leading(12, "0")
    ]
    |> Enum.join("-")
  end

  defp uuid_fragment do
    Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end
end
