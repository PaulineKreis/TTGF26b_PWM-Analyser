# PWM Signal Analyzer with Multiplexed 7-Segment Display

## Overview

This project implements a digital PWM (Pulse Width Modulation) signal analyzer in Verilog HDL.

The system measures:
- the frequency of an incoming PWM signal
- the duty cycle of the PWM signal

The measured values are displayed on a single 4-digit 7-segment display. The `MODE_SWITCH`
input pin selects which of the two readouts is currently shown.

The design is intended for ASIC-oriented digital design workflow and follows a modular
hardware architecture.

---

## Features

- Frequency measurement and display
- Duty cycle measurement and display
- Single 4-digit 7-segment display, time-multiplexed both per-digit and between
  frequency/duty-cycle readouts via the `MODE_SWITCH` input
- Error indication for invalid or missing PWM signals
- Modular Verilog HDL implementation

---

## Display Behavior

The display shows either the frequency or the duty cycle reading, depending on
`MODE_SWITCH`:

| `MODE_SWITCH` | Display shows |
|---------------|----------------|
| `0`           | PWM frequency  |
| `1`           | PWM duty cycle |

### Frequency Mode (`MODE_SWITCH = 0`)
- Displays values from `1 kHz` to `9999 kHz`
- Displays `Lo` if the frequency is below `1 kHz`
- Displays `Hi` if the frequency exceeds `9999 kHz`
- Displays `Err` if no PWM edge transition is detected for more than `1000 ms`

### Duty Cycle Mode (`MODE_SWITCH = 1`)
- Displays values from `0.00` to `1.00`
- Uses a fixed decimal point for fractional representation
- `Lo`/`Hi`/`Err` indications are not applicable in this mode

---

## Project Structure

```text
/docs      Project documentation and specifications
/src       Verilog HDL source files
/tb        Testbenches and test documentation
```