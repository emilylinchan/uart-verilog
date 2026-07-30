/**
 * @file    uart_rx.v
 * @brief   UART receiver with 16x oversampling.
 *
 * Samples each bit near its center using the i_baud_tick_16x strobe and
 * uses 3-sample majority voting for noise tolerance.
 *
 * Frame: 1 start bit (0), DATA_BITS data (LSB first), 1 stop bit (1).
 * 
 * Protocol:
 *   - rx_data   : Received data byte (valid when rx_valid pulses)
 *   - rx_valid  : 1-cycle pulse indicating a received valid byte
 *   - frame_err : 1-cycle pulse (asserted with rx_valid) if the stop bit was low
 */

module uart_rx #(
    parameter integer DATA_BITS = 8
)(
    input wire                 i_clk,         
    input wire                 i_rst_n,         // Active-low synchronous reset
    input wire                 i_baud_tick_16x, // 16x bit-rate oversampling strobe
    input wire                 i_rx,            // Serial input line
    output reg [DATA_BITS-1:0] o_rx_data,       // Received data byte
    output reg                 o_rx_valid,      // Data byte ready pulse
    output reg                 o_frame_err      // Bad stop bit pulse
);

    // ----- State Encoding -----
    localparam S_IDLE  = 2'b00;
    localparam S_START = 2'b01;
    localparam S_DATA  = 2'b10;
    localparam S_STOP  = 2'b11;    

    reg [1:0]                   r_state;
    reg [3:0]                   r_os_count; // Oversample position (0-15) within a bit
    reg [DATA_BITS-1:0]         r_shift;    // Shift register, LSB shifted in first
    reg [$clog2(DATA_BITS)-1:0] r_bit_idx;  // Counts data bits received

    // 3-sample majority vote taken at oversample positions 6,7,8 (bit center)
    reg [1:0] r_vote;    // Running count of data samples in the window
    reg       r_bit_val; // Resolved bit value

    always @(posedge i_clk)
    begin
        if (!i_rst_n)
        begin
            r_state     <= S_IDLE;
            r_os_count  <= 0;
            r_bit_idx   <= 0;
            r_shift     <= 0;
            r_vote      <= 0;
            r_bit_val   <= 1'b0;
            o_rx_data   <= 0;
            o_rx_valid  <= 1'b0;
            o_frame_err <= 1'b0;
        end
        else
        begin
            o_rx_valid  <= 1'b0; // Overridden below when frame ends 
            o_frame_err <= 1'b0;

            if (i_baud_tick_16x)
            begin
                // ----- FSM -----
                case (r_state)

                    // Wait for the falling edge that starts a frame
                    S_IDLE:
                    begin
                        if (i_rx == 1'b0)
                        begin
                            r_state    <= S_START;
                            r_os_count <= 0;
                        end
                    end

                    // Confirm start bit is still low at its center (position 7)
                    S_START:
                    begin
                        if (r_os_count == 4'd7 && i_rx != 1'b0)
                        begin
                            r_state    <= S_IDLE;          // Glitch occurred, false start
                            r_os_count <= r_os_count + 1;
                        end
                        else if (r_os_count == 4'd15)
                        begin
                            r_os_count <= 0;      // Reset counter when aligned with bit period
                            r_bit_idx  <= 0;
                            r_state    <= S_DATA;
                        end
                        else
                        begin
                            r_os_count <= r_os_count + 1;
                        end
                    end

                    // Sample each data bit, vote across positions 6,7,8
                    S_DATA:
                    begin
                        // Accumulate votes around the bit center
                        if (r_os_count == 4'd6)
                        begin
                            r_vote <= {1'b0, i_rx};
                        end
                        else if (r_os_count == 4'd7)
                        begin
                            r_vote <= r_vote + i_rx;
                        end
                        else if (r_os_count == 4'd8)
                        begin
                            r_bit_val <= (r_vote + i_rx >= 2'd2); // Majority of 3
                        end

                        // Commit resolved bit at the end of the oversampling period
                        if (r_os_count == 4'd15)
                        begin
                            r_shift    <= {r_bit_val, r_shift[DATA_BITS-1:1]} // LSB first, shift right
                            r_os_count <= 0;
                            if (r_bit_idx == DATA_BITS-1)
                            begin
                                r_state <= S_STOP;
                            end
                        end
                        else
                        begin
                            r_bit_idx <= r_bit_idx + 1;
                        end
                    end

                    // Check the stop bit at its center, then publish
                    S_STOP:
                    begin
                        if (r_os_count == 4'd15)
                        begin
                            o_rx_data   <= r_shift;
                            o_rx_valid  <= 1'b1; 
                            o_frame_err <= (i_rx != 1'b1); // Stop must be high
                            r_os_count  <= 0;
                            r_state     <= S_IDLE;
                        end
                        else
                        begin
                            r_os_count <= r_os_count + 1;
                        end
                    end

                    default: r_state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
