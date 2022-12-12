`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/09/2022 12:35:14 PM
// Design Name: 
// Module Name: system
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
module system(output wire RsTx, input wire RsRx,input clk, input btnC);
 
    //////////////////////////////////
    // uart
    wire                baud;           // baudrate
    baudrate_gen baudrate(clk, baud);
    
    wire    [7:0]       data_out;       // 1 char from receive
    wire                received;       // = received 8 bits successfully
    reg                 last_rec;       // = check if received is new
    wire                new_input;
    assign new_input = ~last_rec & received;
    uart_rx receiver(baud, RsRx, received, data_out);
    
    reg     [7:0]       data_in;        // 1 char to transmit
    wire                sent;           // = sent 8 bits successfully
    reg                 wr_en;          // = enable transmitter
    uart_tx transmitter(baud, data_in, wr_en, sent, RsTx);
    
    //////////////////////////////////
    // push button
    wire                reset;
    singlePulser resetButton(reset, btnC, baud);
    
    //////////////////////////////////
    // r/w buffer
    reg     [111:0]     writebuffer;    // 14 chars
    reg     [31:0]      readbuffer;  // 4 chars
    
    //////////////////////////////////
    // cast input from uart to int
    reg     [31:0]      inputbuffer;
    wire    [31:0]      inputval;
    strToInt inputCast(inputbuffer, inputval);

    wire    [111:0]     outputbuffer;
    wire    [31:0]      outputval;
    wire                validOutput;    // 1 if output is valid
    wire    [7:0]       signbuffer;
    wire    [31:0]      outputValBuffer;
    assign outputbuffer = {16'h0D0A,signbuffer,16'h2820,outputValBuffer,40'h2029203A20};
  
    intToStr outputCast(outputval, signbuffer, outputValBuffer, validOutput);
    
    //////////////////////////////////
    // calculation
    reg     [2:0]       op;             // 0+ 1- 2* 3/ 4c
    reg                 enterkey;
    reg                 calculate;
    calculator cal(baud, reset, validOutput, inputval, op, calculate, outputval);

    //////////////////////////////////
    // state
    reg     [2:0]       state;
    parameter GET_OPERATOR        = 3'd0;
    parameter GET_OPERAND    	  = 3'd1;
    parameter SENDMORE    	      = 3'd2;
    parameter DELAY               = 3'd3;
    parameter RECIEVED_ENTERKEY   = 3'd4;
    parameter CALCULATE           = 3'd5;
    
    reg     [7:0]       sendlen;        // length of sending sting
    reg     [7:0]       counter;        // for delay state
    
    reg operand;                  
    reg operator;                       // 1 = need new operator , 0 = no more operator needs
    
    initial begin
        sendlen = 14; counter = 0; enterkey = 1; op = 5; operand = 1; operator = 1;
        readbuffer   = 32'h30303030;
        writebuffer     = {40'h0D0A2B2820,readbuffer,40'h2029203A20};
        state = RECIEVED_ENTERKEY;
    end

    always @(posedge baud) begin
        if(wr_en) wr_en=0;
        if(reset) begin
            sendlen = 0; counter = 0; enterkey = 1; op = 4; operand = 1; operator = 1;
            readbuffer   = 32'h30303030;
            writebuffer     = {40'h0D0A2B2820,readbuffer,40'h2029203A20};
            state = RECIEVED_ENTERKEY;
        end
        case(state)
            GET_OPERATOR:
                if(new_input) begin
                    case(data_out)
                        8'h2F: op = 3; // /
                        8'h2A: op = 2; // *
                        8'h2D: op = 1; // -
                        default: op = 0; //+
                    endcase
                    //13 == Carriage Return
                    if(data_out == 13) begin enterkey = 1; inputbuffer = {readbuffer}; end
                    //08 == backspace
                    else if(data_out == 8'h08) ;
                    else begin
                        if(data_out >= 8'h30 && data_out <=8'h39) begin
                            readbuffer[31:8] = readbuffer[23:0];
                            readbuffer[7:0] = data_out;
                        end

                        sendlen = 1;
                        writebuffer[111:104] = data_out;
                    end
                    operator = 0;
                    state = RECIEVED_ENTERKEY;
                end
            GET_OPERAND:
                if(new_input) begin
                    case(data_out)
                        13: begin enterkey = 1; inputbuffer = {readbuffer}; end
                        default: 
                            if(data_out >= 8'h30 && data_out <=8'h39) begin // 0-9
                                readbuffer[31:8] = readbuffer[23:0];
                                readbuffer[7:0]  = data_out;
                                writebuffer[111:104]= data_out;
                                sendlen             = 1;
                            end
                    endcase
                    state = RECIEVED_ENTERKEY;
                end
            RECIEVED_ENTERKEY: begin
                if(enterkey) begin
                    readbuffer   = 32'h30303030;
                    enterkey        = 0;
                    calculate       = 1;
                    state = CALCULATE;
                end
                else state = SENDMORE;
            end
            CALCULATE: begin
                calculate = 0;
                if(counter < 32) counter = counter+1;
                else begin 
                    if(validOutput) writebuffer = outputbuffer;
                    else writebuffer = 112'h0D0A4E2F4E_20202020_20203A20;
                    sendlen = 14;
                    operand = 1; operator = 1;
                    state = SENDMORE;
                    counter = 0;
                end
            end
            SENDMORE: begin
                if(sent & sendlen != 0) begin
                    wr_en       = 1;
                    data_in     = writebuffer[111:104];
                    writebuffer = writebuffer << 8;
                    sendlen     = sendlen - 1;
                    state       = DELAY;
                end
                else if(sendlen == 0) begin
                    if(operator)            state = GET_OPERATOR;
                    else if(operand)    state = GET_OPERAND;
                end
            end
            DELAY: begin
                if(counter < 20) counter = counter+1;
                else begin state = SENDMORE; counter = 0; end
            end
        endcase
        last_rec = received;
    end
endmodule
