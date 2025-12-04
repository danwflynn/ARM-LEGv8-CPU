`timescale 1ns/10ps

// Daniel Flynn, Defne Ulusoy

module cpu5armtb();

parameter num = 77;
reg  [31:0] instrbus;
reg  [31:0] instrbusin[0:num];
wire [63:0] iaddrbus, daddrbus;
reg  [63:0] iaddrbusout[0:num], daddrbusout[0:num];
wire [63:0] databus;
reg  [63:0] databusk, databusin[0:num], databusout[0:num];
reg         clk, reset;
reg         clkd;

reg [63:0] dontcare;
reg [24*8:1] iname[0:num];
integer error, k, ntests;

parameter BRANCH	= 6'b000011;
parameter BEQ		= 8'b01110100;
parameter BNE		= 8'b01110101;
parameter BLT		= 8'b01110110;
parameter BGE		= 8'b01110111;
parameter CBZ		= 8'b11110100;
parameter CBNZ		= 8'b11110101;
parameter ADD		= 11'b00101000000;
parameter ADDS		= 11'b00101000001;
parameter SUB		= 11'b00101001001;
parameter SUBS		= 11'b00101001010;
parameter AND		= 11'b00101000010;
parameter ANDS		= 11'b00101000011;
parameter EOR		= 11'b00101000100;
parameter ENOR      = 11'b00101000101;
parameter ORR		= 11'b00101001000;
parameter LSL		= 11'b00101000110;
parameter LSR		= 11'b00101000111;
parameter ADDI  	= 10'b1000100000;
parameter ADDIS		= 10'b1000100001;
parameter SUBI		= 10'b1000100111;
parameter SUBIS		= 10'b1000101000;
parameter ANDI		= 10'b1000100010;
parameter ANDIS		= 10'b1000100011;
parameter EORI		= 10'b1000100100;
parameter ENORI     = 10'b1000100101;
parameter ORRI		= 10'b1000100110;
parameter MOVZ		= 9'b110010101;
parameter STUR		= 11'b11010000001;
parameter LDUR		= 11'b11010000000;
	
	
cpu5arm dut(.reset(reset),.clk(clk),.iaddrbus(iaddrbus),.ibus(instrbus),.daddrbus(daddrbus),.databus(databus));

initial begin
// This test file runs the following program.

iname[0]  = "ADDI R14, R31, #2";
iname[1]  = "ANDI R15, R31, #4095";
iname[2]  = "ORRI R16, R31, #1000";
iname[3]  = "SUBI R17, R31, #1445";
iname[4]  = "LDUR R18, [R14, 0]";
iname[5]  = "LDUR R19, [R15, 1]";
iname[6]  = "LDUR R20, [R16, 0]";
iname[7]  = "STUR R14, [R16, 100]";
iname[8]  = "ENOR R21, R18, R19";
iname[9]  = "ORR R22, R20, R31";
iname[10] = "ANDS R23, R14, R17";
iname[11] = "ADDS R24, R14, R16";
iname[12] = "EORI R25, R31, #2730";
iname[13] = "ADDIS R26, R16, #2000";
iname[14] = "EOR R27, R20, R21";
iname[15] = "STUR R21, [R21, 0]";
iname[16] = "STUR R21, [R20, 0]";
iname[17] = "STUR R26, [R22, 0]";
iname[18] = "STUR R25, [R23, 0]";
iname[19] = "LSL R13, R16, #1";
iname[20] = "ADD R12, R16, R17"; // Adding a positive to a negative
iname[21] = "SUB R11, R17, R14"; // Subtracting a negative from a positive
iname[22] = "LSR R10, R13 #2";
iname[23] = "SUBS R31, R14, R31";
iname[24] = "BLT #16";
iname[25] = "MOVZ R31, (<< 1*16), #hABCD";
iname[26] = "MOVZ R31, (<< 3*16), #hABCD";
iname[27] = "MOVZ R1, (<< 0*16), #hDCBA";
iname[28] = "CBZ R14 #d32";
iname[29] = "ANDIS R2, R1, #0";
iname[30] = "CBNZ R14 #d32";
iname[31] = "ADDI R31, R31, #0";
iname[32] = "ADDI R31, R31, #0";
iname[33] = "SUBIS R31, R31, #0";
iname[34] = "BEQ #16";
iname[35] = "ENORI R31, R31, #0";
iname[36] = "AND R31, R31, R31";
iname[37] = "SUBIS R31, R2, #1";
iname[38] = "BGE #16";
iname[39] = "ADDI R3, R31, #17";
iname[40] = "ADDI R4, R31, #1";
iname[41] = "ADDI R5, R31, #1";
iname[42] = "ADDI R6, R31, #1";
iname[43] = "SUBS R31, R1, R2";
iname[44] = "BNE #16";
iname[45] = "ORRI R31, R31, #0";
iname[46] = "ORRI R31, R31, #0";
iname[47] = "B #d32";
iname[48] = "NOP  ADDI  R31,  R31, #0";
iname[49] = "NOP  ADDI  R31,  R31, #0";
iname[50] = "NOP  ADDI  R31,  R31, #0";
iname[51] = "NOP  ADDI  R31,  R31, #0";
iname[52] = "NOP  ADDI  R31,  R31, #0";

iname[53] = "MOVZ R7, (<< 0*16), #h00FF";
iname[54] = "ENORI R8, R6, #0x0F0F";
iname[55] = "ADDI R9, R4, #1";
iname[56] = "LSL R10, R5, #2";
iname[57] = "STUR 11, [R3, 0]";
iname[58] = "ADD R12, R6, R4";
iname[59] = "ORR R13, R7, R5";
iname[60] = "ADDI R14, R7, #1";
iname[61] = "LSL R15, R8, #3";
iname[62] = "SUBI R16, R6, #1";
iname[63] = "ORR R17, R8, R7";
iname[64] = "LDUR R18, [R9, 0]";
iname[65] = "ENORI R19, R10, #0";
iname[66] = "ADDI R20, R11, #5";
iname[67] = "LSL R21, R11, #1";
iname[68] = "ADD R22, R12, R10";
iname[69] = "STUR R23, [R10, 100]";
iname[70] = "ADDI R24, R12, #45";
iname[71] = "LDUR R25, [R12, 0]";
iname[72] = "LSL R26, R14, #4";




dontcare = 64'hx;

//* ADDI  R14, R31, #2
// Makes value at R14 = 2
iaddrbusout[0] = 64'h0000000000000000;
//            opcode 
instrbusin[0]={ADDI, 12'b000000000010, 5'b11111, 5'd14};
daddrbusout[0] = 64'b0000000000000000000000000000000000000000000000000000000000000010;
databusin[0] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[0] = dontcare;

//* ANDI  R15, R31, #4095
// Makes value at R15 = 0
iaddrbusout[1] = 64'h0000000000000004;
//            opcode
instrbusin[1]={ANDI, 12'b111111111111, 5'b11111, 5'd15};
daddrbusout[1] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[1]   = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[1]  = dontcare;

//* ORRI  R16, R31, #1000
// Makes value at R16 = 1000
iaddrbusout[2] = 64'h0000000000000008;
//            opcode
instrbusin[2]={ORRI, 12'd1000, 5'b11111, 5'd16};
daddrbusout[2] = 64'b0000000000000000000000000000000000000000000000000000001111101000;
databusin[2]   = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[2]  = dontcare;

//* SUBI R17, R31, #1445
// Makes value at R17 = -1445
iaddrbusout[3] = 64'h000000000000000C;
// opcode
instrbusin[3]={SUBI, 12'd1445, 5'b11111, 5'd17};
daddrbusout[3] = 64'b1111111111111111111111111111111111111111111111111111101001011011;
databusin[3] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[3] = dontcare;

//* LDUR R18, [R14, 0]
// Loads value at data memory address 2 (made it AAAAAAAAAAAAAAAA) into R18
iaddrbusout[4] = 64'h0000000000000010;
// opcode
instrbusin[4]={LDUR, 9'b000000000, 2'b00, 5'b01110, 5'b10010};
daddrbusout[4] = 64'b0000000000000000000000000000000000000000000000000000000000000010;
databusin[4] = 64'hAAAAAAAAAAAAAAAA;
databusout[4] = dontcare;

//* LDUR R19, [R15, 1]
// Loads value at data memory address 1 (Made it BBBBBBBBBBBBBBBB) into R19
iaddrbusout[5] = 64'h0000000000000014;
// opcode
instrbusin[5]={LDUR, 9'b000000001, 2'b00, 5'b01111, 5'b10011};
daddrbusout[5] = 64'b0000000000000000000000000000000000000000000000000000000000000001;
databusin[5] = 64'hBBBBBBBBBBBBBBBB;
databusout[5] = dontcare;

//* LDUR R20, [R16, 0]
// Loads value at data memory address 1000 (made it CCCCCCCCCCCCCCCC) into R20
iaddrbusout[6] = 64'h0000000000000018;
// opcode
instrbusin[6]={LDUR, 9'b000000000, 2'b00, 5'b10000, 5'b10100};
daddrbusout[6] = 64'b0000000000000000000000000000000000000000000000000000001111101000;
databusin[6] = 64'hCCCCCCCCCCCCCCCC;
databusout[6] = dontcare;

//* STUR   R14, [R16, 100]
// Stores value at R14 (2) into data memory address 1100
iaddrbusout[7] = 64'h000000000000001C;
//            opcode 
instrbusin[7]={STUR, 9'b001100100, 2'b01, 5'b10000, 5'b01110};
daddrbusout[7] = 64'h000000000000044C;
databusin[7] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[7] = 64'b0000000000000000000000000000000000000000000000000000000000000010;

//* ENOR R21, R18, R19
// AAAAAAAAAAAAAAAA ENOR BBBBBBBBBBBBBBBB into R21
iaddrbusout[8] = 64'h0000000000000020;
//            opcode 
instrbusin[8]={ENOR, 5'd18, 6'b000000, 5'd19, 5'd21};
daddrbusout[8] = 64'hEEEEEEEEEEEEEEEE;
databusin[8] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[8] = dontcare;

//* ORR R22, R20, R31
// R22 becomes CCCCCCCCCCCCCCCC
iaddrbusout[9] = 64'h0000000000000024;
//            opcode 
instrbusin[9]={ORR, 5'd20, 6'b000000, 5'd31, 5'd22};
daddrbusout[9] = 64'hCCCCCCCCCCCCCCCC;
databusin[9] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[9] = dontcare;

//* ANDS R23, R14, R17
// R23 becomes 2
iaddrbusout[10] = 64'h0000000000000028;
//            opcode 
instrbusin[10]={ANDS, 5'd14, 6'b000000, 5'd17, 5'd23};
daddrbusout[10] = 64'h0000000000000002;
databusin[10] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[10] = dontcare;

//* ADDS R24, R14, R16
// R24 becomes 1002
iaddrbusout[11] = 64'h000000000000002C;
//            opcode 
instrbusin[11]={ADDS, 5'd14, 6'b000000, 5'd16, 5'd24};
daddrbusout[11] = 64'd1002;
databusin[11] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[11] = dontcare;

//* EORI R25, R31, #2730
// R25 becomes 2730
iaddrbusout[12] = 64'h0000000000000030;
//            opcode 
instrbusin[12]={EORI, 12'd2730, 5'b11111, 5'd25};
daddrbusout[12] = 64'd2730;
databusin[12] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[12] = dontcare;

//* ADDIS R26, R16, #2000
// Makes value at R26 = 3000
iaddrbusout[13] = 64'h0000000000000034;
//            opcode 
instrbusin[13]={ADDIS, 12'd2000, 5'd16, 5'd26};
daddrbusout[13] = 64'd3000;
databusin[13] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[13] = dontcare;

//* EOR R27, R20, R21
// Makes R27 = 64'h2222222222222222 which is Cs xor Es
iaddrbusout[14] = 64'h0000000000000038;
//            opcode 
instrbusin[14]={EOR, 5'd20, 6'b000000, 5'd21, 5'd27};
daddrbusout[14] = 64'h2222222222222222;
databusin[14] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[14] = dontcare;

//* STUR R21, [R21, 0]
// Stores 64'hEEEEEEEEEEEEEEEE in address 64'hEEEEEEEEEEEEEEEE
iaddrbusout[15] = 64'h000000000000003C;
//            opcode
instrbusin[15]={STUR, 9'b000000000, 2'b01, 5'd21, 5'd21};
daddrbusout[15] = 64'hEEEEEEEEEEEEEEEE;
databusin[15] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[15] = 64'hEEEEEEEEEEEEEEEE;

//* STUR R21, [R20, 0]
// Stores 64'hEEEEEEEEEEEEEEEE in address 64'hCCCCCCCCCCCCCCCC
iaddrbusout[16] = 64'h0000000000000040;
//            opcode
instrbusin[16]={STUR, 9'b000000000, 2'b01, 5'd20, 5'd21};
daddrbusout[16] = 64'hCCCCCCCCCCCCCCCC;
databusin[16] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[16] = 64'hEEEEEEEEEEEEEEEE;

//* STUR R26, [R22, 0]
// Stores 3000 in address 64'hCCCCCCCCCCCCCCCC
iaddrbusout[17] = 64'h0000000000000044;
//            opcode
instrbusin[17]={STUR, 9'b000000000, 2'b01, 5'd22, 5'd26};
daddrbusout[17] = 64'hCCCCCCCCCCCCCCCC;
databusin[17] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[17] = 64'd3000;

//* STUR R25, [R23, 0]
// Stores 2730 in address 2
iaddrbusout[18] = 64'h0000000000000048;
//            opcode
instrbusin[18]={STUR, 9'b000000000, 2'b01, 5'd23, 5'd25};
daddrbusout[18] = 64'd2;
databusin[18] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[18] = 64'd2730;

//* LSL R13, R16, #1
// Shifts value in R16 to the left once and puts result in R13
iaddrbusout[19] = 64'h000000000000004C;
//            opcode
instrbusin[19]={LSL, 5'd0, 6'b000001, 5'd16, 5'd13};
daddrbusout[19] = 64'b0000000000000000000000000000000000000000000000000000011111010000;
databusin[19] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[19] = dontcare;

//* ADD R12, R16, R17
// Puts -445 in R12
iaddrbusout[20] = 64'h0000000000000050;
//            opcode
instrbusin[20]={ADD, 5'd16, 6'b000000, 5'd17, 5'd12};
daddrbusout[20] = 64'b1111111111111111111111111111111111111111111111111111111001000011;
databusin[20] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[20] = dontcare;

//* SUB R11, R17, R14
// Puts 1447 in R11
iaddrbusout[21] = 64'h0000000000000054;
//            opcode
instrbusin[21]={SUB, 5'd17, 6'b000000, 5'd14, 5'd11};
daddrbusout[21] = 64'd1447;
databusin[21] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[21] = dontcare;

//* LSR R10, R13 #2
// Shifts value in R13 to the right by 2 and puts it in R10
iaddrbusout[22] = 64'h0000000000000058;
//            opcode
instrbusin[22]={LSR, 5'd0, 6'b000010, 5'd13, 5'd10};
daddrbusout[22] = 64'b0000000000000000000000000000000000000000000000000000000111110100;
databusin[22] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[22] = dontcare;

//* SUBS R31, R14, R31
// Result is -2
iaddrbusout[23] = 64'h000000000000005C;
//            opcode
instrbusin[23]={SUBS, 5'd14, 6'b000000, 5'd31, 5'd31};
daddrbusout[23] = 64'b1111111111111111111111111111111111111111111111111111111111111110;
databusin[23] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[23] = dontcare;

//* BLT #16
// Branch here
iaddrbusout[24] = 64'h0000000000000060;
//            opcode
instrbusin[24]={BLT, 19'd16, 5'd0};
daddrbusout[24] = dontcare;
databusin[24] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[24] = dontcare;

//* MOVZ  R31, (<< 1*16), #hABCD 
// Waiting for the PC to branch
iaddrbusout[25] = 64'h0000000000000064;
//            opcode
instrbusin[25]={MOVZ, 2'b01, 16'hABCD, 5'd31};
daddrbusout[25] = 64'b0000000000000000000000000000000010101011110011010000000000000000;
databusin[25] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[25] = dontcare;

//* MOVZ  R31, (<< 3*16), #hABCD 
// PC branches
iaddrbusout[26] = 64'h00000000000000A0;
//            opcode
instrbusin[26]={MOVZ, 2'b11, 16'hABCD, 5'd31};
daddrbusout[26] = 64'b1010101111001101000000000000000000000000000000000000000000000000;
databusin[26] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[26] = dontcare;

//* MOVZ R1, (<< 0*16), #hDCBA
// Moves DCBA into R1
iaddrbusout[27] = 64'h00000000000000A4;
//            opcode
instrbusin[27]={MOVZ, 2'b00, 16'hDCBA, 5'd1};
daddrbusout[27] = 64'hDCBA;
databusin[27] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[27] = dontcare;

//* CBZ R14 #d32
// Will not branch because R14 is not zero
iaddrbusout[28] = 64'h00000000000000A8;
//            opcode
instrbusin[28]={CBZ, 19'd32, 5'd14};
daddrbusout[28] = dontcare;
databusin[28] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[28] = dontcare;

//* ANDIS R2, R1, #0
// Makes value at R2 = 0
iaddrbusout[29] = 64'h00000000000000AC;
//            opcode
instrbusin[29]={ANDIS, 12'b000000000000, 5'd14, 5'd2};
daddrbusout[29] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[29]   = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[29]  = dontcare;

//* CBNZ R14 #d32
// This time we will actually branch
iaddrbusout[30] = 64'h00000000000000B0;
//            opcode
instrbusin[30]={CBNZ, 19'd32, 5'd14};
daddrbusout[30] = dontcare;
databusin[30] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[30] = dontcare;

//* ADDI R31, R31, #0
// Delay
iaddrbusout[31] = 64'h00000000000000B4;
//            opcode 
instrbusin[31]={ADDI, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[31] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[31] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[31] = dontcare;

//* ADDI R31, R31, #0
// Branch happens
iaddrbusout[32] = 64'h0000000000000130;
//            opcode 
instrbusin[32]={ADDI, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[32] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[32] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[32] = dontcare;

//* SUBIS R31, R31, #0
// Subtract 0 from 0
iaddrbusout[33] = 64'h0000000000000134;
//            opcode 
instrbusin[33]={SUBIS, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[33] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[33] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[33] = dontcare;

//* BEQ #16
// Branch here
iaddrbusout[34] = 64'h0000000000000138;
//            opcode
instrbusin[34]={BEQ, 19'd16, 5'd0};
daddrbusout[34] = dontcare;
databusin[34] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[34] = dontcare;

//* ENORI R31, R31, #0
// Delay
iaddrbusout[35] = 64'h000000000000013C;
//            opcode 
instrbusin[35]={ENORI, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[35] = 64'hFFFFFFFFFFFFFFFF;
databusin[35] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[35] = dontcare;

//* AND R31, R31, R31
// Branch happens
iaddrbusout[36] = 64'h0000000000000178;
//            opcode 
instrbusin[36]={AND, 5'd31, 6'b000000, 5'd31, 5'd31};
daddrbusout[36] = 64'h0000000000000000;
databusin[36] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;

//* SUBIS R31, R2, #1
// Subtract 1 from 0
iaddrbusout[37] = 64'h000000000000017C;
//            opcode 
instrbusin[37]={SUBIS, 12'b000000000001, 5'd2, 5'd31};
daddrbusout[37] = 64'b1111111111111111111111111111111111111111111111111111111111111111;
databusin[37] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[37] = dontcare;

//* BGE #16
// Don't branch here
iaddrbusout[38] = 64'h0000000000000180;
//            opcode
instrbusin[38]={BGE, 19'd16, 5'd0};
daddrbusout[38] = dontcare;
databusin[38] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[38] = dontcare;

//* ADDI  R3, R31, #17
// Makes value at R3 = 17
iaddrbusout[39] = 64'h0000000000000184;
//            opcode 
instrbusin[39]={ADDI, 12'd17, 5'b11111, 5'd3};
daddrbusout[39] = 64'd17;
databusin[39] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[39] = dontcare;

//* ADDI  R4, R31, #1
// Makes value at R4 = 1
iaddrbusout[40] = 64'h0000000000000188;
//            opcode 
instrbusin[40]={ADDI, 12'b000000000001, 5'd31, 5'd4};
daddrbusout[40] = 64'b0000000000000000000000000000000000000000000000000000000000000001;
databusin[40] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[40] = dontcare;

//* ADDI  R5, R31, #1
// Makes value at R5 = 1
iaddrbusout[41] = 64'h000000000000018C;
//            opcode 
instrbusin[41]={ADDI, 12'b000000000001, 5'd31, 5'd5};
daddrbusout[41] = 64'b0000000000000000000000000000000000000000000000000000000000000001;
databusin[41] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[41] = dontcare;

//* ADDI  R6, R31, #1
// Makes value at R6 = 1
iaddrbusout[42] = 64'h0000000000000190;
//            opcode 
instrbusin[42]={ADDI, 12'b000000000001, 5'd31, 5'd6};
daddrbusout[42] = 64'b0000000000000000000000000000000000000000000000000000000000000001;
databusin[42] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[42] = dontcare;

//* SUBS R31, R1, R2
// Comparing 2 unequal numbers
iaddrbusout[43] = 64'h0000000000000194;
//            opcode
instrbusin[43]={SUBS, 5'd1, 6'b000000, 5'd2, 5'd31};
daddrbusout[43] = 64'b1111111111111111111111111111111111111111111111110010001101000110;
databusin[43] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[43] = dontcare;

//* BNE #16
// Branch here
iaddrbusout[44] = 64'h0000000000000198;
//            opcode
instrbusin[44]={BNE, 19'd16, 5'd0};
daddrbusout[44] = dontcare;
databusin[44] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[44] = dontcare;

//* ORRI R31, R31, #0
// Delay
iaddrbusout[45] = 64'h000000000000019C;
//            opcode 
instrbusin[45]={ORRI, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[45] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[45] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[45] = dontcare;

//* ORRI R31, R31, #0
// Branch happens
iaddrbusout[46] = 64'h00000000000001D8;
//            opcode 
instrbusin[46]={ORRI, 12'b000000000000, 5'd31, 5'd31};
daddrbusout[46] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[46] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[46] = dontcare;

//* B #d32
// Branch here
iaddrbusout[47] = 64'h00000000000001DC;
//            opcode 
instrbusin[47]={BRANCH, 26'd32};
daddrbusout[47] = dontcare;
databusin[47] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[47] = dontcare;


//* NOP  ADDI  R31,  R31, #0
iaddrbusout[48] = 64'h00000000000001E0;
//            opcode 
instrbusin[48]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[48] = 64'd0;
databusin[48] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[48] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[49] = 64'h000000000000025C;
//            opcode 
instrbusin[49]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[49] = 64'd0;
databusin[49] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[49] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[50] = 64'h0000000000000260;
//            opcode 
instrbusin[50]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[50] = 64'd0;
databusin[50] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[50] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[51] = 64'h0000000000000264;
//            opcode 
instrbusin[51]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[51] = 64'd0;
databusin[51] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[51] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[52] = 64'h0000000000000268;
//            opcode 
instrbusin[52]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[52] = 64'd0;
databusin[52] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[52] = dontcare;
  
  
// MOVZ R7, (<< 0*16), #h00FF
iaddrbusout[53] = 64'h000000000000026C;
instrbusin[53]  = {MOVZ, 2'b00, 16'h00FF, 5'd7};
daddrbusout[53] = 64'b0000000000000000000000000000000000000000000000000000000011111111;
databusin[53]   = dontcare;
databusout[53]  = dontcare;


// ENORI R8, R6, #0x0F0F"
iaddrbusout[54] = 64'h0000000000000270;
instrbusin[54]  = {ENORI, 12'hF0F, 5'd6, 5'd8};
daddrbusout[54] = 64'b1111111111111111111111111111111111111111111111111111000011110001;
databusin[54]   = dontcare;
databusout[54]  = dontcare;


// ADDI R9, R4, #1
iaddrbusout[55] = 64'h0000000000000274;
instrbusin[55]  = {ADDI, 12'd1, 5'd4, 5'd9};
daddrbusout[55] = 64'b0000000000000000000000000000000000000000000000000000000000000010;
databusin[55]   = dontcare;
databusout[55]  = dontcare;

  
// LSL R10, R5, #2
iaddrbusout[56] = 64'h0000000000000278;
instrbusin[56]  = {LSL, 5'd0, 6'b000010, 5'd5, 5'd10};
daddrbusout[56] = 64'b0000000000000000000000000000000000000000000000000000000000000100;
databusin[56]   = dontcare;
databusout[56]  = dontcare;


// STUR 11, [R3, 0]
iaddrbusout[57] = 64'h000000000000027C;
instrbusin[57]  = {STUR, 9'b000000000, 2'b01, 5'd3, 5'd11};
daddrbusout[57] = 64'b0000000000000000000000000000000000000000000000000000000000010001;
databusin[57]   = dontcare;
databusout[57]  = 64'b0000000000000000000000000000000000000000000000000000010110100111;


// ADD R12, R6, R4
iaddrbusout[58] = 64'h0000000000000280;
instrbusin[58]  = {ADD, 5'd4, 6'b000000, 5'd4, 5'd12};
daddrbusout[58] = 64'b0000000000000000000000000000000000000000000000000000000000000010;
databusin[58]   = dontcare;
databusout[58]  = dontcare;


// ORR R13, R7, R5
iaddrbusout[59] = 64'h0000000000000284;
instrbusin[59]  = {ORR, 5'd7, 6'b000000, 5'd5, 5'd13};
daddrbusout[59] = 64'b0000000000000000000000000000000000000000000000000000000011111111;
databusin[59]   = dontcare;
databusout[59]  = dontcare;


// ADDI R14, R7, #1
iaddrbusout[60] = 64'h0000000000000288;
instrbusin[60]  = {ADDI, 12'd1, 5'd7, 5'd14};
daddrbusout[60] = 64'b0000000000000000000000000000000000000000000000000000000100000000;
databusin[60]   = dontcare;
databusout[60]  = dontcare;


// LSL R15, R8, #3
iaddrbusout[61] = 64'h000000000000028C;
instrbusin[61]  = {LSL, 5'd0, 6'b000011, 5'd8, 5'd15};
daddrbusout[61] = 64'b1111111111111111111111111111111111111111111111111000011110001000;
databusin[61]   = dontcare;
databusout[61]  = dontcare;


// SUBI R16, R6, #1
iaddrbusout[62] = 64'h0000000000000290;
instrbusin[62]  = {SUBI, 12'd1, 5'd6, 5'd16};
daddrbusout[62] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
databusin[62]   = dontcare;
databusout[62]  = dontcare;


// ORR R17, R8, R7
iaddrbusout[63] = 64'h0000000000000294;
instrbusin[63]  = {ORR, 5'd8, 6'b000000, 5'd7, 5'd17};
daddrbusout[63] = 64'b1111111111111111111111111111111111111111111111111111000011111111;
databusin[63]   = dontcare;
databusout[63]  = dontcare;


  
// LDUR R18, [R9, 0]
iaddrbusout[64] = 64'h0000000000000298;
instrbusin[64]  = {LDUR, 9'b000000000, 2'b00, 5'd9, 5'd18};
daddrbusout[64] = 64'b0000000000000000000000000000000000000000000000000000000000000010; 
databusin[64]   = 64'b0000000000000000000000000000000000000000000000000000010110100111;
databusout[64]  = dontcare;



// ENORI R19, R10, #0
iaddrbusout[65] = 64'h000000000000029C;
instrbusin[65]  = {ENORI, 12'd0, 5'd10, 5'd19};
daddrbusout[65] = 64'b 1111111111111111111111111111111111111111111111111111111111111011;
databusin[65]   = dontcare;
databusout[65]  = dontcare;


// ADDI R20, R11, #5
iaddrbusout[66] = 64'h00000000000002A0;
instrbusin[66]  = {ADDI, 12'd5, 5'd11, 5'd20};
daddrbusout[66] = 64'b0000000000000000000000000000000000000000000000000000010110101100;
databusin[66]   = dontcare;
databusout[66]  = dontcare;


// LSL R21, R11, #1
iaddrbusout[67] = 64'h00000000000002A4;
instrbusin[67]  = {LSL, 5'd0, 6'b000001, 5'd11, 5'd21};
daddrbusout[67] = 64'b0000000000000000000000000000000000000000000000000000101101001110;
databusin[67]   = dontcare;
databusout[67]  = dontcare;


// ADD R22, R12, R10
iaddrbusout[68] = 64'h00000000000002A8;
instrbusin[68]  = {ADD, 5'd12, 6'b000000, 5'd10, 5'd22};
daddrbusout[68] = 64'b0000000000000000000000000000000000000000000000000000000000000110;
databusin[68]   = dontcare;
databusout[68]  = dontcare;


// STUR R23, [R10, 100]
iaddrbusout[69] = 64'h00000000000002AC;
instrbusin[69]  = {STUR, 9'b001100100, 2'b01, 5'd10, 5'd23};
daddrbusout[69] = 64'b0000000000000000000000000000000000000000000000000000000001101000;
databusin[69]   = dontcare;
databusout[69]  = 64'b0000000000000000000000000000000000000000000000000000000000000010;

  

// ADDI R24, R12, #45
iaddrbusout[70] = 64'h00000000000002B0;
instrbusin[70]  = {ADDI, 12'd45, 5'd12, 5'd24};
daddrbusout[70] = 64'b0000000000000000000000000000000000000000000000000000000000101111;
databusin[70]   = dontcare;
databusout[70]  = dontcare;


// LDUR R25, [R12, 0]
iaddrbusout[71] = 64'h00000000000002B4;
instrbusin[71]  = {LDUR, 9'b000000000, 2'b00, 5'd12, 5'd25};
daddrbusout[71] = 64'b0000000000000000000000000000000000000000000000000000000000000010;
databusin[71]   = 64'hFFFFFFFFFFFFF801;
databusout[71]  = dontcare;

  
// LSL R26, R14, #4
iaddrbusout[72] = 64'h00000000000002B8;
instrbusin[72]  = {LSL, 5'd0, 6'b000100, 5'd14, 5'd26};
daddrbusout[72] = 64'b0000000000000000000000000000000000000000000000000001000000000000;
databusin[72]   = dontcare;
databusout[72]  = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[73] = 64'h00000000000002BC;
instrbusin[73]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[73] = 64'd0;
databusin[73] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[73] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[74] = 64'h00000000000002C0;
instrbusin[74]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[74] = 64'd0;
databusin[74] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[74] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[75] = 64'h00000000000002C4;
instrbusin[75]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[75] = 64'd0;
databusin[75] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[75] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[76] = 64'h00000000000002C8;
instrbusin[76]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[76] = 64'd0;
databusin[76] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[76] = dontcare;

//* NOP  ADDI  R31,  R31, #0
iaddrbusout[77] = 64'h00000000000002CC;
instrbusin[77]={ADDI, 12'd0, 5'd31, 5'd31};
daddrbusout[77] = 64'd0;
databusin[77] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
databusout[77] = dontcare;
  

// (no. instructions) + (no. loads) + 2*(no. stores) = 
  // 
ntests = 143;

$timeformat(-9,1,"ns",12);

end


//assumes positive edge FF.
//testbench reads databus when clk high, writes databus when clk low.
assign databus = clkd ? 64'bz : databusk;

//Change inputs in middle of period (falling edge).
initial begin
  error = 0;
  clkd =1;
  clk=1;
  $display ("Time=%t\n  clk=%b", $realtime, clk);
  databusk = 32'bz;

  //extended reset to set up PC MUX
  reset = 1;
  $display ("reset=%b", reset);
  #5
  clk=0;
  clkd=0;
  $display ("Time=%t\n  clk=%b", $realtime, clk);
  #5

  clk=1;
  clkd=1;
  $display ("Time=%t\n  clk=%b", $realtime, clk);
  #5
  clk=0;
  clkd=0;
  $display ("Time=%t\n  clk=%b", $realtime, clk);
  #5
  $display ("Time=%t\n  clk=%b", $realtime, clk);

for (k=0; k<= num; k=k+1) begin
    clk=1;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #2
    clkd=1;
    #3
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    reset = 0;
    $display ("reset=%b", reset);


    //set load data for 3rd previous instruction
    if (k >=3)
      databusk = databusin[k-3];

    //check PC for this instruction
    if (k >= 0) begin
      $display ("  Testing PC for instruction %d", k);
      $display ("    Your iaddrbus =    %b", iaddrbus);
      $display ("    Correct iaddrbus = %b", iaddrbusout[k]);
      if (iaddrbusout[k] !== iaddrbus) begin
        $display ("    -------------ERROR. A Mismatch Has Occured-----------");
        error = error + 1;
      end
    end

    //put next instruction on ibus
    instrbus=instrbusin[k];
    $display ("  instrbus=%b %b %b %b %b for instruction %d: %s", instrbus[31:26], instrbus[25:21], instrbus[20:16], instrbus[15:11], instrbus[10:0], k, iname[k]);

    //check data address from 3rd previous instruction
    if ( (k >= 3) && 
	     ((k-3) != 24)  && ((k-3) != 28) && ((k-3) != 30) && ((k-3) != 34) && 
	     ((k-3) != 38) && ((k-3) != 44) && ((k-3) != 47)                        ) begin
	
	//if ( (k >= 3) && (daddrbusout[k-3] !== dontcare) ) begin
      $display ("  Testing data address for instruction %d:", k-3);
      $display ("  %s", iname[k-3]);
      $display ("    Your daddrbus =    %b", daddrbus);
      $display ("    Correct daddrbus = %b", daddrbusout[k-3]);
      if (daddrbusout[k-3] !== daddrbus) begin
        $display ("    -------------ERROR. A Mismatch Has Occured-----------");
        error = error + 1;
      end
    end
    

    //check store data from 3rd previous instruction
    if ( (k >= 3) && (databusout[k-3] !== dontcare) && 
	     ((k-3) != 24) && ((k-3) != 28) && ((k-3) != 30) && ((k-3) != 34) && 
		 ((k-3) != 38) && ((k-3) != 44 ) && ((k-3) != 47)                      ) begin
      $display ("  Testing store data for instruction %d:", k-3);
      $display ("  %s", iname[k-3]);
      $display ("    Your databus =    %b", databus);
      $display ("    Correct databus = %b", databusout[k-3]);
      if (databusout[k-3] !== databus) begin
        $display ("    -------------ERROR. A Mismatch Has Occured-----------");
        error = error + 1;
      end
    end

    clk = 0;
    $display ("Time=%t\n  clk=%b", $realtime, clk);
    #2
    clkd = 0;
    #3
    $display ("Time=%t\n  clk=%b", $realtime, clk);
  end

  if ( error !== 0) begin
    $display("--------- SIMULATION UNSUCCESFUL - MISMATCHES HAVE OCCURED ----------");
  end

  if ( error == 0)
    $display("---------YOU DID IT!! SIMULATION SUCCESFULLY FINISHED----------");

   $display(" Number Of Errors = %d", error);
   $display(" Total Test numbers = %d", ntests);
   $display(" Total number of correct operations = %d", (ntests-error));
   $display(" ");

end

endmodule
