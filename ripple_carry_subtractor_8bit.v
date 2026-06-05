`timescale 1ns/1ps
// 8-bit Ripple Carry Subtractor
// Used for exponent adjustment in normalization block
// Implements A - B using two's complement: A + (~B) + 1
module ripple_carry_subtractor_8bit (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] diff,
    output       bout    // borrow out (active high means underflow)
);
    wire [7:0] b_inv;
    wire       cout;

    // Invert B for two's complement subtraction
    assign b_inv = ~b;

    // cin = 1 to complete two's complement of B
    ripple_carry_adder_8bit rca_sub (
        .a   (a),
        .b   (b_inv),
        .cin (1'b1),
        .sum (diff),
        .cout(cout)
    );

    // Borrow occurs when cout = 0 (result is negative)
    assign bout = ~cout;
endmodule
