`timescale 1ns/1ps
// =============================================================================
// Module      : booth_encoder
// Description : Radix-4 Modified Booth Encoder (Figure 10.6)
//               Synthesizes as a COMBINATIONAL ENCODER (not ROM).
//
//   Outputs: neg, two, non0   (3 signals -- 'one'/'zero' removed)
//   The 'two' (x2) shift is applied AFTER pp_generator in mantissa_multiplier.
//
//   b_tri = { b[i+1], b[i], b[i-1] } = { x2, x1, x0 }
//
//   Decode table:
//     x2 x1 x0 | neg  two  non0 | Operation
//      0  0  0 |  0    0    0   |  0
//      0  0  1 |  0    0    1   | +A
//      0  1  0 |  0    0    1   | +A
//      0  1  1 |  0    1    1   | +2A
//      1  0  0 |  1    1    1   | -2A
//      1  0  1 |  1    0    1   | -A
//      1  1  0 |  1    0    1   | -A
//      1  1  1 |  0    0    0   |  0
//
// -----------------------------------------------------------------------
// WHY THIS SYNTHESIZES AS LOGIC (NOT ROM):
//   Using a 'case' statement causes Vivado to infer a lookup ROM because
//   it sees a table mapping -> it maps to LUT-as-ROM primitives.
//
//   Using explicit Boolean equations forces Vivado to build individual
//   logic gates (AND/OR/XOR/NOT) -> LUT-as-logic primitives (encoder).
//
// -----------------------------------------------------------------------
// Boolean equation derivation (Karnaugh map / minterm grouping):
//
//   non0: low only for 000 and 111 (all-same inputs)
//         non0 = (x2 ^ x1) | (x1 ^ x0)
//
//   neg:  high for 100, 101, 110 (x2=1, NOT both x1 and x0 high)
//         neg  = x2 & ~(x1 & x0)
//
//   two:  high for 011 and 100 only
//         two  = (x2 ^ x1) & (x2 ^ x0)
//
// Verified against all 8 input combinations (see table above).
// =============================================================================

module booth_encoder (
    input  wire [2:0] b_tri,  // 3-bit Booth group: {b[i+1], b[i], b[i-1]}
    output wire       neg,    // negate: PP is bitwise-inverted (-A or -2A)
    output wire       two,    // select 2*A (shift applied AFTER pp_generator)
    output wire       non0    // PP is non-zero (replaces 'one' and 'zero')
);

    // Rename for readability
    wire x2 = b_tri[2];  // b[i+1]
    wire x1 = b_tri[1];  // b[i]
    wire x0 = b_tri[0];  // b[i-1]

    // -------------------------------------------------------------------------
    // non0: zero only when all inputs are identical (000 or 111)
    //       = detects any difference between adjacent bits
    // -------------------------------------------------------------------------
    assign non0 = (x2 ^ x1) | (x1 ^ x0);

    // -------------------------------------------------------------------------
    // neg: high when x2=1 AND it is NOT the all-ones case
    //      = x2 AND NAND(x1, x0)
    // -------------------------------------------------------------------------
    assign neg = x2 & ~(x1 & x0);

    // -------------------------------------------------------------------------
    // two: high only for +2A (011) and -2A (100)
    //      = both adjacent-bit XORs are simultaneously 1
    // -------------------------------------------------------------------------
    assign two = (x2 ^ x1) & (x2 ^ x0);

endmodule
