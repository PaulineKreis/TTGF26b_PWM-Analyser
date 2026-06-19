# FPGA Testing (iCEbreaker)

This folder contains the setup for testing the PWM Analyser on an iCEbreaker FPGA board using Apio and VS Code.

## Driver Setup (Windows)

The iCEbreaker board requires the WinUSB driver on both USB interfaces. This can be done with [Zadig](https://zadig.akeo.ie/):

1. Open Zadig and select **iCEBreaker V1.1a (Interface 0)** → install/reinstall **WinUSB**
2. Repeat for **iCEBreaker V1.1a (Interface 1)** → install/reinstall **WinUSB**

## Build & Flash (VS Code + Apio)

1. Install the **Apio** extension in VS Code (by fpgawars)
2. Open the `apio-FPGA_Testing` folder as your workspace in VS Code
3. **Build** using the ✓ button in the Apio toolbar
4. **Upload** using the → (arrow) button — linting is not required

## Project Structure

In the main repo, `PWM_Analyser.v` integrates all submodules and is wrapped by `tt_um_PaulineKreis_PWM_Analyser.v` to comply with the Tiny Tapeout interface (packed I/O buses `ui_in`, `uo_out`). For FPGA testing, the TT wrapper is dropped and `PWM_Analyser.v` acts as the top-level directly.

To match the iCEbreaker pinout, the FPGA version of `PWM_Analyser.v` replaces the packed output arrays (`o_seg[6:0]`, `o_digit_en[3:0]`) with individual output ports (`o_segA`–`o_segG`, `o_digit_en_0`–`o_digit_en_3`), assigned via `assign` statements internally.

The reset signal is also inverted when passed to submodules (`.i_resetn(~i_aresetn)`). The design uses an active-low reset internally, but the iCEbreaker button is low when pressed. Without the inversion, the design would only run while the button is held down — with it, the button acts as a reset trigger and the design runs normally when released.

All other `.v` source files mirror the main repo, with one exception: the clock frequency parameter is set to **12 MHz** throughout, matching the iCEbreaker's onboard oscillator.

## Limitations vs. ASIC Design

Due to the 12 MHz clock (vs. the target ASIC clock), the FPGA build has a reduced measurement range and lower accuracy at higher frequencies. Duty cycle measurements are reliable up to approximately **100 kHz**. Above that, results become inaccurate and the full measurement range of the ASIC design is not covered.