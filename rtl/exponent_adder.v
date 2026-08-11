`timescale 1ns/1ps

// Exponent Addition Block
// Adds the two 8-bit biased exponents and subtracts the bias (127)
// Formula: E_product = E_a + E_b - 127
// Steps:
//   1) Add E_a + E_b  (9-bit result to handle overflow)
//   2) Subtract bias 127 (8'h7F) from the sum
module exponent_adder (
    input  [7:0] ea,        // Biased exponent of operand A
    input  [7:0] eb,        // Biased exponent of operand B
    output [7:0] ep,        // Biased exponent of product (before normalization)
    output       exp_cout   // Carry out from exponent addition (overflow indicator)
);
    wire [7:0] ea_plus_eb;
    wire       add_cout;
    wire [7:0] bias = 8'd127;
    wire       sub_bout;

    // Step 1: Add the two exponents
    ripple_carry_adder_8bit exp_add (
        .a   (ea),
        .b   (eb),
        .cin (1'b0),
        .sum (ea_plus_eb),
        .cout(add_cout)
    );

    // Step 2: Subtract bias (127)
    ripple_carry_subtractor_8bit exp_sub (
        .a   (ea_plus_eb),
        .b   (bias),
        .diff(ep),
        .bout(sub_bout)
    );

    assign exp_cout = add_cout;
endmodule
