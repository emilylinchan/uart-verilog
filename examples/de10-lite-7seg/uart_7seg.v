/**
 * @file    uart_7seg.v
 * @brief   Displays bytes received over UART on two 7-segment digits.
 *
 * Data flow:
 *   PC keyboard -> terminal -> serial cable -> i_uart_rx -> uart core
 *     -> latch byte on o_rx_valid -> split into two nibbles
 *     -> binary_to_7segment x2 -> segment pins
 *
 * The digits show the byte in HEX. Pressing 'A' in the terminal sends ASCII
 * 0x41, so the display reads "41".
 *
 * The received byte is also echoed straight back out o_uart_tx so the
 * terminal shows what you typed.
 */

module uart_7seg #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire i_clk,       // FPGA main clock
    input  wire i_rst_n,     // Async reset button, active low
    input  wire i_uart_rx,   // UART RX data (from PC)
    output wire o_uart_tx,   // UART TX data (to PC)

    // Segment 1 = upper digit (high nibble)
    output wire o_segment1_a,
    output wire o_segment1_b,
    output wire o_segment1_c,
    output wire o_segment1_d,
    output wire o_segment1_e,
    output wire o_segment1_f,
    output wire o_segment1_g,

    // Segment 2 = lower digit (low nibble)
    output wire o_segment2_a,
    output wire o_segment2_b,
    output wire o_segment2_c,
    output wire o_segment2_d,
    output wire o_segment2_e,
    output wire o_segment2_f,
    output wire o_segment2_g
);

    // ----- Asynch Reset Button Synchronizer (2-FF) -----
    reg r_rst_meta, r_rst_stable;
    always @(posedge i_clk or negedge i_rst_n)
    begin
        if (!i_rst_n)
        begin
            r_rst_meta   <= 1'b0; // Asserted state
            r_rst_stable <= 1'b0;
        end
        else
        begin
            r_rst_meta   <= 1'b1; // Constant: i_rst_n enters via the async pin only
            r_rst_stable <= r_rst_meta;
        end
    end   

    // ----- UART Core -----
    wire [7:0] w_rx_data;
    wire       w_rx_valid;
    wire       w_frame_err;
    wire       w_tx_busy;
    reg        r_tx_start;
    reg  [7:0] r_tx_data;

    uart #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (8)
    ) u_uart (
        .i_clk       (i_clk),
        .i_rst_n     (r_rst_stable),

        // TX interface
        .i_tx_start  (r_tx_start),
        .i_tx_data   (r_tx_data),
        .o_tx_busy   (w_tx_busy),
        .o_tx_done   (),          // Unused
        .o_tx        (o_uart_tx),

        // RX interface
        .i_rx        (i_uart_rx),
        .o_rx_data   (w_rx_data),
        .o_rx_valid  (w_rx_valid),
        .o_frame_err (w_frame_err)
    );

    // ----- LED Display Value -----
    reg [7:0] r_display_byte;

    always @(posedge i_clk)
    begin
        if (!r_rst_stable)
            r_display_byte <= 8'h00;
        else if (w_rx_valid && !w_frame_err)
            r_display_byte <= w_rx_data;
    end

    // ----- Echo Back to Terminal -----
    always @(posedge i_clk)
    begin
        if (!r_rst_stable)
        begin
            r_tx_start <= 1'b0;
            r_tx_data  <= 8'h00;
        end
        else
        begin
            r_tx_start <= 1'b0;

            // Only transmit if not already busy and data is not corrupted
            if (w_rx_valid && !w_frame_err && !w_tx_busy)
            begin
                r_tx_start <= 1'b1;
                r_tx_data  <= w_rx_data;
            end
        end
    end

    // ----- 7-Segment Decoding -----
    wire w_segment1_a, w_segment1_b, w_segment1_c, w_segment1_d, w_segment1_e, w_segment1_f, w_segment1_g;
    wire w_segment2_a, w_segment2_b, w_segment2_c, w_segment2_d, w_segment2_e, w_segment2_f, w_segment2_g;

    // Upper digit = high nibble
    binary_to_7segment u_7seg1(
        .i_clk        (i_clk),
        .i_binary_num (r_display_byte[7:4]),
        .o_segment_a  (w_segment1_a),
        .o_segment_b  (w_segment1_b),
        .o_segment_c  (w_segment1_c),
        .o_segment_d  (w_segment1_d),
        .o_segment_e  (w_segment1_e),
        .o_segment_f  (w_segment1_f),
        .o_segment_g  (w_segment1_g)
    );

    // Lower digit = low nibble
    binary_to_7segment u_7seg2(
        .i_clk        (i_clk),
        .i_binary_num (r_display_byte[3:0]),
        .o_segment_a  (w_segment2_a),
        .o_segment_b  (w_segment2_b),
        .o_segment_c  (w_segment2_c),
        .o_segment_d  (w_segment2_d),
        .o_segment_e  (w_segment2_e),
        .o_segment_f  (w_segment2_f),
        .o_segment_g  (w_segment2_g)
    );

    // LEDs are active low on the DE10-Lite board, so invert
    assign o_segment1_a = ~w_segment1_a;
    assign o_segment1_b = ~w_segment1_b;
    assign o_segment1_c = ~w_segment1_c;
    assign o_segment1_d = ~w_segment1_d;
    assign o_segment1_e = ~w_segment1_e;
    assign o_segment1_f = ~w_segment1_f;
    assign o_segment1_g = ~w_segment1_g;

    assign o_segment2_a = ~w_segment2_a;
    assign o_segment2_b = ~w_segment2_b;
    assign o_segment2_c = ~w_segment2_c;
    assign o_segment2_d = ~w_segment2_d;
    assign o_segment2_e = ~w_segment2_e;
    assign o_segment2_f = ~w_segment2_f;
    assign o_segment2_g = ~w_segment2_g;

endmodule