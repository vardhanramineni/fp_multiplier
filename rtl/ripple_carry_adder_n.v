`timescale 1ns/1ps
// =============================================================================
// Module      : ripple_carry_adder_n
// Description : Parameterized N-bit ripple carry adder, built from the
//                existing full_adder primitive. Used as the final
//                Carry-Propagate Adder (CPA) stage after the Dadda
//                reduction tree produces the final Sum and Carry rows.
// =============================================================================
module ripple_carry_adder_n #(
    parameter WIDTH = 88
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);

    wire [WIDTH:0] c;
    assign c[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_fa
            full_adder fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (c[i]),
                .sum  (sum[i]),
                .carry(c[i+1])
            );
        end
    endgenerate

    assign cout = c[WIDTH];

endmodule
