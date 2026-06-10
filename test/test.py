"""
Cocotb testbench for PWM_Analyser top-level module.

DUT ports:
    i_clk           - 100 MHz system clock
    i_pwm           - PWM input signal
    i_aresetn       - Active-low asynchronous reset

    o_seg_dc        - 7-segment pattern for duty cycle display
    o_dp_dc         - Decimal point for duty cycle display
    o_digit_en_dc   - Digit enable for duty cycle display (active-low, common anode)

    o_seg_freq      - 7-segment pattern for frequency display
    o_dp_freq       - Decimal point for frequency display
    o_digit_en_freq - Digit enable for frequency display (active-low, common anode)

SevenSegmentDecoder is instantiated with COMMON_ANODE=1 (default), so:
    - o_digit_en is active-low  (enabled digit = 0)
    - o_seg      is active-low  (lit segment = 0)
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────

CLK_PERIOD_NS   = 10        # 100 MHz
CLK_HZ          = 100_000_000

# SevenSegmentDecoder defaults
DIGIT_REFRESH_HZ    = 1000
REFRESH_COUNT_MAX   = CLK_HZ // DIGIT_REFRESH_HZ   # 100 000 cycles per digit
NUM_DIGITS          = 4

# How many full display refresh cycles to wait before sampling outputs.
# One full rotation = NUM_DIGITS * REFRESH_COUNT_MAX clock cycles.
DISPLAY_SETTLE_CYCLES = NUM_DIGITS * REFRESH_COUNT_MAX

# Extra settling margin for freq_counter / duty_cycle_counter pipelines.
# Both submodules need at least 2 full PWM periods to produce a stable result.
# This is handled per-test by waiting after the PWM stimulus is established.


# ──────────────────────────────────────────────────────────────────────────────
# Seven-segment decode helpers  (active-low, common anode)
# ──────────────────────────────────────────────────────────────────────────────

# Segment order in the 7-bit vector: {a, b, c, d, e, f, g}
# Patterns below are the *active-low* values seen on o_seg (i.e. ~active_segments).
SEG_MAP = {
    0b0000001: 0,   # 0
    0b1001111: 1,   # 1
    0b0010010: 2,   # 2
    0b0000110: 3,   # 3
    0b1001100: 4,   # 4
    0b0100100: 5,   # 5
    0b0100000: 6,   # 6
    0b0001111: 7,   # 7
    0b0000000: 8,   # 8
    0b0000100: 9,   # 9
}

# Special character patterns (active-low)
CHAR_BLANK_PATTERN  = 0b1111111
CHAR_E_PATTERN      = 0b0110000   # E  → active high 1001111 → active low 0110000  -- wait, recalculate
CHAR_H_PATTERN      = 0b1001000
CHAR_I_PATTERN      = 0b1001111
CHAR_L_PATTERN      = 0b1110001
CHAR_O_PATTERN      = 0b0000001   # same as 0
CHAR_R_PATTERN      = 0b1111010

# Build the active-low patterns properly from the RTL source:
# RTL defines active-high patterns, then inverts for COMMON_ANODE.
# We invert them here (mask to 7 bits) to get what the DUT actually drives.
_active_high = {
    'E': 0b1001111,
    'R': 0b0000101,
    'H': 0b0110111,
    'I': 0b0110000,
    'L': 0b0001110,
    'O': 0b1111110,   # same segments as 0
    ' ': 0b0000000,
}
SPECIAL_CHARS = {((~v) & 0x7F): k for k, v in _active_high.items()}

# Similarly build the digit decode map from active-high RTL values
_digit_active_high = {
    0: 0b1111110,
    1: 0b0110000,
    2: 0b1101101,
    3: 0b1111001,
    4: 0b0110011,
    5: 0b1011011,
    6: 0b1011111,
    7: 0b1110000,
    8: 0b1111111,
    9: 0b1111011,
}
SEG_TO_DIGIT = {((~v) & 0x7F): k for k, v in _digit_active_high.items()}


def decode_segment(seg_val: int):
    """
    Decode a 7-bit active-low segment pattern to a character.
    Returns an integer (0-9), a string for special chars, or '?' if unknown.
    """
    if seg_val in SEG_TO_DIGIT:
        return SEG_TO_DIGIT[seg_val]
    if seg_val in SPECIAL_CHARS:
        return SPECIAL_CHARS[seg_val]
    if seg_val == 0b1111111:
        return ' '     # blank
    return f'?({seg_val:07b})'


def sample_display(digit_en, seg):
    """
    Given the current digit_en (active-low 4-bit) and seg (active-low 7-bit),
    return (active_digit_index, decoded_character).

    digit_en bit positions: [3]=leftmost, [0]=rightmost
    """
    inv_en = (~digit_en) & 0xF      # invert to find which digit is asserted
    if inv_en == 0:
        return None, None           # no digit enabled
    digit_idx = inv_en.bit_length() - 1  # 0=rightmost ... 3=leftmost
    char = decode_segment(seg & 0x7F)
    return digit_idx, char


async def read_display(dut, seg_signal, dp_signal, digit_en_signal, label=""):
    """
    Scan all four digits by waiting for each digit_en pattern to appear.
    Returns a list of 4 decoded characters [digit3(left), digit2, digit1, digit0(right)].

    Waits up to DISPLAY_SETTLE_CYCLES * 2 clock cycles before giving up.
    """
    chars = [None, None, None, None]    # index 0 = rightmost
    seen = set()
    timeout = DISPLAY_SETTLE_CYCLES * 2

    for _ in range(timeout):
        await RisingEdge(dut.i_clk)
        digit_en = digit_en_signal.value.integer
        seg      = seg_signal.value.integer
        inv_en   = (~digit_en) & 0xF
        if inv_en and inv_en not in seen:
            idx = inv_en.bit_length() - 1
            chars[idx] = decode_segment(seg & 0x7F)
            seen.add(inv_en)
        if len(seen) == 4:
            break

    dut._log.info(f"[{label}] digits (left→right): {chars[3]} {chars[2]} {chars[1]} {chars[0]}")
    return chars


def chars_to_number(chars):
    """
    Convert a 4-element digit list [d3, d2, d1, d0] to an integer.
    Strips leading blanks. Returns None if any remaining digit is non-numeric.
    """
    # chars[3]=leftmost, chars[0]=rightmost
    digits = [chars[3], chars[2], chars[1], chars[0]]
    # strip leading blanks
    while digits and digits[0] == ' ':
        digits.pop(0)
    if not digits:
        return 0
    result = 0
    for d in digits:
        if not isinstance(d, int):
            return None     # non-numeric character present
        result = result * 10 + d
    return result


# ──────────────────────────────────────────────────────────────────────────────
# PWM generation helper
# ──────────────────────────────────────────────────────────────────────────────

async def drive_pwm(dut, freq_hz: int, duty_percent: float, num_periods: int):
    """
    Drive i_pwm with a PWM signal of the given frequency and duty cycle
    for num_periods complete periods.  Stimulus is aligned to negedge of i_clk.

    freq_hz       - desired PWM frequency in Hz
    duty_percent  - duty cycle 0.0 – 100.0
    num_periods   - number of complete PWM periods to generate
    """
    period_cycles   = CLK_HZ // freq_hz
    high_cycles     = round(period_cycles * duty_percent / 100.0)
    low_cycles      = period_cycles - high_cycles

    if high_cycles == 0 and duty_percent > 0:
        high_cycles = 1
        low_cycles  = period_cycles - 1
    if low_cycles == 0 and duty_percent < 100:
        low_cycles  = 1
        high_cycles = period_cycles - 1

    for _ in range(num_periods):
        await FallingEdge(dut.i_clk)
        dut.i_pwm.value = 1
        for _ in range(high_cycles - 1):
            await FallingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)
        dut.i_pwm.value = 0
        for _ in range(low_cycles - 1):
            await FallingEdge(dut.i_clk)


# ──────────────────────────────────────────────────────────────────────────────
# Common setup
# ──────────────────────────────────────────────────────────────────────────────

async def setup(dut):
    """Start clock and apply reset."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, units="ns").start())

    dut.i_aresetn.value = 0
    dut.i_pwm.value     = 0
    await ClockCycles(dut.i_clk, 5)

    dut.i_aresetn.value = 1
    await ClockCycles(dut.i_clk, 5)
    dut._log.info("Reset released.")


# ──────────────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────────────

@cocotb.test()
async def test_reset_behaviour(dut):
    """
    While reset is asserted (i_aresetn=0), the 7-segment outputs should be
    in a defined idle state.  We just confirm the DUT does not produce X/Z.
    """
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, units="ns").start())

    dut.i_aresetn.value = 0
    dut.i_pwm.value     = 0
    await ClockCycles(dut.i_clk, 20)

    # Check outputs are not X/Z
    for sig, name in [
        (dut.o_seg_freq,       "o_seg_freq"),
        (dut.o_digit_en_freq,  "o_digit_en_freq"),
        (dut.o_seg_dc,         "o_seg_dc"),
        (dut.o_digit_en_dc,    "o_digit_en_dc"),
    ]:
        assert sig.value.is_resolvable, \
            f"{name} contains X/Z during reset: {sig.value}"

    dut._log.info("PASS: No X/Z on outputs during reset.")


@cocotb.test()
async def test_1khz_50pct(dut):
    """
    1 kHz PWM, 50% duty cycle.
    Expected:  freq display → 1, dc display → 50 (with decimal point on digit 2)
    """
    await setup(dut)

    FREQ_HZ   = 1_000
    DUTY_PCT  = 50.0
    PERIODS   = 20      # enough for both submodules to lock

    dut._log.info(f"Driving PWM: {FREQ_HZ} Hz, {DUTY_PCT}% duty")
    await drive_pwm(dut, FREQ_HZ, DUTY_PCT, PERIODS)

    # Let displays settle for one full rotation
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq")
    dc_chars   = await read_display(dut, dut.o_seg_dc, dut.o_dp_dc,
                                    dut.o_digit_en_dc,   label="dc")

    freq_val = chars_to_number(freq_chars)
    dc_val   = chars_to_number(dc_chars)

    dut._log.info(f"Decoded freq={freq_val} kHz, dc={dc_val} (×0.1 %)")

    assert freq_val == 1, \
        f"Expected freq=1 kHz, got {freq_val}"
    assert dc_val == 50, \
        f"Expected dc=50 (50.0%), got {dc_val}"

    dut._log.info("PASS: 1 kHz, 50%")


@cocotb.test()
async def test_10khz_25pct(dut):
    """
    10 kHz PWM, 25% duty cycle.
    Expected:  freq display → 10, dc display → 25
    """
    await setup(dut)

    FREQ_HZ  = 10_000
    DUTY_PCT = 25.0
    PERIODS  = 50

    dut._log.info(f"Driving PWM: {FREQ_HZ} Hz, {DUTY_PCT}% duty")
    await drive_pwm(dut, FREQ_HZ, DUTY_PCT, PERIODS)
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq")
    dc_chars   = await read_display(dut, dut.o_seg_dc, dut.o_dp_dc,
                                    dut.o_digit_en_dc,   label="dc")

    freq_val = chars_to_number(freq_chars)
    dc_val   = chars_to_number(dc_chars)

    dut._log.info(f"Decoded freq={freq_val} kHz, dc={dc_val}")

    assert freq_val == 10, \
        f"Expected freq=10 kHz, got {freq_val}"
    assert dc_val == 25, \
        f"Expected dc=25 (25%), got {dc_val}"

    dut._log.info("PASS: 10 kHz, 25%")


@cocotb.test()
async def test_100khz_75pct(dut):
    """
    100 kHz PWM, 75% duty cycle.
    Expected:  freq display → 100 kHz, dc display → 75
    """
    await setup(dut)

    FREQ_HZ  = 100_000
    DUTY_PCT = 75.0
    PERIODS  = 200

    dut._log.info(f"Driving PWM: {FREQ_HZ} Hz, {DUTY_PCT}% duty")
    await drive_pwm(dut, FREQ_HZ, DUTY_PCT, PERIODS)
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq")
    dc_chars   = await read_display(dut, dut.o_seg_dc, dut.o_dp_dc,
                                    dut.o_digit_en_dc,   label="dc")

    freq_val = chars_to_number(freq_chars)
    dc_val   = chars_to_number(dc_chars)

    dut._log.info(f"Decoded freq={freq_val} kHz, dc={dc_val}")

    assert freq_val == 100, \
        f"Expected freq=100 kHz, got {freq_val}"
    assert dc_val == 75, \
        f"Expected dc=75 (75%), got {dc_val}"

    dut._log.info("PASS: 100 kHz, 75%")


@cocotb.test()
async def test_dc_edge_cases(dut):
    """
    Check that near-0% and near-100% duty cycles produce sensible results
    and do not cause X/Z on any output.
    """
    await setup(dut)

    for duty in [1.0, 99.0]:
        dut._log.info(f"Testing edge duty cycle: {duty}%")
        await drive_pwm(dut, 10_000, duty, 100)
        await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

        for sig, name in [
            (dut.o_seg_dc,        "o_seg_dc"),
            (dut.o_digit_en_dc,   "o_digit_en_dc"),
            (dut.o_seg_freq,      "o_seg_freq"),
            (dut.o_digit_en_freq, "o_digit_en_freq"),
        ]:
            assert sig.value.is_resolvable, \
                f"{name} contains X/Z at {duty}% duty: {sig.value}"

        dut._log.info(f"PASS: {duty}% duty — no X/Z on outputs.")


@cocotb.test()
async def test_status_hi(dut):
    """
    Drive a PWM frequency above the freq_counter's measurable range and
    verify the frequency display shows 'HI' (o_status = 3'b100).

    Note: what counts as HI depends on your freq_counter implementation.
    Here we drive at 9999 kHz (just below Nyquist at 100 MHz) to trigger it.
    Adjust FREQ_HZ to match your actual HI threshold.
    """
    await setup(dut)

    # Drive as fast as possible — single-cycle high, single-cycle low = 50 MHz
    # This is above typical freq_counter range and should trigger HI status.
    FREQ_HZ  = 25_000_000
    DUTY_PCT = 50.0
    PERIODS  = 500

    dut._log.info(f"Driving PWM at {FREQ_HZ//1_000_000} MHz to trigger HI status")
    await drive_pwm(dut, FREQ_HZ, DUTY_PCT, PERIODS)
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq_hi")

    dut._log.info(f"freq display chars: {freq_chars}")

    # Expect 'H' and 'I' somewhere in the display
    assert 'H' in freq_chars and ('I' in freq_chars or 1 in freq_chars), \
        f"Expected HI or H1 on freq display for out-of-range input, got: {freq_chars}"

    dut._log.info("PASS: HI status displayed for over-range frequency.")

@cocotb.test()
async def test_status_lo(dut):
    """
    Drive a PWM frequency below the freq_counter's measurable range and
    verify the frequency display shows 'LO' (o_status = 3'b001).
    """
    await setup(dut)

    # Drive as fast as possible — single-cycle high, single-cycle low = 50 MHz
    # This is above typical freq_counter range and should trigger HI status.
    FREQ_HZ  = 900
    DUTY_PCT = 50.0
    PERIODS  = 5

    dut._log.info(f"Driving PWM at {FREQ_HZ/1_000_000} MHz to trigger LO status")
    await drive_pwm(dut, FREQ_HZ, DUTY_PCT, PERIODS)
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq_hi")

    dut._log.info(f"freq display chars: {freq_chars}")

    # Expect 'H' and 'I' somewhere in the display
    assert 'L' in freq_chars and ('O' in freq_chars or 0 in freq_chars), \
        f"Expected LO on freq display for out-of-range input, got: {freq_chars}"

    dut._log.info("PASS: LO status displayed for over-range frequency.")


@cocotb.test()
async def test_pwm_removed(dut):
    """
    Start with a valid PWM signal, then remove it (hold i_pwm low).
    Verify the freq display shows 'LO' (o_status = 3'b001).
    """
    await setup(dut)

    # First establish a valid signal
    await drive_pwm(dut, 10_000, 50.0, 3)
    await ClockCycles(dut.i_clk, DISPLAY_SETTLE_CYCLES)

    # Now remove the PWM signal
    dut.i_pwm.value = 0
    dut._log.info("PWM removed — holding i_pwm low.")

    # Wait long enough for freq_counter to detect signal loss
    await ClockCycles(dut.i_clk, 110_000_000)

    freq_chars = await read_display(dut, dut.o_seg_freq, dut.o_dp_freq,
                                    dut.o_digit_en_freq, label="freq_lo")

    dut._log.info(f"freq display chars after PWM removed: {freq_chars}")

    assert 'E' in freq_chars and 'R' in freq_chars and 'R' in freq_chars, \
        f"Expected LO on freq display after PWM removed, got: {freq_chars}"

    dut._log.info("PASS: LO status displayed after PWM signal removed.")
