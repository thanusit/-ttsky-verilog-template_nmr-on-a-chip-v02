/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */
// The top module instantiating only the pulse sequencer. All workflows were succesful.

`default_nettype none

module tt_um_thanusit_nmr_cores (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
     // Internal wires connecting the sub-module outputs to top pins or other blocks
    wire psq_rf_A;
    wire psq_rf_B;
    wire psq_rx_gate;
    wire psq_busy;

    // Instantiate CPMG Pulse Sequencer
    pulse_sequencer psq_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ui_in[0]),
        .spi_sclk(ui_in[1]),
        .spi_mosi(ui_in[2]),
        .spi_ss_n(ui_in[3]),
        .rf_pulse_A(psq_rf_A),   // This can also route to the Transmitter block
        .rf_pulse_B(psq_rf_B),   // This can also route to the Transmitter block
        .rx_gate(psq_rx_gate),    // This can also route to the Demodulator block
        .status_busy(psq_busy)
    );

    // Bind internal outputs to the physical hardware output pins
    assign uo_out[0] = psq_rf_A;
    assign uo_out[1] = psq_rf_B;
    assign uo_out[2] = psq_rx_gate;
    assign uo_out[3] = psq_busy;

    // Cleanly tie off (forcing to 0) the remaining unused pins
    assign uo_out[7:4] = 4'b0000;
    assign uio_out     = 8'b00000000;
    assign uio_oe      = 8'b00000000;

endmodule  
