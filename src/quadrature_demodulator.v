/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module quadrature_demodulator (
    input  wire       clk,        // System clock
    input  wire       rst_n,      // Active-low asynchronous reset
    input  wire       rx_gate,    // Gate signal from sequencer (1 = process data)
    input  wire       rx_in,      // Digitized 1-bit RF input signal
    output reg  [7:0] i_out,      // Filtered 8-bit In-phase output
    output reg  [7:0] q_out       // Filtered 8-bit Quadrature output
);

    // =========================================================================
    // 1. Local Oscillator (LO) Generation (f_clk / 4)
    // =========================================================================
    // A 2-bit counter creates a 4-state sequence for cosine and sine channels.
    // LO Phase states: 
    // State 0: cos =  1, sin =  0
    // State 1: cos =  0, sin =  1
    // State 2: cos = -1, sin =  0
    // State 3: cos =  0, sin = -1
    reg [1:0] lo_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lo_phase <= 2'b00;
        end else if (rx_gate) begin
            lo_phase <= lo_phase + 1'b1;
        end
    end

    // =========================================================================
    // 2. Mixing (Demodulation) Stage
    // =========================================================================
    // Maps 1-bit input (0 -> -1, 1 -> +1) multiplied by LO (1, 0, -1) 
    // into 2-bit signed numbers (-1, 0, +1).
    reg signed [1:0] mixed_i;
    reg signed [1:0] mixed_q;

    always @(*) begin
        if (!rx_gate) begin
            mixed_i = 2'sb00;
            mixed_q = 2'sb00;
        end else begin
            // In-Phase Mixer
            case (lo_phase)
                2'b00:   mixed_i = rx_in ? 2'sb01 : 2'sb11; // +1 or -1
                2'b10:   mixed_i = rx_in ? 2'sb11 : 2'sb01; // -1 or +1
                default: mixed_i = 2'sb00;                  // 0
            endcase

            // Quadrature Mixer
            case (lo_phase)
                2'b01:   mixed_q = rx_in ? 2'sb01 : 2'sb11; // +1 or -1
                2'b11:   mixed_q = rx_in ? 2'sb11 : 2'sb01; // -1 or +1
                default: mixed_q = 2'sb00;                  // 0
            endcase
        end
    end

    // =========================================================================
    // 3. Low-Pass Filtering (Moving Average / Boxcar Filter)
    // =========================================================================
    // Computes the moving average over 32 samples.
    // Max positive output: +32 (needs 7 bits signed). 
    // 8-bit accumulators prevent overflow.
    reg signed [1:0] shift_reg_i [0:31];
    reg signed [1:0] shift_reg_q [0:31];
    reg signed [7:0] acc_i;
    reg signed [7:0] acc_q;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_i <= 8'sh00;
            acc_q <= 8'sh00;
            for (j = 0; j < 32; j = j + 1) begin
                shift_reg_i[j] <= 2'sb00;
                shift_reg_q[j] <= 2'sb00;
            end
        end else if (rx_gate) begin
            // Update Accumulators: Add new mixed sample, subtract oldest sample
            acc_i <= acc_i + mixed_i - shift_reg_i[31];
            acc_q <= acc_q + mixed_q - shift_reg_q[31];

            // Advance the pipeline delay lines
            shift_reg_i[0] <= mixed_i;
            shift_reg_q[0] <= mixed_q;
            for (j = 1; j < 32; j = j + 1) begin
                shift_reg_i[j] <= shift_reg_i[j-1];
                shift_reg_q[j] <= shift_reg_q[j-1];
            end
        end
    end

// Output assignment (casts internal signed registers to top-level raw wires)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_out <= 8'h00;
            q_out <= 8'h00;
        end else begin
            // Corrected logical condition
              i_out <= rx_gate ? $unsigned(acc_i) : 8'h00;
              q_out <= rx_gate ? $unsigned(acc_q) : 8'h00;
        end
    end

endmodule
