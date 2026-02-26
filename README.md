# NSW NLIS Compliance Verifier

Research prototype for verifying selected NSW NLIS livestock movement compliance rules from the NSW Biosecurity (NLIS) Regulation 2017 (as amended 2024).

This is a single-run, file-based verifier implemented as a plain Mix project (no Phoenix, no Ecto, no OTP runtime services).

## Purpose

This project demonstrates an auditable, deterministic rule-evaluation pipeline that:

- generates synthetic NLIS movement events,
- injects controlled non-compliance cases,
- verifies each event against bounded regulatory checks, and
- outputs per-event compliance decisions and summaries in JSON.

The target audience is MRes supervision and research review: the design favors transparency and traceability over framework complexity.

## Scope and Boundaries

Implemented scope is intentionally narrow and fixed:

- Input schema is the movement-event schema described in project requirements.
- Rules implemented: `R1.1`, `R2.4`, `R2.5` only.
- PIC validation implemented for NA-NZ prefixes excluding NI.
- Output schema includes per-rule outcome, event summary, and enforcement flags.

Out of scope:

- No external API integration
- No frontend
- No database persistence
- No workflow orchestration beyond local script execution
- No additional regulatory clauses beyond R1.1/R2.4/R2.5

## Technology Stack

- Elixir `~> 1.16`
- Mix project
- `Jason ~> 1.4` for JSON encoding/decoding

## Project Structure

- `mix.exs` - project definition and dependencies
- `lib/pic_validator.ex` - PIC format validation and valid PIC generation helpers
- `lib/generate_events.ex` - synthetic event generation (100 events total)
- `lib/verify.ex` - ingestion + rule engine + output object construction
- `run.exs` - entry point to execute full pipeline
- `data/events.json` - generated test events
- `data/results.json` - verification output

## End-to-End Flow

1. `run.exs` calls `GenerateEvents.run/0`.
2. `GenerateEvents` builds:
   - 85 compliant events
   - 5 R1.1 violations
   - 5 R2.4 violations
   - 5 R2.5 violations
3. Events are written to `data/events.json`.
4. `run.exs` calls `Verify.run/0`.
5. `Verify` ingests events and parses dates before rule evaluation:
   - `Date.from_iso8601!/1` for date fields
   - `DateTime.from_iso8601/1` for timestamp
6. Each event is evaluated against all three rules.
7. Results are written to `data/results.json`.
8. `run.exs` prints summary counts and sample failing events.

## Regulatory Rule Coverage

### R1.1 - NSW Clause 32(1) - Delivery Information Completeness

Checks required delivery information fields are present and valid:

- `stock_details.species` non-empty
- `stock_details.count > 0`
- `movement.previous_property_pic` non-empty
- `movement.movement_document_id` non-empty / non-null
- `responsible_persons.owner_name` non-empty
- `responsible_persons.owner_address` non-empty

Failure reason: `INCOMPLETE_DELIVERY_INFO`  
Severity: medium

### R2.4 - NSW Clause 17(3) - PIC Attachment Locality

Checks:

- both PIC values are valid format (`validate/1` in `PicValidator`)
- `identifier.pic_on_device == movement.previous_property_pic`

Failure reasons:

- `INVALID_PIC_ON_DEVICE`
- `INVALID_PREVIOUS_PROPERTY_PIC`
- `PIC_ATTACHMENT_MISMATCH`

Severity: high

### R2.5 - NSW Clause 17(4)(b) - eID Mandate for Sheep/Goats

Checks:

- if species is sheep or goat and birth date is on/after `2025-01-01`,
- then device type must be `electronic_device`

Possible outcomes:

- `PASS`
- `FAIL` with `NON_COMPLIANT_EID_MISSING`
- `NOT_APPLICABLE` (non-sheep/goat or pre-mandate birth date)

Severity on failure: high

## PIC Validation Rules

Implemented in `lib/pic_validator.ex`:

- exactly 8 characters
- alphanumeric only
- first 2 chars in allowed set:
  `NA, NB, NC, ND, NE, NF, NG, NH, NJ, NK, NL, NM, NN, NP, NQ, NR, NS, NT, NU, NV, NW, NX, NY, NZ`

`NI` is intentionally excluded.

## Expected Output Behavior

Per run, generated data should produce:

- Total events: `100`
- Compliant events: `85`
- Non-compliant events: `15`
- Rule failure counts:
  - R1.1 = 5
  - R2.4 = 5
  - R2.5 = 5

Each event in `data/results.json` includes:

- `event_id`
- `is_compliant`
- `validation_timestamp`
- `rules_evaluated` (3 rule outputs)
- `compliance_summary`
- `enforcement_flags`

`failure_reason` is:

- a reason string only when a rule fails,
- `null` for `PASS` or `NOT_APPLICABLE`.

## How to Run

From project root:

```bash
mix deps.get
mix run run.exs
```

Then inspect:

- `data/events.json`
- `data/results.json`

## Reproducibility Notes

- Counts are deterministic by construction (85/15 split).
- Field values are randomly generated each run (`Enum.random`, `:rand.uniform`, crypto bytes for IDs).
- Therefore IDs and specific event contents change run-to-run, while aggregate rule-failure counts remain stable.

## Design Constraints Followed

- Pattern matching and function clauses used in rule/generator logic.
- No if/else chains in core rule checks.
- ISO8601 parsing performed before rule evaluation.
- Single-run script execution model.
- No GenServer, Supervisor, or Application runtime behavior used for processing.

## Supporting Documentation

- `docs/rule-traceability.md` - clause-to-code mapping and outcome semantics
- `docs/verification-methodology.md` - data generation, evaluation workflow, and interpretation guidance

## Known Limitations

- Synthetic data only; no direct integration with production NLIS event sources.
- Timestamp parsing uses `DateTime.from_iso8601/1` with explicit case handling (runtime-safe, but not bang form).
- Enforcement flags are heuristic mappings from rule severities, not an external policy engine.
