/**
 * @file    uart_tb.v
 * @brief   Self-checking loopback testbench for the UART core.
 *
 * Wires tx -> rx directly, sends a set of bytes through the transmitter, and
 * checks each one comes back out of the receiver correctly. Also drives a
 * deliberately malformed frame to confirm frame_err is raised.
 */

`timescale 1ns / 1ps

module uart_tb();

    localparam CLK_FREQ  = 50_000_000;
    localparam BAUD_RATE = 115_200;
    localparam DATA_BITS = 8;

    // Periods in ns (timescale is 1ns). Integer ns is close enough for timing.
    localparam CLK_PERIOD = 1_000_000_000 / CLK_FREQ;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE;
    localparam NUM_FRAMES = 4;
    localparam TIMEOUT_NS = (DATA_BITS + 3) * BIT_PERIOD * NUM_FRAMES * 4; // 4x safety margin

    // ----- DUT I/O -----
    reg                  r_clk      = 1'b0;
    reg                  r_rst_n    = 1'b0;
    reg                  r_tx_start = 1'b0;
    reg [DATA_BITS-1:0]  r_tx_data  = 0;
    wire                 w_tx_busy, w_tx_done, w_tx;
    wire [DATA_BITS-1:0] w_rx_data;
    wire                 w_rx_valid, w_frame_err;

    wire w_loopback;        // Pass TX straight to RX
    reg  r_force_rx = 1'b0; // When high, drive RX manually (for error test)
    reg  r_rx_drive = 1'b1;

    // Line hijack mux to inject an error
    assign w_loopback = r_force_rx ? r_rx_drive : w_tx;

    // ----- DUT -----
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_BITS(DATA_BITS)
    ) dut (
        .i_clk       (r_clk),
        .i_rst_n     (r_rst_n),

        // TX interface
        .i_tx_start  (r_tx_start),
        .i_tx_data   (r_tx_data),
        .o_tx_busy   (w_tx_busy),
        .o_tx_done   (w_tx_done),
        .o_tx        (w_tx),

        // RX interface
        .i_rx        (w_loopback),
        .o_rx_data   (w_rx_data),
        .o_rx_valid  (w_rx_valid),
        .o_frame_err (w_frame_err)
    );

    // ----- Tests -----
    always #(CLK_PERIOD/2) r_clk = ~r_clk;

    integer errors = 0;
    integer checks = 0;

    // Block until the RX asserts w_rx_valid
    task wait_rx_valid();
    begin
        @(posedge r_clk);
        while (w_rx_valid !== 1'b1) @(posedge r_clk);
    end
    endtask

    // Send 1 byte and self-check the round trip
    task send_and_check(input [DATA_BITS-1:0] i_data);
    begin
        @(posedge r_clk);
        r_tx_data <= i_data;
        r_tx_start <= 1'b1;
        @(posedge r_clk);
        r_tx_start <= 1'b0;
    
        wait_rx_valid; // w_rx_data, w_frame_err valid on this edge

        checks = checks + 1;
        if (w_rx_data !== i_data)
        begin
            errors = errors + 1;
            $display("[%0t] FAIL: sent %0h, received %0h", $time, i_data, w_rx_data);
        end
        else if (w_frame_err !== 1'b0)
        begin
            errors = errors + 1;
            $display("[%0t] FAIL: sent %02h, received unexpected frame error", $time, i_data);
        end
        else
        begin
            $display("[%0t] PASS: %02h round-tripped", $time, i_data);
        end
    end
    endtask

    // Drive a frame with a bad (low) stop bit to force w_frame_err
    task drive_bad_stop(input [DATA_BITS-1:0] i_data);
    begin
        @(posedge r_clk);
        r_tx_data <= i_data;
        r_tx_start <= 1'b1;
        @(posedge r_clk);
        r_tx_start <= 1'b0;

        // Wait for TX to finish the frame and then force the line low so 
        // that RX samples a bad stop bit
        @(posedge r_clk);
        while (w_tx_done !== 1'b1) @(posedge r_clk);
        r_force_rx <= 1'b1;
        r_rx_drive <= 1'b0; // Corrupt the stop bit by driving the line low

        wait_rx_valid;      // RX publishes the bad frame

        checks = checks + 1;
        if (w_frame_err === 1'b1)
        begin
            $display("[%0t] PASS: frame error raised on bad stop bit", $time);
        end
        else 
        begin
            errors = errors + 1;
            $display("[%0t] FAIL: frame error not raised on bad stop bit", $time);
        end

        // Idle high and hand line back to TX
        r_rx_drive <= 1'b1;
        r_force_rx <= 1'b0;
    end
    endtask

    // ----- Main Test Sequence -----
    initial
    begin
        // Reset 
        r_rst_n = 1'b0;
        repeat (2) @(posedge r_clk);
        r_rst_n = 1'b1;
        @(posedge r_clk);

        // Test various byte patterns
        send_and_check(8'h00); // 00000000
        send_and_check(8'hFF); // 11111111
        send_and_check(8'h9A); // 10011010

        // Test error
        drive_bad_stop(8'h3C); // 00111100

        // Summary output
        $display("----------------------------------------");
        $display("Checks run : %0d", checks);
        $display("Failures   : %0d", errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: %0d TEST(S) FAILED", errors);
        $display("----------------------------------------");
        $finish;
    end

    // ----- Watchdog Safety Timeout -----
    initial
    begin
        #(TIMEOUT_NS);
        $display("[%0t] FAIL: testbench hung — w_rx_valid never asserted", $time);
        $finish;
    end

    // ----- Waveform Output -----
    initial
    begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);     // Log entire hierarchy
    end

endmodule