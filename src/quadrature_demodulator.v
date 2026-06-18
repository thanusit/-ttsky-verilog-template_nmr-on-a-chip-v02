/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

// ============================================================================
// Sub-Module: Quadrature Demodulator
// Optimized for Sky130 area/routability constraints (Tiny Tapeout)
// ============================================================================
module quadrature_demodulator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_gate, // Active high: Demodulate only during RX windows
    input  wire       adc_in,  // 1-bit comparative/Delta-Sigma input
    output reg  [3:0] i_out,   // Filtered In-phase component
    output reg  [3:0] q_out    // Filtered Quadrature component
);

    // 2-bit counter to generate 0, 90, 180, 270 degree Local Oscillator (LO)
    reg [1:0] lo_phase;
    
    // LO signals represented as signed 2-bit values (+1 or -1)
    // 2'b01 = +1, 2'b11 = -1
    reg signed [1:0] lo_i;
    reg signed [1:0] lo_q;

    // Local Oscillator Generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lo_phase <= 2'b0;
            lo_i     <= 2'sb01;
            lo_q     <= 2'sb01;
        end else if (rx_gate) begin
            lo_phase <= lo_phase + 1'b1;
            case (lo_phase)
                2'b00: begin lo_i <= 2'sb01; lo_q <= 2'sb00; end // 0 deg (I=1, Q=0)
                2'b01: begin lo_i <= 2'sb00; lo_q <= 2'sb01; end // 90 deg (I=0, Q=1)
                2'b10: begin lo_i <= 2'sb11; lo_q <= 2'sb00; end // 180 deg (I=-1, Q=0)
                2'b11: begin lo_i <= 2'sb00; lo_q <= 2'sb11; end // 270 deg (I=0, Q=-1)
            endcase
        end else begin
            lo_phase <= 2'b0;
            lo_i     <= 2'sb00;
            lo_q     <= 2'sb00;
        end
    end

    // Convert 1-bit input to signed representation (+1 or -1)
    wire signed [1:0] signed_adc = adc_in ? 2'sb01 : 2'sb11;

    // Mixer outputs (Signal * LO)
    reg signed [1:0] mixed_i;
    reg signed [1:0] mixed_q;

    always @(*) begin
        mixed_i = signed_adc * lo_i;
        mixed_q = signed_adc * lo_q;
    end

    // Moving Average Low-Pass Filters (Accumulate over 8 clock cycles)
    reg [2:0]           filter_cnt;
    reg signed [4:0]    acc_i;
    reg signed [4:0]    acc_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            filter_cnt <= 3'b0;
            acc_i      <= 5'sb0;
            acc_q      <= 5'sb0;
            i_out      <= 4'b0;
            q_out      <= 4'b0;
        end else if (rx_gate) begin
            filter_cnt <= filter_cnt + 1'b1;
            
            // Accumulate mixer results
            acc_i <= acc_i + mixed_i;
            acc_q <= acc_q + mixed_q;

            // Output data and reset accumulator every 8 cycles
            if (filter_cnt == 3'b111) begin
                i_out      <= acc_i[4:1]; // Truncate/scale to match 4-bit output
                q_out      <= acc_q[4:1];
                acc_i      <= 5'sb0;
                acc_q      <= 5'sb0;
            end
        end else begin
            filter_cnt <= 3'b0;
            acc_i      <= 5'sb0;
            acc_q      <= 5'sb0;
        end
    end

endmodule
