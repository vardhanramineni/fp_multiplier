`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.05.2026 18:05:34
// Design Name: 
// Module Name: fp_rounding
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fp_rounding (
    input  [47:0] mantissa_in,
    output [23:0] mantissa_out
);

    // Keep bits
    wire [23:0] keep;
    wire        carry_out;

    // Guard, Round, Sticky bits
    wire guard_bit;
    wire round_bit;
    wire sticky_bit;

    // Rounded mantissa
    wire [24:0] rounded;

    assign keep       = mantissa_in[47:24];

    assign guard_bit  = mantissa_in[23];
    assign round_bit  = mantissa_in[22];

    // Sticky bit = OR of all lower discarded bits
    assign sticky_bit = |mantissa_in[21:0];


    wire round_up;

    assign round_up =
            guard_bit &
            (round_bit | sticky_bit | keep[0]);

    // Add rounding increment
    assign rounded = {1'b0, keep} + round_up;

    // Carry generation after rounding
    assign carry_out   = rounded[24];

    assign mantissa_out =
            carry_out ? rounded[24:1] : rounded[23:0];

endmodule