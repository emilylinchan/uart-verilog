/**
 * @file    binary_to_7segment.v
 * @brief   Decodes a 4-bit binary value (0-F) into 7-segment display
 *          segment drive signals, registered on the clock edge.
 */

module binary_to_7segment(
    input       i_clk,
    input [3:0] i_binary_num,
    output      o_segment_a,
    output      o_segment_b,
    output      o_segment_c,
    output      o_segment_d,
    output      o_segment_e,
    output      o_segment_f,
    output      o_segment_g
);

    // Segment bits, MSB to LSB: a b c d e f g
    // Active-high; inverted by the caller if the target board wires segments active-low
    reg [6:0] r_hex_encoding = 7'h00;

    // Lookup table mapping each 4-bit value to its segment pattern
    always @(posedge i_clk)
        begin
            case (i_binary_num)
                4'b0000: r_hex_encoding <= 7'h7E; // 0
                4'b0001: r_hex_encoding <= 7'h30; // 1
                4'b0010: r_hex_encoding <= 7'h6D; // 2
                4'b0011: r_hex_encoding <= 7'h79; // 3
                4'b0100: r_hex_encoding <= 7'h33; // 4
                4'b0101: r_hex_encoding <= 7'h5B; // 5
                4'b0110: r_hex_encoding <= 7'h5F; // 6
                4'b0111: r_hex_encoding <= 7'h70; // 7
                4'b1000: r_hex_encoding <= 7'h7F; // 8
                4'b1001: r_hex_encoding <= 7'h7B; // 9
                4'b1010: r_hex_encoding <= 7'h77; // A
                4'b1011: r_hex_encoding <= 7'h1F; // b
                4'b1100: r_hex_encoding <= 7'h4E; // C
                4'b1101: r_hex_encoding <= 7'h3D; // d
                4'b1110: r_hex_encoding <= 7'h4F; // E
                4'b1111: r_hex_encoding <= 7'h47; // F
            endcase
        end
    
    assign o_segment_a = r_hex_encoding[6];
    assign o_segment_b = r_hex_encoding[5];
    assign o_segment_c = r_hex_encoding[4];
    assign o_segment_d = r_hex_encoding[3];
    assign o_segment_e = r_hex_encoding[2];
    assign o_segment_f = r_hex_encoding[1];
    assign o_segment_g = r_hex_encoding[0];

endmodule