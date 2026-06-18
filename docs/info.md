<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

At the start, pulse sequence parameters: rf_pulse_A duration, rf_pulse_B duration, tau duration, and the echo count, are loaded via SPI into the 128-bit register in the chip. Then the chip sequencially generates rf_pulse_A, rf_pulse_B and its echos, rx_gate, and status_busy signals at the assigned pinout 0,1,2,3.       

## How to test
Assisgn the pulse sequence parameters within a microcontroller and transmit to the project chip via SPI interface. Monitor the output control signals rf_pulse_A, rf_pulse_B, rx_gate, and the status_busy.


## External hardware
List external hardware used in your project (e.g. PMOD, LED display, etc), if any
A microcontroller and an oscilloscope.
