`timescale 1ns / 1ps
`default_nettype none

module tb_tt_um_thanusit_nmr_cores;

    // Testbench signals
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg       ena;
    reg       clk;
    reg       rst_n;

    // Clock generation (50 MHz clock -> 20ns period)
    always #10 clk = ~clk;

    // Instantiate the Top Module (DUT)
    tt_um_thanusit_nmr_cores dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Aliases for scannable waveform monitoring
    wire psq_rf_A    = uo_out[0];
    wire psq_rf_B    = uo_out[1];
    wire psq_rx_gate = uo_out[2];
    wire psq_busy    = uo_out[3];
    
    wire [3:0] monitor_I = uio_out[3:0];
    wire [3:0] monitor_Q = uio_out[7:4];

    // Generate a continuous, synthetic 1-bit RF data stream on ui_in[4]
    // Changing state every 2 clock cycles to mimic an incoming IF/RF signal
    reg mock_rf_signal;
    always begin
        #40 mock_rf_signal = 1'b1;
        #40 mock_rf_signal = 1'b0;
    end

    // Map our testbench signals dynamically onto the input bus
    always @(*) begin
        ui_in[4] = mock_rf_signal; // Feed mock digitized RF to the ADC input
        uio_in  = uio_out;        // Mimic loopback behavior on the bi-directional bus
    end

    // Main Test Procedure
    initial begin
        // Initialize inputs
        clk    = 1'b0;
        rst_n  = 1'b0;
        ena    = 1'b1;
        ui_in  = 8'b0;
        
        // Wait 5 clock cycles and release system reset
        repeat (5) @(posedge clk);
        #1 rst_n = 1'b1;
        
        $display("[STATUS] Reset released. Demodulator outputs should be 0 (rx_gate is inactive).");
        repeat (10) @(posedge clk);

        // --- VERIFICATION STEP 1: VERIFY IDLE STATE (rx_gate = 0) ---
        if (psq_rx_gate == 1'b0 && monitor_I == 4'b0 && monitor_Q == 4'b0) begin
            $display("[PASS] Demodulator successfully idle while rx_gate is inactive.");
        end else begin
            $display("[FAIL] Demodulator producing non-zero outputs while rx_gate is inactive!");
        end

        // --- VERIFICATION STEP 2: ACTIVATE RX WINDOW ---
        $display("[STATUS] Pulsing UI_IN[0] to trigger the Pulse Sequencer...");
        ui_in[0] = 1'b1; // Trigger signal for pulse_sequencer
        @(posedge clk);
        #1 ui_in[0] = 1'b0;

        // Wait until your pulse sequencer opens the RX Gate window
        wait(psq_rx_gate == 1'b1);
        $display("[STATUS] rx_gate went HIGH. Demodulator processing active data stream.");

        // Let the demodulator mix and accumulate over several filtration cycles
        repeat (40) @(posedge clk);
        $display("[STATUS] Active Data Window Snippet -> I-Out: %d, Q-Out: %d", monitor_I, monitor_Q);

        // --- VERIFICATION STEP 3: CLOSE RX WINDOW & CHECK FOR LOCK ---
        // Wait until the sequencer automatically closes the gate window
        wait(psq_rx_gate == 1'b0);
        $display("[STATUS] rx_gate went LOW. Verifying demodulator freeze behavior...");
        
        // Capture data immediately upon closure
        reg [3:0] frozen_I;
        reg [3:0] frozen_Q;
        frozen_I = monitor_I;
        frozen_Q = monitor_Q;

        // Wait another 20 clock cycles to confirm no new math or shifting happens
        repeat (20) @(posedge clk);

        if (monitor_I == frozen_I && monitor_Q == frozen_Q) begin
            $display("[PASS] Demodulator locked flawlessly. No logic leakage outside of rx_gate.");
        end else begin
            $display("[FAIL] Demodulator outputs changed while rx_gate was down!");
        end

        // Finish simulation
        $display("[STATUS] Testbench execution completed successfully.");
    //    $finish;
    end

    // Generate VCD file for waveform viewer (GTKWave / ModelSim)
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule
