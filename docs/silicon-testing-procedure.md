# Silicon Testing Procedure — PWM Signal Analyser

## 1. Overview

This document specifies the silicon testing procedure for the PWM Signal Analyser integrated circuit. It defines the input signals to be applied to the fabricated chip and the output signals expected in response, for each test scenario.

The device under test (DUT) is `tt_um_PaulineKreis_PWM_Analyser.v` which essentially wraps `PWM_Analyser.v` for Tiny Tapeout, implemented on the Tiny Tapeout shuttle. The design is rated to operate at a clock frequency of **50 MHz only**; correct operation at other clock frequencies cannot be guaranteed and is outside the scope of this procedure. Likewise, the input PWM signal frequency must not exceed **25 MHz**, the Nyquist limit relative to the 50 MHz sampling clock — input frequencies above this limit cannot be reliably sampled and are outside the scope of this procedure, independent of the R4 "HI" display range (which tops out at 9999 kHz, well below this limit).

**Output timing model:**
- A free-running output-latch timer samples the latest available *numeric* measurement onto the display every **100 ms** (5,000,000 clock cycles), on a fixed grid independent of when any individual measurement completes.
- The **frequency counter** waits for 5 rising edges of the PWM input, measuring the elapsed time between the 1st and 5th edge — i.e. **4 full PWM periods** — to complete a numeric measurement. Once ready, the new value is sampled onto the output at the next 100 ms grid boundary. If 4 PWM periods take longer than one 100 ms window (i.e. for input frequencies below ~40 Hz), the output continues showing the previous value until the first grid boundary that occurs after the new measurement becomes ready.
- The **duty cycle counter** measures a single rising-edge-to-falling-edge window and runs asynchronously, in parallel with the 100 ms grid (not gated by it). If the 100 ms boundary occurs before a falling edge arrives, the latched duty cycle value may reflect an incomplete or stale measurement. This is a known and accepted limitation of the design, not a defect.
- **LO, HI, and ERR status conditions are dominant and bypass the 100 ms grid entirely.** LO and HI are detected using the same 4-PWM-period measurement window as a normal frequency reading, but once detected, the status overrides the display immediately — it does not wait for the next 100 ms boundary. ERR (missing-signal) is detected by the 1 s no-edge timeout and is likewise displayed immediately upon detection, with no additional 100 ms grid delay.
- **Display decoder pipeline latency:** once a new numeric value is presented to the 7-segment decoder, it is converted to BCD digits through a 4-stage sequential division pipeline (one division per decimal digit), using a `shift_subtract_divider` instantiated with `WIDTH_A = 14`. Each division takes exactly 14 clock cycles (one shift-subtract iteration per dividend bit) from `start` to `done`. With 4 sequential divisions chained back-to-back, the total BCD-conversion latency is approximately 4 × 14 = **56 clock cycles**, plus 1–2 cycles for state-machine transitions between digits — call it **~60 clock cycles** as a safe margin. This is negligible relative to the 100 ms grid period but should be accounted for as a small margin when capturing data immediately after a status condition is expected to bypass the grid (T5–T7 below).

This timing model must be accounted for when scheduling each measurement in the procedure below.

---

## 2. External Setup

### 2.1 Signal Connections

| Signal | DUT Pin | Source |
|---|---|---|
| Clock | `clk` | 50 MHz clock source |
| Reset | `rst_n` | Active-low reset (pushbutton or GPIO) |
| PWM stimulus | `ui[0]` (`PWM_INPUT`) | External PWM stimulus (function generator) |
| Mode select | `ui[1]` (`MODE_SWITCH`) | Logic '0' (frequency) or '1' (duty cycle) |
| `ui[2]`–`ui[7]` | `NC` | Tied low (GND), unused |
| `ena` | `ena` | Tied high (3.3 V) |
| Segment G | `uo[0]` (`G`) | Capture (logic analyser) |
| Segment F | `uo[1]` (`F`) | Capture (logic analyser) |
| Segment E | `uo[2]` (`E`) | Capture (logic analyser) |
| Segment D | `uo[3]` (`D`) | Capture (logic analyser) |
| Segment C | `uo[4]` (`C`) | Capture (logic analyser) |
| Segment B | `uo[5]` (`B`) | Capture (logic analyser) |
| Segment A | `uo[6]` (`A`) | Capture (logic analyser) |
| Decimal point | `uo[7]` (`DP`) | Capture (logic analyser) |
| Digit enable 3 | `uio[0]` (`DIGIT_EN_3`) | Capture (logic analyser) |
| Digit enable 2 | `uio[1]` (`DIGIT_EN_2`) | Capture (logic analyser) |
| Digit enable 1 | `uio[2]` (`DIGIT_EN_1`) | Capture (logic analyser) |
| Digit enable 0 | `uio[3]` (`DIGIT_EN_0`) | Capture (logic analyser) |
| `uio[4]`–`uio[7]` | `NC` | Unused |

> **Note on bit ordering:** Segment bits are mapped individually by name (`uo[6]=A` through `uo[0]=G`), not as a simple bus where bit position equals segment order. When decoding captured values, map each `uo` bit to its labelled segment per the pinout. Likewise, `uio[0]` corresponds to `DIGIT_EN_3` (leftmost digit) and `uio[3]` to `DIGIT_EN_0` (rightmost digit) — the reverse of a naive `uio[3:0]` index-to-digit mapping.

### 2.2 PWM Stimulus Conditioning

The PWM stimulus must be supplied as a clean 3.3 V CMOS-level square wave (0 V low / 3.3 V high) from an external function generator, since the chip has no analog front end of its own. The generator output should be configured to drive directly into the high-impedance digital input pin; no termination resistor to ground should be used, as this is a digital CMOS input, not a transmission-line load.

**The PWM input frequency must not exceed 25 MHz** (the Nyquist limit for the 50 MHz sampling clock). Input frequencies above this limit cannot be reliably sampled by the digital edge-detection logic and fall outside the scope of this procedure.

Signal integrity (rise/fall time, overshoot) should be checked at the DUT pin with an oscilloscope before each test to ensure the input edges are clean enough for reliable edge detection.

### 2.3 Display Output Decoding

The segment outputs (`uo[6:0]` = A–G), DP (`uo[7]`), and DIGIT_EN outputs (`uio[3:0]`) together form a time-multiplexed 4-digit 7-segment display interface (digit refresh rate 1 kHz per digit). To read a displayed value:

1. Capture all 12 signals simultaneously.
2. Identify the active digit from the one-hot pattern on DIGIT_EN outputs.
3. Read the segment outputs while that digit is active and decode each `uo` bit as its labelled segment (A–G).
4. Repeat across all four digit slots to reconstruct the full 4-character display.

A capture window of at least 10 ms is recommended to observe multiple full refresh frames per measurement.

---

## 3. Test Procedure

All tests assume the chip has been reset (`rst_n = 0` for ≥ 10 cycles, then released) before the stimulus is applied. Per the timing model above: numeric frequency readings (T1–T3) wait for 4 PWM periods to elapse plus the next 100 ms grid boundary; duty cycle readings (T4) wait one 100 ms boundary after a stable PWM signal is applied, which is sufficient for the nominal cases tested here; status conditions (T5–T7: LO, HI, ERR) bypass the grid and are read as soon as they are detected, plus a small margin for the decoder's internal pipeline.

### T1 — Frequency Measurement (1 kHz)

`MODE_SWITCH (ui[1]) = 0` (frequency mode) for T1–T3, T5–T7 below.

> 4 PWM periods (1st-to-5th rising edge) at 1 kHz = 4 ms, well within the first 100 ms output grid window, so the measurement is ready before the first 100 ms boundary.

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | segment/digit-enable outputs undefined during reset | | |
| 10 | `rst_n=1`, PWM_INPUT=1 kHz, 50% duty | (previous/stale value, counter not yet updated) | | |
| 5,000,010 | `rst_n=1`, PWM_INPUT=1 kHz, 50% duty | Display = `0001` (kHz) | | |

### T2 — Frequency Measurement (10 kHz)

> 4 PWM periods (1st-to-5th rising edge) at 10 kHz = 0.4 ms — measurement is ready well before the first 100 ms boundary.

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | (reset) | | |
| 10 | `rst_n=1`, PWM_INPUT=10 kHz, 25% duty | (stale value) | | |
| 5,000,010 | `rst_n=1`, PWM_INPUT=10 kHz, 25% duty | Display = `0010` (kHz) | | |

### T3 — Frequency Measurement (100 kHz)

> 4 PWM periods (1st-to-5th rising edge) at 100 kHz = 40 µs — measurement is ready well before the first 100 ms boundary.

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | (reset) | | |
| 10 | `rst_n=1`, PWM_INPUT=100 kHz, 75% duty | (stale value) | | |
| 5,000,010 | `rst_n=1`, PWM_INPUT=100 kHz, 75% duty | Display = `0100` (kHz) | | |

### T4 — Duty Cycle Measurement

`MODE_SWITCH (ui[1]) = 1` (duty cycle mode); PWM stimulus = 10 kHz throughout.

> The duty cycle counter measures a single rising-to-falling edge window asynchronously to the 100 ms output grid. At 10 kHz, one full period is 100 µs — far shorter than the 100 ms grid — so the measurement window reliably completes before being latched in this nominal case. (At very low input frequencies, e.g. close to the 1 kHz lower bound, the 100 ms boundary could occur before the falling edge arrives, in which case the latched duty cycle value may be stale or incomplete; this is an accepted limitation and not tested here.)

| Test Point | Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|---|
| T4a | 5,000,010 | PWM_INPUT duty = 25% | Display = `0025`, DP active on tens digit | | |
| T4b | 5,000,010 | PWM_INPUT duty = 50% | Display = `0050`, DP active on tens digit | | |
| T4c | 5,000,010 | PWM_INPUT duty = 75% | Display = `0075`, DP active on tens digit | | |

### T5 — Low-Frequency Indication

> LO is detected after the same 4-PWM-period measurement window (1st-to-5th rising edge) as a normal frequency reading. At 900 Hz, 4 periods ≈ 4.44 ms (≈222,222 cycles at 50 MHz). As a dominant status, LO bypasses the 100 ms output grid and is displayed as soon as detected, plus the decoder's ~60-cycle BCD-conversion pipeline margin (see Section 1).

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | (reset) | | |
| 10 | `rst_n=1`, PWM_INPUT=900 Hz, 50% duty | (stale value) | | |
| ~222,290 | `rst_n=1`, PWM_INPUT=900 Hz, 50% duty | Display = `Lo` (D1=`L`, D0=`o`; D2,D3 blank) — appears shortly after detection, no grid wait | | |

### T6 — High-Frequency Indication

> HI is detected after the same 4-PWM-period measurement window (1st-to-5th rising edge) as a normal frequency reading. At 11 MHz, 4 periods ≈ 364 ns (≈18 cycles at 50 MHz) — detection is essentially immediate. As a dominant status, HI bypasses the 100 ms output grid and is displayed shortly after detection, plus the decoder's ~60-cycle BCD-conversion pipeline margin (see Section 1). Note: 11 MHz is below the 25 MHz Nyquist limit for the 50 MHz sampling clock, so this is a valid input frequency for this test.

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | (reset) | | |
| 10 | `rst_n=1`, PWM_INPUT=11 MHz, 50% duty | (stale value) | | |
| ~80 | `rst_n=1`, PWM_INPUT=11 MHz, 50% duty | Display = `Hi` (D1=`H`, D0=`i`; D2,D3 blank) — appears shortly after detection, no grid wait | | |

### T7 — Missing-Signal Detection

> ERR is detected via a 1 s no-edge timeout (independent of the 4-PWM-period measurement window) and, as a dominant status, bypasses the 100 ms output grid entirely — it is displayed shortly after detection, plus the decoder's ~60-cycle BCD-conversion pipeline margin (see Section 1), with no additional grid delay.

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| 0 | `rst_n=0`, PWM_INPUT=0 | (reset) | | |
| 10 | `rst_n=1`, PWM_INPUT=10 kHz | (stale value) | | |
| 5,000,010 | `rst_n=1`, PWM_INPUT=10 kHz | Display = `0010` | | |
| 5,000,011 | `rst_n=1`, PWM_INPUT=0 (held low) | (still showing last valid value) | | |
| ~55,000,070 | `rst_n=1`, PWM_INPUT=0 (held low) | Display = `Err` (D2=`E`, D1=`r`, D0=`r`; D3 blank) — appears shortly after detection, no grid wait | | |

> Note: ~55,000,070 ≈ 5,000,011 (PWM removed) + 50,000,000 cycles (1 s timeout at 50 MHz) + ~60 cycles (decoder pipeline margin). No additional 100 ms grid delay is added since ERR bypasses the output grid.

### T8 — Multiplexed Display Control

| Clock Cycle | Input Signals | Expected Output | Measured | Pass / Fail |
|---|---|---|---|---|
| Any (steady state) | Valid PWM applied, display settled | DIGIT_EN outputs cycle one-hot through all 4 digit positions at 1 kHz/digit; segment outputs update in sync | | |

---

## 4. Notes for Reproduction

- All "Expected Output" entries assume `COMMON_ANODE = 1` (default configuration). Per the decoder RTL, segment outputs and DP are active-low under this configuration (inverted based on `COMMON_ANODE`), while **DIGIT_EN outputs are active-high regardless of `COMMON_ANODE`** (not inverted by this parameter). Confirm output polarity against the synthesised decoder before assuming all three buses share the same active level.
- The frequency display only updates at most once per 100 ms grid boundary for *numeric* readings, and only once 4 full PWM periods (1st-to-5th rising edge) have been observed; low input frequencies may add an extra 100 ms of apparent latency (see Section 1, Output timing model).
- The duty cycle display updates independently of the 100 ms grid and may latch a stale or partial value if a measurement window has not completed by the time the grid boundary occurs; this is expected behaviour for sufficiently low input frequencies and is not exercised in the nominal tests above.
- **LO, HI, and ERR are dominant status conditions and bypass the 100 ms output grid entirely** — they are displayed shortly after detection (plus a small decoder pipeline margin), not at the next grid boundary. This is unlike numeric frequency/duty cycle readings, which are only ever sampled onto the display at a grid boundary.
- **The decoder's BCD-conversion pipeline** (4 sequential digit divisions through a shared 14-cycle `shift_subtract_divider`) adds a fixed latency of approximately **60 clock cycles** (4 × 14 cycles + state-machine overhead) between a value being presented to the decoder and the corresponding segments appearing at the output pins. This is negligible relative to the 100 ms grid but should be allowed for as a margin when capturing data immediately after a dominant status is expected to appear.
- **This procedure is valid only for `clk` = 50 MHz.** Correct operation, and the cycle counts given throughout this document, cannot be guaranteed if the device is clocked at any other frequency; reproduction at other clock frequencies is outside the scope of this procedure.
- **The PWM input frequency must not exceed 25 MHz** (Nyquist limit for the 50 MHz sampling clock); inputs above this frequency cannot be reliably measured and are outside the scope of this procedure.