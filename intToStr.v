`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/09/2022 12:33:42 PM
// Design Name: 
// Module Name: intToStr
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

module intToStr(
    input signed [31:0]  float,
    output       [7:0]   signbuffer,
    output       [31:0]  outputValBuffer,
    output reg           validout
    );
    
    reg signed  [31:0]  f;
    reg signed  [7:0]   a1,a2;
    wire        [15:0]  o1,o2;
    wire                negative;
    
    assign negative         = float[31];
    assign signbuffer       = (negative)? 8'h2D: 8'h2B;
    assign outputValBuffer  = {o1,o2};

    intToChar2 i2c1(a1, o1);
    intToChar2 i2c2(a2, o2);
    
    always @(float) begin
        f = float;
        if(negative) f = -float;
        
        a1 = f/100; f = f-a1*100;
        a2 = f;
        if(float>=10000 || float<=-10000) validout = 0;
        else validout = 1;
    end
endmodule

module intToChar2(input [7:0] i, output [15:0] c);
    reg [7:0] a;
    reg [3:0] i1,i2;
    
    intToChar i2c1(i1, c[15:8]);
    intToChar i2c2(i2, c[7:0]);
    
    always @(i) begin
        a = i;
        i1 = a/10;
        i2 = a-i1*10;
    end
endmodule

module intToChar(input [3:0] f, output reg [7:0] c);
    always @(f)
        case(f)
            0: c = 8'h30;
            1: c = 8'h31;
            2: c = 8'h32;
            3: c = 8'h33;
            4: c = 8'h34;
            5: c = 8'h35;
            6: c = 8'h36;
            7: c = 8'h37;
            8: c = 8'h38;
            9: c = 8'h39;
        endcase
endmodule