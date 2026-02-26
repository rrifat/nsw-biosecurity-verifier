# Verification Methodology

This document describes how the prototype generates data, ingests data, evaluates rules, and produces outputs for analysis.

## 1) Synthetic Dataset Generation

Implemented in `lib/generate_events.ex`.

Per run, exactly 100 events are generated:

- 85 compliant
- 15 non-compliant:
  - 5 R1.1 failures (`movement_document_id` set to `null`)
  - 5 R2.4 failures (valid PICs, but `pic_on_device != previous_property_pic`)
  - 5 R2.5 failures (sheep/goat, post-mandate birth date, non-electronic device)

Events are written to `data/events.json`.

### Why this design?

- Provides known class balance for controlled evaluation.
- Guarantees presence of each failure category for inspection.
- Keeps generation logic local and auditable.

## 2) Ingestion and Type Normalization

Implemented in `lib/verify.ex` (`ingest_event/1`).

Before rule checks:

- `timestamp` is parsed from ISO8601 to `DateTime`
- `stock_details.birth_date` is parsed to `Date`
- `movement.departure_date` is parsed to `Date`

Rule evaluation then operates on typed values rather than raw strings.

## 3) Rule Evaluation

Each event is evaluated against all three scoped rules:

- R1.1 completeness
- R2.4 PIC locality
- R2.5 eID mandate

Outcome tuples are converted to output objects via `rule_result_to_output/1`.

## 4) Event Compliance Decision

Per event:

- `is_compliant = true` only when no rule returns FAIL
- `compliance_summary` records counts of pass/fail/critical
- `enforcement_flags` are derived from rule severities

## 5) Output Artifacts

Generated files:

- `data/events.json` - source test events
- `data/results.json` - per-event verification output

Console output from `run.exs` includes:

- total event count
- compliant/non-compliant counts
- per-rule failure counts
- sample of 3 failing events

## 6) Interpreting Results

Important interpretation points:

- `failure_reason` is only populated for rule entries where `result == "FAIL"`.
- `NOT_APPLICABLE` is valid only for R2.5 in current scope.
- Counts are fixed by construction (85/15 split), but event values vary each run.

## 7) Reproducibility and Validity Notes

- This is a research prototype, not legal advice software.
- Regulatory interpretation is bounded to three explicitly modeled rules.
- Dataset is synthetic and intentionally structured for demonstration/testing.

If strict run-to-run deterministic records are needed, add fixed random seeding and run identifiers in a future iteration.
