# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import Timer

@cocotb.test()
# To have the test entirely performed in pure verilog, configure cocotb to start and pause until tb.v is completed.
async def run_verilog_for_fixed_duration(dut):
    """
    Waits for a predefined simulation timeframe to give 
    tb.v enough space to complete all its internal operations.
    """
    # Force initialize the control pins
    dut.ena.value = 1
    # Adjust 10000 to match your testbench duration requirements
    await Timer(72000, unit="ns") 


    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
