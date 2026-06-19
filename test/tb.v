`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();
  // Wire up the inputs and outputs:
    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
 `ifdef GL_TEST
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
 `endif
  
   // Replace tt_um_example with your module name(DUT instantiation):
    tt_um_thanusit_nmr_cores user_project (
        // Include power ports for the Gate Level test:
       `ifdef GL_TEST
          .VPWR(VPWR),
          .VGND(VGND),
       `endif
          .ui_in  (ui_in),    // Dedicated inputs
          .uo_out (uo_out),   // Dedicated outputs
          .uio_in (uio_in),   // IOs: Input path
          .uio_out(uio_out),  // IOs: Output path
          .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
          .ena    (ena),      // enable - goes high when design is selected
          .clk    (clk),      // clock
          .rst_n  (rst_n)     // not reset
    );

  // Watch aliases
    wire rf_pulse_A = uo_out[0];
    wire rf_pulse_B = uo_out[1];
    wire rx_gate    = uo_out[2];
    wire status_busy = uo_out[3];

  // Clock generator (50MHz -> 20ns period)
    always #10 clk = ~clk;

  // SPI Configuration Master emulation task
    task spi_send_word(input [127:0] data_stream);
        integer i;
        begin
            ui_in[3] = 1'b0; // Pull SS_N Low
            #40;
            for (i = 127; i >= 0; i = i - 1) begin
                ui_in[2] = data_stream[i]; // Set MOSI bit
                #20;
                ui_in[1] = 1'b1;           // SCLK High
                #40;
                ui_in[1] = 1'b0;           // SCLK Low
                #20;
            end
            #40;
            ui_in[3] = 1'b1; // Pull SS_N High (Applies Config changes)
            #100;
        end
    endtask

    initial begin
        // Initialize Inputs
        clk    = 0;
        rst_n  = 0;
        ui_in  = 8'h08; // SS_N initialized high, all others low
        uio_in = 8'h00;

       // Reset Sequence
        #100;
        rst_n = 1;
        #100;

     // Configuration values setup: 
       // Data arrangement: ({cfg_tA, tau, cfg_tB, cfg_echo_count})
       // Example: ({32'd10, 32'd40, 32'd20, 32'd4}) outputs cfg_tA=10, tau=40, cfg_tB=20, 
       // and cfg_echo_count=4 to the SPI 128-bits shift register.
        
        $display("[TB] Sending configuration packet over SPI interface...");
        spi_send_word({32'd10, 32'd40, 32'd20, 32'd4});
       repeat (4) begin
        // Trigger pulse sequencing sequence execution
        $display("[TB] Pulsing START to activate sequence execution.");
        #40;
        ui_in[0] = 1'b1; // Start high
        #20;
        ui_in[0] = 1'b0; // Start low

        // Track outputs down active sequencing states
        @(posedge rf_pulse_A);
        $display("[TB] Detected 90-degree RF channel excitation start.");
        
        @(posedge rf_pulse_B);
        $display("[TB] Detected 180-degree refocusing RF pulse start.");
        
        @(posedge rx_gate);
        $display("[TB] Data Acquisition window active.");

        // Wait until completion
        
        @(negedge status_busy);
        $display("[TB] Sequencer finished sequence and returned to IDLE.");

        #200;  //delay 200 clk before start next pulse sequence
        end
        $display("[TB] Simulation completed successfully.");
      // Reset Sequence
        #100;
        rst_n = 0;
        #100;
    end
   
// ========================================================================
// APPENDED: Non-Invasive Demodulator RF Signal Injector
// ========================================================================

    // Math parameters for the RF carrier synthesis (50 MHz clock)
    real carrier_freq = 1000000;   // 1 MHz RF Carrier
    real sample_freq  = 50000000;  // 50 MHz System Clock
    real phase_deg    = 0.0;
    integer sample_idx = 0;
    integer tb_filter_cnt = 0; // TB-local counter to sample demod outputs every 8 cycles

    initial begin
      // Continuously monitor the simulation for every RX window
      forever begin
        // Monitor the simulation and wait until the sequencer triggers the RX window
        @(posedge rx_gate);
        $display("[DEMOD_TB] RX Window active! Intercepting ADC input with 1MHz RF stream...");

        // Process samples continuously as long as the data acquisition window is open
        while (rx_gate) begin
            // Calculate square wave phase approximation
            phase_deg = (sample_idx * (carrier_freq / sample_freq) * 360.0) % 360.0;
            
            if (phase_deg < 180.0) begin
                // Force the adc_in pin high
                force ui_in[4] = 1'b1; 
            end else begin
                force ui_in[4] = 1'b0;
            end
            
            sample_idx = sample_idx + 1;
            @(posedge clk);
        end
        // Release control immediately when rx_gate drops to restore clean operation
        release ui_in[4];
      end
         // restore idle value for ui_in[4] so the vector matches the initial state
        ui_in[4] = 1'b0;
        $display("[DEMOD_TB] RX Window closed. Released internal ADC line control.");
    end

   // Monitor Block: Track the integration values to your console in real-time
    initial begin
      forever begin
        @(posedge rx_gate);
        // Wait 4 clock cycles to align with internal LO pipeline startup
        repeat (4) @(posedge clk); 
        
        $display("[DEMOD_TB] Tracking integrated boxcar outputs (sampled every 8 cycles):");
        $display("Time\t\t\tI_OUT\tQ_OUT");
        $display("----------------------------------------");
        
        while (rx_gate) begin
            // Increment TB-side filter counter to sample every 8 cycles (3-bit rollover equivalent)
            if (tb_filter_cnt == 7) begin
                // demod I is uio_out[3:0], demod Q is uio_out[7:4]
                // Sign-extend 4-bit values to 16-bit for display
                $display("%t\t%d\t%d",
                         $time,
                         $signed({{12{uio_out[3]}}, uio_out[3:0]}),
                         $signed({{12{uio_out[7]}}, uio_out[7:4]}));
            end
            tb_filter_cnt = tb_filter_cnt + 1;
            if (tb_filter_cnt == 8)
                tb_filter_cnt = 0;
            @(posedge clk);
        end
      end 
    end
   
   // Dump the signals to a FST file. You can view it with gtkwave or surfer.
    initial begin
      $dumpfile("tb.vcd");
      $dumpvars(0, tb);
      #1;
   end
   
endmodule
