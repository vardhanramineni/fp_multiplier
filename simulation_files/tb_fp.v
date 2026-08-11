`timescale 1ns/1ps
module tb_fp;
    reg [31:0] a,b;
    wire [31:0] p;
    fp_multiplier_32bit uut(.a(a),.b(b),.p(p));

    initial begin
        // 2.0 * 3.0 = 6.0
        a = 32'h40000000; // 2.0
        b = 32'h40400000; // 3.0
        #1; $display("2.0*3.0 = %h (expect 40C00000)", p);

        // 1.5 * 1.5 = 2.25
        a = 32'h3FC00000; // 1.5
        b = 32'h3FC00000; // 1.5
        #1; $display("1.5*1.5 = %h (expect 40100000)", p);

        // 1.0 * 1.0 = 1.0
        a = 32'h3F800000;
        b = 32'h3F800000;
        #1; $display("1.0*1.0 = %h (expect 3F800000)", p);

        // -2.0 * 3.0 = -6.0  (sign bit handling, not part of dadda change but check still works)
        a = 32'hC0000000;
        b = 32'h40400000;
        #1; $display("-2.0*3.0 = %h (expect C0C00000)", p);
        
        a= 32'h40840000;
        b=32'h406D3F7D;
        #10;
        
        $finish;
    end
endmodule
