# run.exs - entry point: mix run run.exs
# Generates 100 NLIS events, runs verification, writes data/results.json, prints summary

GenerateEvents.run()
results = Verify.run()

File.mkdir_p!("data")
File.write!("data/results.json", Jason.encode!(results, pretty: true))

total = length(results)
compliant_count = Enum.count(results, & &1["is_compliant"])
non_compliant_count = total - compliant_count

delivery_info_failures = Enum.count(results, fn result ->
  Enum.any?(result["rules_evaluated"], fn rule ->
    rule["rule_id"] == "R1.1" and rule["result"] == "FAIL"
  end)
end)
pic_attachment_failures = Enum.count(results, fn result ->
  Enum.any?(result["rules_evaluated"], fn rule ->
    rule["rule_id"] == "R2.4" and rule["result"] == "FAIL"
  end)
end)
eid_mandate_failures = Enum.count(results, fn result ->
  Enum.any?(result["rules_evaluated"], fn rule ->
    rule["rule_id"] == "R2.5" and rule["result"] == "FAIL"
  end)
end)

IO.puts("Total events: #{total}")
IO.puts("Compliant: #{compliant_count}")
IO.puts("Non-compliant: #{non_compliant_count}")
IO.puts(
  "Per-rule failure counts: R1.1=#{delivery_info_failures}, R2.4=#{pic_attachment_failures}, R2.5=#{eid_mandate_failures}"
)
IO.puts("")
IO.puts("Sample of 3 failing events (full output schema):")

failing = Enum.filter(results, &(!&1["is_compliant"])) |> Enum.take(3)
Enum.each(failing, fn r -> IO.inspect(r, pretty: true, limit: :infinity) end)

IO.puts("")
IO.puts("Wrote data/results.json")
