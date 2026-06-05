`timescale 1ns/1ps

// Top-Level 32-bit IEEE 754 Single-Precision Floating-Point Multiplier
// Architecture based on the paper:
// "FPGA Implementation of Floating-Point Multiplier Employing Carry-Lookahead Adders"
// (This implementation uses simple array multiplier for mantissa as requested)
//
// IEEE 754 Single Precision Format (32-bit):
//  [31]      [30:23]           [22:0]
//  Sign   Biased Exponent   Mantissa (fraction)
//  1 bit     8 bits            23 bits
//
// Floating-point value = (-1)^S * 2^(E-127) * 1.M
//
// Multiplication steps:
//  1) Sign    : Sp = Sa XOR Sb
//  2) Exponent: Ep = Ea + Eb - 127
//  3) Mantissa: Mp = Ma * Mb  (24x24 -> 48 bits, implicit leading 1 appended)
//  4) Normalize and round (truncate) the mantissa product
//  5) Handle special cases (zero, inf, NaN)

module fp_multiplier_32bit (
    input  [31:0] a,    // Operand A (IEEE 754 single precision)
    input  [31:0] b,    // Operand B (IEEE 754 single precision)
    output [31:0] p     // Product   (IEEE 754 single precision)
);

    // ----------------------------------------------------------------
    // Unpack operands
    // ----------------------------------------------------------------
    wire        sa = a[31];
    wire [7:0]  ea = a[30:23];
    wire [22:0] ma = a[22:0];

    wire        sb = b[31];
    wire [7:0]  eb = b[30:23];
    wire [22:0] mb = b[22:0];

    // ----------------------------------------------------------------
    // Step 1: Sign bit computation
    // ----------------------------------------------------------------
    wire sp;
    sign_block u_sign (
        .sa(sa),
        .sb(sb),
        .sp(sp)
    );

    // ----------------------------------------------------------------
    // Step 2: Exponent addition  (Ep = Ea + Eb - 127)
    // ----------------------------------------------------------------
    wire [7:0] ep_raw;
    wire       exp_cout;
    exponent_adder u_exp_add (
        .ea      (ea),
        .eb      (eb),
        .ep      (ep_raw),
        .exp_cout(exp_cout)
    );

    // ----------------------------------------------------------------
    // Step 3: Mantissa multiplication
    // Append implicit leading 1 to both mantissas -> 24-bit values
    // 1.Ma * 1.Mb => 48-bit product
    // ----------------------------------------------------------------
    wire [23:0] ma_full = {1'b1, ma};
    wire [23:0] mb_full = {1'b1, mb};
    wire [47:0] mp_raw;

    mantissa_multiplier u_mant_mul (
        .ma(ma_full),
        .mb(mb_full),
        .mp(mp_raw)
    );
    
    // ----------------------------------------------------------------
    // Step 4: Rounding
    // ----------------------------------------------------------------
    
    wire [23:0] mp_round;
    wire carry_round;
    
    fp_rounding rounding(mp_raw,mp_round);

    // ----------------------------------------------------------------
    // Step 5: Normalization
    // ----------------------------------------------------------------
    wire [22:0] mp_norm;
    wire [7:0]  ep_norm;

    normalization_block u_norm (
        .mp_raw  (mp_round),
        .ep_in   (ep_raw),
        .mp_norm (mp_norm),
        .ep_norm (ep_norm)
    );

    // ----------------------------------------------------------------
    // Step 5: Special case handling
    // ----------------------------------------------------------------
//    wire        special_detected;
//    wire        is_zero, is_inf, is_nan;
//    wire [31:0] special_result;

//    special_case_handler u_special (
//        .a                (a),
//        .b                (b),
//        .is_zero          (is_zero),
//        .is_inf           (is_inf),
//        .is_nan           (is_nan),
//        .special_detected (special_detected),
//        .special_result   (special_result)
//    );

    // ----------------------------------------------------------------
    // Output: select normal result or special result
    // ----------------------------------------------------------------
    wire [31:0] normal_result = {sp, ep_norm, mp_norm};
    assign p = normal_result;
//    assign p = special_detected ? special_result : normal_result;

endmodule
