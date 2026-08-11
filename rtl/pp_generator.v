`timescale 1ns/1ps
// =============================================================================
// Module      : pp_generator
// Description : Narrow Partial Product Generator for Radix-4 Booth Multiplier
//               (Figure 10.6 architecture)
//
//   Key change vs. previous design:
//     OLD: pp_generator received neg/two/one/zero; internally computed 2A
//          via a PP_WIDTH=52 wide shift and output 52-bit pp.
//     NEW: pp_generator receives neg/non0 only; outputs a NARROW A_WIDTH-bit
//          partial product. The 'two' (x2) shift is deferred to a dedicated
//          stage in mantissa_multiplier, AFTER this module.
//
//   This keeps ALL internal logic A_WIDTH=25 bits wide instead of 52 bits,
//   reducing the MUX and gate count for the PP generation stage.
//
//   Computation:
//     mag = non0 ? A : 0           (select A or zero, A_WIDTH bits)
//     pp  = neg  ? ~mag : mag      (bitwise-invert for -A case)
//
//   Two's-complement +1 correction for the neg case is handled via the
//   sign_corr vector in the parent (mantissa_multiplier).
// =============================================================================
module pp_generator #(
    parameter A_WIDTH = 25          // width of multiplicand (signed)
)(
    input  wire [A_WIDTH-1:0] A,    // multiplicand (signed, two's complement)
    input  wire               neg,  // negate: output ~A instead of A
    input  wire               non0, // 1 => output A (or ~A); 0 => output 0
    output wire [A_WIDTH-1:0] pp,   // narrow partial product (before 'two' shift)
    output wire               pp_neg // passthrough of neg for sign-correction use
);

    // Select magnitude: A or 0  (no 2A here -- deferred to parent)
    wire [A_WIDTH-1:0] mag = non0 ? A : {A_WIDTH{1'b0}};

    // Bitwise invert when neg; +1 correction added externally via sign_corr
    assign pp     = neg ? ~mag : mag;
    assign pp_neg = neg;

endmodule
