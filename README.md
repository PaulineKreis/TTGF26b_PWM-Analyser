# PWM Signal Analyzer with Dual 7-Segment Display

## Overview

This project implements a digital PWM (Pulse Width Modulation) signal analyzer in Verilog HDL.

The system measures:
- the frequency of an incoming PWM signal
- the duty cycle of the PWM signal

The measured values are displayed on two independent 4-digit 7-segment displays:
- one display for the PWM frequency
- one display for the PWM duty cycle

The design is intended for ASIC-oriented digital design workflow and follows a modular hardware architecture.

---

## Features

- Frequency measurement and display
- Duty cycle measurement and display
- Multiplexed control of two 4-digit 7-segment displays
- Error indication for invalid or missing PWM signals
- Support for common-anode and common-cathode displays
- Modular Verilog HDL implementation

---

## Display Behavior

### Frequency Display
- Displays values from `1 kHz` to `9999 kHz`
- Displays `Lo` if the frequency is below `1 kHz`
- Displays `Hi` if the frequency exceeds `9999 kHz`
- Displays `Err` if no PWM edge transition is detected for more than `50 ms`

### Duty Cycle Display
- Displays values from `0.00` to `1.00`
- Uses a fixed decimal point for fractional representation

---

## Project Structure

```text
/docs      Project documentation and specifications
/src       Verilog HDL source files
/tb        Testbenches and test documentation