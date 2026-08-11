`timescale 1ns/1ps
// =============================================================================
// Module      : mantissa_multiplier
// Description : 24x24 Unsigned Mantissa Multiplier
//               Radix-4 Modified Booth Encoding (Figure 10.6 style)
//               + Narrow Partial Product Generation
//               + Post-generation 'two' shift stage
//               + Dadda Tree Reduction
//               + Final Carry-Propagate Adder (CPA)
//
// -----------------------------------------------------------------------
// Data-flow:
//
//   Radix-4 Booth Encoder (neg, two, non0)
//          |
//          v
//   Narrow PP Generator  [PP_NARROW = 25 bits]
//   pp = non0 ? (neg ? ~A : A) : 0
//          |
//          v
//   'two' Shift Stage    [PP_WIDE = 26 bits]
//   two=0: pp_wide = {pp[MSB], pp}      (sign-extend by 1 bit)
//   two=1: pp_wide = {pp, neg}          (shift-left by 1, insert neg at LSB)
//          |
//          v
//   Alignment: pp_wide placed at correct bit position (shift by 2*i)
//   Each aligned row is exactly PP_WIDE + 2*(NUM_PP-1) = 26+24 = 50 bits
//          |
//          + sign_corr row (bit[2*i] = pp_neg_flag[i], structural)
//          |
//          v
//   Dadda Tree Reduction  (dadda_reduce.v)   [TREE_W = 52 bits]
//          |
//          v
//   Carry-Propagate Adder (ripple_carry_adder_n.v)
//          |
//          v
//   48-bit Mantissa Product P[47:0]
//
// -----------------------------------------------------------------------
// Width justification:
//
//   PP_NARROW = 25   : narrow pp_generator output (just A or ~A or 0)
//   PP_WIDE   = 26   : after 'two' shift (A or 2A, one bit wider)
//
//   ALN_W = PP_WIDE + 2*(NUM_PP-1)
//         = 26 + 2*12 = 26 + 24 = 50 bits
//   This is the EXACT width needed to hold the widest aligned PP
//   (PP[12] shifted left by 24 bits: occupies bits[24..49]).
//
//   OLD design used ALN_W=76 because pp_generator output was 52 bits
//   (sign-extended + 2A computed inside).  With the new narrow 26-bit
//   pp_wide, ALN_W=50 is correct and sufficient.
//
//   TREE_W = ALN_W + 2 = 52 bits
//   2 guard bits above the 50-bit aligned width absorb carry growth
//   through the Dadda reduction stages (log2(14) ~ 3.8 bits needed;
//   the 2 extra bits on top of ALN_W = 50 > 48 product width give
//   sufficient margin since the unsigned product fits in 48 bits).
//
//   Hardware saving vs. old design:
//     Dadda tree : 88-bit wide -> 52-bit wide  (~41% narrower)
//     CPA        : 88-bit      -> 52-bit        (~41% smaller)
//     All internal wires proportionally smaller.
//
// -----------------------------------------------------------------------
// Unsigned -> Signed bridge:
//   IEEE-754 mantissas are UNSIGNED 24-bit. Zero-extend to 25 bits so
//   the signed Booth core sees non-negative values. bits[47:0] of the
//   25x25 signed product equal the correct unsigned 24x24 product.
// -----------------------------------------------------------------------
// Synthesizability:
//   - Pure structural Verilog-2001 (generate/genvar only).
//   - No behavioral arithmetic (+, *, <<) in the synthesis path.
//   - 'two' shift is a 1-bit concat, not a barrel shifter.
//   - Alignment shifts are fixed offsets resolved at elaboration time.
//   - Sign correction is per-bit wire assignment (no adder needed).
//   - Dadda tree recursion terminates at N<=2 (bounded hierarchy).
// =============================================================================

module mantissa_multiplier (
    input  wire [23:0] A,   // 24-bit unsigned mantissa (implicit 1 included)
    input  wire [23:0] B,   // 24-bit unsigned multiplier (implicit 1 included)
    output wire [47:0] P    // 48-bit unsigned product
);

    // =========================================================================
    // Zero-extend unsigned 24-bit inputs to 25-bit signed (non-negative)
    // =========================================================================
    wire [24:0] A25 = {1'b0, A};
    wire [24:0] B25 = {1'b0, B};

    // =========================================================================
    // Width parameters
    // =========================================================================
    localparam A_W       = 25;           // Multiplicand width (signed)
    localparam NUM_PP    = 13;           // Number of Radix-4 Booth partial products
    localparam PP_NARROW = A_W;          // 25 bits: pp_generator output
    localparam PP_WIDE   = A_W + 1;      // 26 bits: after 'two' shift (A or 2A)

    // ALN_W: exact width to hold the widest aligned partial product.
    //   PP[12] is shifted left by 2*12=24 bits -> needs bits[24..49]
    //   ALN_W = PP_WIDE + 2*(NUM_PP-1) = 26 + 24 = 50
    localparam ALN_W     = PP_WIDE + 2*(NUM_PP-1);  // 50 bits

    // TREE_W: Dadda tree internal width.
    //   Add 2 guard bits above ALN_W=50 for carry absorption.
    //   (Product fits in 48 bits; 50 already covers it with 2 extra.)
    localparam TREE_W    = ALN_W + 2;               // 52 bits

    localparam NUM_ROWS  = NUM_PP + 1;              // 14 rows (13 PPs + sign_corr)

    // =========================================================================
    // Extend B25 to 27 bits for Booth group extraction
    //   b_ext[0]     = implicit B[-1] = 0
    //   b_ext[25:1]  = B25[24:0]
    //   b_ext[26:25] = sign extension (B25[24] = 0 for unsigned inputs)
    // =========================================================================
    wire [26:0] b_ext = {B25[24], B25[24], B25[24:0], 1'b0};

    // =========================================================================
    // 13 overlapping 3-bit Booth groups: b_group[i] = b_ext[2i+2 : 2i]
    // =========================================================================
    wire [2:0] b_group [0:NUM_PP-1];
    genvar gi;
    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_grp
            assign b_group[gi] = b_ext[2*gi+2 : 2*gi];
        end
    endgenerate

    // =========================================================================
    // 13 Booth Encoders -> neg, two, non0
    // =========================================================================
    wire [NUM_PP-1:0] enc_neg, enc_two, enc_non0;

    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_enc
            booth_encoder u_enc (
                .b_tri (b_group[gi] ),
                .neg   (enc_neg [gi]),
                .two   (enc_two [gi]),
                .non0  (enc_non0[gi])
            );
        end
    endgenerate

    // =========================================================================
    // 13 Narrow Partial Product Generators  [PP_NARROW = 25 bits]
    //
    //   pp_raw[i] = enc_non0[i] ? (enc_neg[i] ? ~A25 : A25) : 0
    //
    //   No 2A computation, no sign-extension inside the generator.
    // =========================================================================
    wire [PP_NARROW-1:0] pp_raw      [0:NUM_PP-1];
    wire                 pp_neg_flag [0:NUM_PP-1];

    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_ppg
            pp_generator #(
                .A_WIDTH (A_W)
            ) u_ppg (
                .A      (A25            ),
                .neg    (enc_neg [gi]   ),
                .non0   (enc_non0[gi]   ),
                .pp     (pp_raw[gi]     ),
                .pp_neg (pp_neg_flag[gi])
            );
        end
    endgenerate

    // =========================================================================
    // 'Two' Shift Stage  [PP_WIDE = 26 bits]
    //   (applied AFTER pp_generator, keeping generator at 25-bit width)
    //
    //   two=0: pp_wide = {pp_raw[MSB], pp_raw}    sign-extend by 1 bit
    //   two=1: pp_wide = {pp_raw,      enc_neg}   shift-left by 1, LSB = neg
    //
    //   Why {pp_raw, neg} gives the correct result for two=1:
    //     neg=0 -> pp_raw = A  ->  {A,  0} = 2A          (correct)
    //     neg=1 -> pp_raw = ~A ->  {~A, 1} = ~(A<<1)
    //                                      = ~(2A)        (correct)
    //     The +1 for full -2A is added via sign_corr at bit position 2*i.
    // =========================================================================
    wire [PP_WIDE-1:0] pp_wide [0:NUM_PP-1];

    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_two_shift
            assign pp_wide[gi] = enc_two[gi]
                ? {pp_raw[gi], enc_neg[gi]}               // 2A / ~(2A): concat
                : {pp_raw[gi][PP_NARROW-1], pp_raw[gi]};  // A  / ~A:    sign-ext
        end
    endgenerate

    // =========================================================================
    // Alignment: place pp_wide at bit position 2*i within ALN_W=50 bits
    //
    //   pp_aligned[i] = sign_extend(pp_wide[i]) << (2*i)
    //
    //   Bit positions used by each PP after shift:
    //     PP[0]  -> bits [ 0 .. 25]   (26 bits at offset 0)
    //     PP[1]  -> bits [ 2 .. 27]   (26 bits at offset 2)
    //     PP[2]  -> bits [ 4 .. 29]
    //     ...
    //     PP[12] -> bits [24 .. 49]   (26 bits at offset 24)
    //   Maximum bit index = 49  ->  ALN_W = 50  (correct, no wasted bits)
    // =========================================================================
    wire signed [ALN_W-1:0] pp_aligned [0:NUM_PP-1];

    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_aln
            assign pp_aligned[gi] =
                ( {{(ALN_W-PP_WIDE){pp_wide[gi][PP_WIDE-1]}}, pp_wide[gi]} ) << (2*gi);
        end
    endgenerate

    // =========================================================================
    // Sign Correction Vector  [ALN_W = 50 bits, structural]
    //
    //   Each negated PP needs a +1 at its aligned bit-0 position (= 2*i).
    //   Positions used: 0, 2, 4, ..., 24  (distinct even indices -> no carry
    //   between them -> OR-reduction equals addition here, no adder needed).
    //
    //   sign_corr[2*i] = pp_neg_flag[i]
    //   sign_corr[all other bits] = 0
    // =========================================================================
    wire [ALN_W-1:0] sign_corr;
    genvar sc;
    generate
        for (sc = 0; sc < ALN_W; sc = sc + 1) begin : gen_sc
            if (sc % 2 == 0 && (sc/2) < NUM_PP)
                assign sign_corr[sc] = pp_neg_flag[sc/2];
            else
                assign sign_corr[sc] = 1'b0;
        end
    endgenerate

    // =========================================================================
    // Pack 13 aligned PPs + 1 sign-correction row into the Dadda tree bus
    //   Each row: sign/zero-extend from ALN_W=50 to TREE_W=52 bits.
    // =========================================================================
    wire [NUM_ROWS*TREE_W-1:0] dadda_rows_in;

    generate
        for (gi = 0; gi < NUM_PP; gi = gi + 1) begin : gen_pack_pp
            assign dadda_rows_in[gi*TREE_W +: TREE_W] =
                {{(TREE_W-ALN_W){pp_aligned[gi][ALN_W-1]}}, pp_aligned[gi]};
        end
    endgenerate

    // sign_corr is always non-negative -> zero-extend to TREE_W
    assign dadda_rows_in[NUM_PP*TREE_W +: TREE_W] =
        {{(TREE_W-ALN_W){1'b0}}, sign_corr};

    // =========================================================================
    // Dadda Tree Reduction: 14 rows x 52 bits -> 2 rows (Sum + Carry)
    // =========================================================================
    wire [2*TREE_W-1:0] dadda_rows_out;

    dadda_reduce #(
        .N (NUM_ROWS),
        .W (TREE_W)
    ) u_dadda (
        .rows_in  (dadda_rows_in ),
        .rows_out (dadda_rows_out)
    );

    wire [TREE_W-1:0] dadda_sum   = dadda_rows_out[  TREE_W-1 :       0];
    wire [TREE_W-1:0] dadda_carry = dadda_rows_out[2*TREE_W-1 : TREE_W ];

    // =========================================================================
    // Final Carry-Propagate Adder  [52-bit]
    // =========================================================================
    wire [TREE_W-1:0] cpa_sum;
    wire              cpa_cout;

    ripple_carry_adder_n #(
        .WIDTH (TREE_W)
    ) u_cpa (
        .a    (dadda_sum  ),
        .b    (dadda_carry),
        .cin  (1'b0       ),
        .sum  (cpa_sum    ),
        .cout (cpa_cout   )
    );

    // =========================================================================
    // Output: lower 48 bits = correct unsigned 24x24 product
    // =========================================================================
    assign P = cpa_sum[47:0];

endmodule
