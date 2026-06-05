// Special Case Handler
// Detects IEEE 754 special cases: zero, infinity, NaN
// These must be checked before performing multiplication
module special_case_handler (
    input  [31:0] a,
    input  [31:0] b,
    output        is_zero,
    output        is_inf,
    output        is_nan,
    output        special_detected,
    output [31:0] special_result
);
    wire [7:0]  ea = a[30:23];
    wire [7:0]  eb = b[30:23];
    wire [22:0] ma = a[22:0];
    wire [22:0] mb = b[22:0];
    wire        sa = a[31];
    wire        sb = b[31];

    wire a_zero = (ea == 8'h00) && (ma == 23'h0);
    wire b_zero = (eb == 8'h00) && (mb == 23'h0);
    wire a_inf  = (ea == 8'hFF) && (ma == 23'h0);
    wire b_inf  = (eb == 8'hFF) && (mb == 23'h0);
    wire a_nan  = (ea == 8'hFF) && (ma != 23'h0);
    wire b_nan  = (eb == 8'hFF) && (mb != 23'h0);

    assign is_zero = a_zero | b_zero;
    assign is_inf  = a_inf  | b_inf;
    assign is_nan  = a_nan  | b_nan;

    assign special_detected = is_zero | is_inf | is_nan;

    // Result selection for special cases
    // NaN: return canonical quiet NaN
    // Inf * Zero = NaN
    // Inf * nonzero = Inf (with correct sign)
    // Zero * anything = Zero (with correct sign)
    wire result_sign = sa ^ sb;

    assign special_result =
        (a_nan | b_nan)          ? 32'h7FC00000 :        // Quiet NaN
        (a_inf & b_zero) ||
        (b_inf & a_zero)         ? 32'h7FC00000 :        // Inf * 0 = NaN
        (a_inf | b_inf)          ? {result_sign, 8'hFF, 23'h0} : // Infinity
        /* zero */                 {result_sign, 31'h0};          // Zero

endmodule
