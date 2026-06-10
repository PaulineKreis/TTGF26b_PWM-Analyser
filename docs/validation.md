# Validation

This document validates that each requirement defined in
[`specification.md`](specification.md) is correctly and meaningfully formulated
according to the SMART criteria:

- **S**pecific: The requirement is stated precisely and unambiguously.
- **M**easurable: The requirement can be verified by an objective method.
- **A**tomic: The requirement specifies exactly one function or property.
- **R**elevant: The requirement is aligned with the overall project objectives.
- **T**ime-bound: The requirement is realistically achievable within the project scope.

---

## V1 — Frequency Measurement

**Requirement:** [R1 — PWM Frequency Measurement](specification.md#r1--pwm-frequency-measurement)

| Criterion | Assessment |
|-----------|------------|
| Specific  | The measurement range is explicitly stated as 1 kHz to 9999 kHz. |
| Measurable | The range boundaries are numeric and unambiguous; compliance can be verified by simulation. |
| Atomic | Specifies only the measurement range, nothing else. |
| Relevant | Frequency measurement is a core function of a PWM analyser. |
| Time-bound | Achievable within the project scope using a counter-based approach. |

---

## V2 — Frequency Display

**Requirement:** [R2 — Frequency Display](specification.md#r2--frequency-display)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Specifies a decimal integer representation on a 4-digit 7-segment display. |
| Measurable | The output format (decimal integer, 4 digits) is objectively verifiable. |
| Atomic | Addresses only the display format of the frequency value. |
| Relevant | Without a display, the measurement result is not accessible to the user. |
| Time-bound | Straightforward to implement with the existing SevenSegmentDecoder module. |

---

## V3 — Low-Frequency Indication

**Requirement:** [R3 — Low-Frequency Indication](specification.md#r3--low-frequency-indication)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Defines the exact display string ("Lo") and the trigger condition (below 1 kHz). |
| Measurable | The threshold (1 kHz) and the expected display output ("Lo") are objectively verifiable. |
| Atomic | Covers only the below-range indication, separate from the Hi and Err cases. |
| Relevant | Informs the user that the signal is outside the measurable range. |
| Time-bound | Implementable as a status flag from the frequency counter. |

---

## V4 — High-Frequency Indication

**Requirement:** [R4 — High-Frequency Indication](specification.md#r4--high-frequency-indication)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Defines the exact display string ("Hi") and the trigger condition (above 9999 kHz). |
| Measurable | The threshold (9999 kHz) and the expected display output ("Hi") are objectively verifiable. |
| Atomic | Covers only the above-range indication, separate from Lo and Err. |
| Relevant | Symmetric counterpart to R3; both are necessary for complete range indication. |
| Time-bound | Implementable as a status flag from the frequency counter, analogous to R3. |

---

## V5 — Missing-Signal Detection

**Requirement:** [R5 — Missing-Signal Detection](specification.md#r5--missing-signal-detection)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Defines the exact timeout condition (no edge transition for more than 50 ms) and the display output ("Err"). |
| Measurable | The 50 ms threshold is a concrete, numeric value verifiable by simulation. |
| Atomic | Addresses only the missing-signal case, not the out-of-range cases covered by R3 and R4. |
| Relevant | Essential for distinguishing a valid low-frequency signal from a disconnected or broken input. |
| Time-bound | Implementable with a timeout counter alongside the existing frequency counter. |

---

## V6 — Duty Cycle Measurement

**Requirement:** [R6 — Duty Cycle Measurement](specification.md#r6--duty-cycle-measurement)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Specifies the resolution (0.01), the range (0.00 to 1.00), and the unit (dimensionless ratio). |
| Measurable | Resolution and range are numeric and verifiable by simulation with known input stimuli. |
| Atomic | Addresses only duty cycle measurement, independent of frequency measurement (R1). |
| Relevant | Duty cycle is the second core measurement of a PWM analyser. |
| Time-bound | Achievable with a high-time counter normalised over one period. |

---

## V7 — Duty Cycle Display

**Requirement:** [R7 — Duty Cycle Display](specification.md#r7--duty-cycle-display)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Specifies a dedicated 4-digit display with a fixed decimal point position. |
| Measurable | The decimal point position and digit count are objectively verifiable. |
| Atomic | Covers only the display format of the duty cycle, not the measurement itself (R6). |
| Relevant | Required to present the duty cycle value in a human-readable fixed-point format. |
| Time-bound | Implementable within the SevenSegmentDecoder via a status flag for decimal point control. |

---

## V8 — Multiplexed Display Control

**Requirement:** [R8 — Multiplexed Display Control](specification.md#r8--multiplexed-display-control)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Specifies time-multiplexed digit activation for both 4-digit displays. |
| Measurable | Multiplexing behaviour (one digit active at a time, cyclic switching) is verifiable by simulation. |
| Atomic | Addresses only the multiplexing control mechanism, not the content of the display. |
| Relevant | Time-multiplexing is the standard method for driving multi-digit 7-segment displays with minimal I/O pins. |
| Time-bound | Implemented with a refresh counter and digit selector within the SevenSegmentDecoder. |

---

## V9 — Display Type Configuration

**Requirement:** [R9 — Display Type Configuration](specification.md#r9--display-type-configuration)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Names the two display types (common-anode and common-cathode) and specifies a configuration parameter as the mechanism. |
| Measurable | The polarity inversion between both modes is objectively verifiable. |
| Atomic | Addresses only the hardware polarity configuration, separate from all display logic requirements. |
| Relevant | Both display types are in common use; supporting both increases hardware compatibility. |
| Time-bound | Achievable with a single Verilog parameter and bitwise inversion of outputs. |

---

## V10 — Modular Design Structure

**Requirement:** [R10 — Modular Design Structure](specification.md#r10--modular-design-structure)

| Criterion | Assessment |
|-----------|------------|
| Specific  | Names the three required modules explicitly: frequency measurement, duty cycle measurement, and seven-segment display control. |
| Measurable | The presence of separate modules is verifiable by structural inspection of the source files. |
| Atomic | Addresses only the structural decomposition, not the behaviour of any individual module. |
| Relevant | Modularity enables independent verification of submodules, which is a central methodology of this project. |
| Time-bound | The modular structure is already reflected in the current implementation. |
