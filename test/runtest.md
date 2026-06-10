# Testing Methodology

## Formal Verification Tests

1. The rising and falling edge modules are simple and self contained allowing for easy cover testing. In particular, one must only verify that the **tick** signal is high only when there is a rising / falling edge on the **level** signal. This can be done by viewing the stimulus waveform for fulfilling the cover condition.

2. 