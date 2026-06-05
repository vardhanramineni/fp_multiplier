`timescale 1ns/1ps
// 24x24 Mantissa Multiplier
// Simple array multiplier (shift-and-add) approach
// Multiplies two 24-bit unsigned mantissa values (with implicit leading 1)
// Produces a 48-bit product
// No Wallace/Dadda/CLA - uses basic partial product accumulation
module mantissa_multiplier (
    input  [23:0] ma,   // 24-bit mantissa of operand A (with implicit leading 1)
    input  [23:0] mb,   // 24-bit mantissa of operand B (with implicit leading 1)
    output [47:0] mp    // 48-bit product
);
    // Partial products: pp[i] = ma shifted left by i if mb[i] == 1, else 0
    wire [47:0] pp [0:23];

    // Generate partial products using AND (logical AND of each bit of mb with full ma)
    genvar i;
    generate
        for (i = 0; i < 24; i = i + 1) begin : gen_pp
            assign pp[i] = {{24{1'b0}}, (mb[i] ? ma : 24'b0)} << i;
        end
    endgenerate

    // Accumulate all partial products using a sequential add tree
    // Stage 1: pairs
    wire [47:0] s1  [0:11];
    generate
        for (i = 0; i < 12; i = i + 1) begin : stage1
            assign s1[i] = pp[2*i] + pp[2*i+1];
        end
    endgenerate

    // Stage 2: reduce 12 -> 6
    wire [47:0] s2 [0:5];
    generate
        for (i = 0; i < 6; i = i + 1) begin : stage2
            assign s2[i] = s1[2*i] + s1[2*i+1];
        end
    endgenerate

    // Stage 3: reduce 6 -> 3
    wire [47:0] s3 [0:2];
    assign s3[0] = s2[0] + s2[1];
    assign s3[1] = s2[2] + s2[3];
    assign s3[2] = s2[4] + s2[5];

    // Stage 4: reduce 3 -> 2
    wire [47:0] s4 [0:1];
    assign s4[0] = s3[0] + s3[1];
    assign s4[1] = s3[2];

    // Stage 5: final sum
    assign mp = s4[0] + s4[1];

endmodule
