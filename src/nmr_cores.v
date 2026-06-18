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
    // Internal wires connecting the Pulse Sequencer sub-module
    wire psq_rf_A;
    wire psq_rf_B;
    wire psq_rx_gate;
    wire psq_busy;

    // Internal wires connecting the Quadrature Demodulator sub-module
    wire [3:0] demod_I;
    wire [3:0] demod_Q;

    // Instantiate CPMG Pulse Sequencer
    pulse_sequencer psq_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(ui_in[0]),
        .spi_sclk(ui_in[1]),
        .spi_mosi(ui_in[2]),
        .spi_ss_n(ui_in[3]),
        .rf_pulse_A(psq_rf_A),   
        .rf_pulse_B(psq_rf_B),   
        .rx_gate(psq_rx_gate),    
        .status_busy(psq_busy)
    );

    // Instantiate Quadrature Demodulator
    quadrature_demodulator demod_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx_gate(psq_rx_gate),    // Controlled by the pulse sequencer
        .adc_in(ui_in[4]),        // 1-bit digitized RF input from RX chain
        .i_out(demod_I),          // 4-bit filtered In-phase output
        .q_out(demod_Q)           // 4-bit filtered Quadrature output
    );

    // Bind pulse sequencer internal outputs to physical pins
    assign uo_out[0] = psq_rf_A;
    assign uo_out[1] = psq_rf_B;
    assign uo_out[2] = psq_rx_gate;
    assign uo_out[3] = psq_busy;

    // Bind demodulator outputs to remaining physical pins (4-bits each)
    // Demodulator outputs are placed onto the bidirectional bus
    assign uio_out[3:0] = demod_I;
    assign uio_out[7:4] = demod_Q;
    assign uio_oe       = 8'b11111111; // Enable all as outputs for Tiny Tapeout

    // Cleanly tie off remaining unused top pins
    assign uo_out[7:4]  = 4'b0000;

endmodule
