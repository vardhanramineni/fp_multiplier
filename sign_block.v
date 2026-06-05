`timescale 1ns/1ps

// Sign Bit Computation Block
// Sign of product = XOR of sign bits of operands
// As per IEEE 754: positive * positive = positive
//                  negative * negative = positive
//                  positive * negative = negative
module sign_block (
    input  sa,   // Sign bit of operand A
    input  sb,   // Sign bit of operand B
    output sp    // Sign bit of product
);
    assign sp = sa ^ sb;
endmodule
