/*
 * Copyright (c) 2026 Thanusit Burinprakhon
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_tx (
    input  wire       clk,        // System clock
    input  wire       rst_n,      // Active-low reset
    input  wire       trig_load,  // High for 1 cycle to load new data
    input  wire [7:0] data_i,     // Full 8-bit In-phase component
    input  wire [7:0] data_q,     // Full 8-bit Quadrature component
    output reg        spi_sclk,   // SPI Serial Clock output to host
    output reg        spi_miso,   // SPI Serial Data output to host
    output reg        spi_busy    // Status flag (High while transmitting)
);

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;
    reg [1:0]  phase_counter; // Tracks 4 quadrants of an SCLK cycle

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg     <= 16'h0000;
            bit_count     <= 5'd0;
            spi_sclk      <= 1'b0;
            spi_miso      <= 1'b0;
            spi_busy      <= 1'b0;
            phase_counter <= 2'b00;
        end else begin
            if (trig_load && !spi_busy) begin
                shift_reg     <= {data_i, data_q};
                bit_count     <= 5'd16;
                spi_busy      <= 1'b1;
                phase_counter <= 2'b00;
                spi_sclk      <= 1'b0;
                spi_miso      <= data_i[7]; // Pre-drive first MSB out immediately
            end else if (spi_busy) begin
                phase_counter <= phase_counter + 1'b1;
                
                case (phase_counter)
                    2'b00: begin
                        spi_sclk <= 1'b1; // Rising Edge: Host samples stable data here
                    end
                    2'b10: begin
                        spi_sclk <= 1'b0; // Falling Edge: Safe to transition data now
                    end
                    2'b11: begin
                        // Shift next register element forward
                        shift_reg <= {shift_reg[14:0], 1'b0};
                        bit_count <= bit_count - 1'b1;
                        
                        if (bit_count == 5'd1) begin
                            spi_busy <= 1'b0; // Finished all 16 bits cleanly
                        end else begin
                            spi_miso <= shift_reg[14]; // Drive next bit out early
                        end
                    end
                    default: begin
                        // Do nothing during intermediate stability phases
                    end
                endcase
            end else begin
                spi_sclk <= 1'b0;
                spi_miso <= 1'b0;
            end
        end
    end

endmodule
