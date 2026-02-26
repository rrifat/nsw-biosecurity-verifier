# Rule Traceability Matrix

This document maps implemented logic to the scoped NSW NLIS regulatory clauses used in this prototype.

## Scope Notice

This project intentionally implements only:

- R1.1 (NSW Clause 32(1))
- R2.4 (NSW Clause 17(3))
- R2.5 (NSW Clause 17(4)(b))

No additional clauses are interpreted or enforced.

## Rule-to-Code Mapping

### R1.1 - Delivery Information Completeness

- Regulatory source: NSW Clause 32(1)
- File: `lib/verify.ex`
- Functions:
  - `evaluate_delivery_info_rule/1`
  - `delivery_info_complete?/1`
  - `non_empty_string?/1`

Decision logic:

- PASS when required fields are present and valid
- FAIL with `INCOMPLETE_DELIVERY_INFO` otherwise

Severity:

- medium

---

### R2.4 - PIC Attachment Locality

- Regulatory source: NSW Clause 17(3)
- Files:
  - `lib/verify.ex`
  - `lib/pic_validator.ex`
- Functions:
  - `evaluate_pic_attachment_rule/1`
  - `PicValidator.valid?/1`
  - `PicValidator.validate/1`

Decision logic:

- FAIL `INVALID_PIC_ON_DEVICE` if `identifier.pic_on_device` invalid
- FAIL `INVALID_PREVIOUS_PROPERTY_PIC` if `movement.previous_property_pic` invalid
- FAIL `PIC_ATTACHMENT_MISMATCH` if both valid but unequal
- PASS if both valid and equal

Severity:

- high

---

### R2.5 - eID Mandate for Sheep/Goats

- Regulatory source: NSW Clause 17(4)(b)
- File: `lib/verify.ex`
- Function:
  - `evaluate_eid_mandate_rule/1`

Decision logic:

- PASS when sheep/goat born on or after 2025-01-01 has `electronic_device`
- FAIL `NON_COMPLIANT_EID_MISSING` when mandated and not electronic
- NOT_APPLICABLE for non-sheep/goat or pre-mandate birth date

Severity (on failure):

- high

## Output Field Semantics

Each event output contains `rules_evaluated` with one entry per scoped rule.

For each rule entry:

- `result` in `PASS | FAIL | NOT_APPLICABLE`
- `failure_reason` is:
  - string code on FAIL
  - `null` on PASS or NOT_APPLICABLE

This behavior is implemented in `rule_result_to_output/1` in `lib/verify.ex`.

## Enforcement Flag Mapping

Current implementation maps rule outcomes to operational flags:

- Any high-severity fail -> `BLOCK_MOVEMENT`
- Any medium-severity fail -> `LOG_BREACH`
- No failures -> `NOTIFY_OPERATOR`

These flags are produced by `build_enforcement_flags/1` in `lib/verify.ex`.
