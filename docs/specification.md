# PWM Signal Analyzer Specification

## Overview

The system shall analyze an incoming PWM signal and display:
- the signal frequency
- the signal duty cycle

The measured values shall be shown on two independent multiplexed 4-digit 7-segment displays.

---

# Requirements

## R1 — PWM Frequency Measurement

The system shall measure PWM input frequencies in the range from 1 kHz to 9999 kHz.

[Validation](validation.md#v1--frequency-measurement)

---

## R2 — Frequency Display

The system shall display the measured PWM frequency as a decimal integer value on a 4-digit 7-segment display.

[Validation](validation.md#v2--frequency-display)

---

## R3 — Low-Frequency Indication

The system shall display "Lo" on the frequency display if the measured PWM frequency is below 1 kHz.

[Validation](validation.md#v3--low-frequency-indication)

---

## R4 — High-Frequency Indication

The system shall display "Hi" on the frequency display if the measured PWM frequency exceeds 9999 kHz.

[Validation](validation.md#v4--high-frequency-indication)

---

## R5 — Missing-Signal Detection

The system shall display "Err" on the frequency display if no PWM signal edge transition is detected for more than 50 ms.

[Validation](validation.md#v5--missing-signal-detection)

---

## R6 — Duty Cycle Measurement

The system shall measure the PWM duty cycle with a display resolution of 0.01 in the range from 0.00 to 1.00.

[Validation](validation.md#v6--duty-cycle-measurement)

---

## R7 — Duty Cycle Display

The system shall display the measured duty cycle value on a dedicated 4-digit 7-segment display with a fixed decimal point position.

[Validation](validation.md#v7--duty-cycle-display)

---

## R8 — Multiplexed Display Control

The system shall control both 4-digit 7-segment displays using time-multiplexed digit activation.

[Validation](validation.md#v8--multiplexed-display-control)

---

## R9 — Display Type Configuration

The seven-segment display controller shall support both common-anode and common-cathode displays through a configuration parameter.

[Validation](validation.md#v9--display-type-configuration)

---

## R10 — Modular Design Structure

The design shall consist of separate modules for frequency measurement, duty cycle measurement, and seven-segment display control.

[Validation](validation.md#v10--modular-design-structure)