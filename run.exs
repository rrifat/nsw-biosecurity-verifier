# run.exs - entry point: mix run run.exs
# Loads events (with ISO8601 -> Date at ingestion), runs rule engine, writes results.json

alias GenerateEvents
alias Verify
alias PicValidator

events_result =
  GenerateEvents.sample_events()

{events, rules} =
  case events_result do
    {:ok, evs} ->
      today = Date.utc_today()
      from = Date.add(today, -30)
      to = Date.add(today, 30)

      rules = [
        :valid_pic,
        {:date_in_range, from: from, to: to},
        {:type_allowed, [:movement, :inspection]}
      ]

      {evs, rules}

    {:error, reason} ->
      IO.puts("Failed to load events: #{inspect(reason)}")
      System.halt(1)
  end

results = Verify.run(events, rules)

encodable_results =
  Enum.map(results, fn r ->
    %{
      "event" => %{
        "date" => Date.to_iso8601(r.event.date),
        "pic" => r.event.pic,
        "type" => to_string(r.event.type)
      },
      "passed" => r.passed,
      "results" =>
        Enum.map(r.results, fn
          {:pass, tag} -> %{"outcome" => "pass", "rule" => to_string(tag)}
          {:fail, reason} -> %{"outcome" => "fail", "reason" => inspect(reason)}
        end)
    }
  end)

output = %{
  "summary" => %{
    "total" => length(results),
    "passed" => Enum.count(results, & &1.passed),
    "failed" => Enum.count(results, &(!&1.passed))
  },
  "results" => encodable_results
}

json = Jason.encode!(output, pretty: true)
File.write!("results.json", json)
IO.puts("Wrote results.json")
