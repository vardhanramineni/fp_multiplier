`timescale 1ns/1ps
// Normalization Block
// After mantissa multiplication, the 48-bit product may have the form:
//   1x.xxx...  (bit 47 = 1) => already normalized, shift right by 1, increment exponent
//   01.xxx...  (bit 46 = 1) => normalized, keep top 24 bits from bit 46 downward
// Per the paper: top 24 bits of 48-bit product are kept (truncation/round to zero)
// Exponent is adjusted based on leading 1 position
module normalization_block (
    input  [23:0] mp_raw,     // 48-bit raw mantissa product
    input  [7:0]  ep_in,      // Exponent before normalization
    output [22:0] mp_norm,    // Normalized 23-bit mantissa (no implicit bit)
    output [7:0]  ep_norm     // Adjusted exponent after normalization
);
    wire [7:0] ep_inc;
    wire       carry_dummy;

    // Increment exponent by 1
//    ripple_carry_adder_8bit exp_inc_add (
//        .a   (ep_in),
//        .b   (8'd1),
//        .cin (1'b0),
//        .sum (ep_inc),
//        .cout(carry_dummy)
//    );

    // If bit[47] = 1 => product is of form 1x.xxx, MSB is at position 47
    //   normalized mantissa = mp_raw[46:24], exponent += 1
    // If bit[47] = 0 and bit[46] = 1 => product is of form 01.xxx, MSB at 46
    //   normalized mantissa = mp_raw[45:23], exponent unchanged
    // Both cases: strip the implicit leading 1 and keep the next 23 bits

    assign mp_norm = mp_raw[23] ? mp_raw[22:0] : {mp_raw[21:0],1'b0};
    assign ep_norm = mp_raw[23] ? ep_in+8'd1        : ep_in;

endmodule
