`timescale 1ns/1ps

// Daniel Flynn, Defne Ulusoy

module cpu5arm(ibus, clk, reset, daddrbus, iaddrbus, databus);
  	input [31:0] ibus;
  	input clk, reset;
  	output [63:0] daddrbus, iaddrbus;
  	inout [63:0] databus;

	wire [63:0] pc_mux_out;
  	program_counter pc(.clk(clk), .reset(reset), .d(pc_mux_out), .q(iaddrbus));

	wire [63:0] pc_adder_out;
  	pc_adder pca(.in0(64'h0000000000000004), .in1(iaddrbus), .out(pc_adder_out));

	wire [31:0] id_if_out;
	wire [63:0] pc_adder_wire;
  	IF_ID_reg if_id(.clk(clk), .id_if_in(ibus), .id_if_out(id_if_out), .pca_in(iaddrbus), .pca_out(pc_adder_wire));

	wire N_bit, Z_bit, V_bit;
	wire [2:0] S_dec;
	wire CinD, ImmD, RegWriteD, MemWriteD, MemToRegD, SetFlagsD, LslD, LsrD, BranchD, CbzD, CbnzD;
	wire [31:0] AselectD, BselectD, DselectD;
	wire [63:0] sign_extend_immediateD;
	wire [5:0] shift_amountD;
	legv8_decoder decoder(.instr(id_if_out),
							.N_bit(N_bit),
							.Z_bit(Z_bit),
							.V_bit(V_bit),
							.S(S_dec),
							.Cin(CinD),
							.Imm(ImmD),
							.RegWrite(RegWriteD),
							.MemWrite(MemWriteD),
							.MemToReg(MemToRegD),
							.SetFlags(SetFlagsD),
							.Lsl(LslD),
							.Lsr(LsrD),
							.Branch(BranchD),
							.Cbz(CbzD),
							.Cbnz(CbnzD),
							.Aselect(AselectD),
							.Bselect(BselectD),
							.Dselect(DselectD),
							.sign_extend_immediate(sign_extend_immediateD),
							.shift_amount(shift_amountD));
	
	wire [31:0] Dselect_wire_final;
	wire [63:0] abusD, bbusD, dbus_mem_wb_mux; // declaring this now
	regfile regfile_inst(.clk(clk), .Aselect(AselectD), .Bselect(BselectD), .Dselect(Dselect_wire_final), .dbus(dbus_mem_wb_mux), .abus(abusD), .bbus(bbusD));

	// sign ext pass to adder
	wire [63:0] se_adder_out;
	se_adder sea(.in0(sign_extend_immediateD), .in1(pc_adder_wire), .out(se_adder_out));

	wire pc_sel;
	assign pc_sel = (CbzD && (bbusD == 64'h0000000000000000)) | (CbnzD && (~(bbusD == 64'h0000000000000000))) | BranchD;
	mux64 pc_mux(.i0(pc_adder_out), .i1(se_adder_out), .sel(pc_sel), .y(pc_mux_out));

	wire [63:0] bbusE, sign_extend_immediateE, abusE;
	wire [31:0] DselectE;
	wire [2:0] S;
	wire Imm, Cin, MemWriteE1, MemToRegE1, RegWriteE1, SetFlagsE, LslE, LsrE;
	wire [5:0] shift_amountE;

	ID_EX_reg id_ex(.clk(clk),
				.abus_in(abusD),
				.bbus_in(bbusD),
				.Dselect_in(DselectD),
				.sign_ext_in(sign_extend_immediateD),
				.S_in(S_dec),
				.Cin_in(CinD),
				.Imm_in(ImmD),
				.RegWrite_in(RegWriteD),
				.MemToReg_in(MemToRegD),
				.MemWrite_in(MemWriteD),
				.SetFlags_in(SetFlagsD),
				.Lsl_in(LslD),
				.Lsr_in(LsrD),
				.shift_amount_in(shift_amountD),
				.abus_out(abusE),
				.bbus_out(bbusE),
				.Dselect_out(DselectE), 
				.sign_ext_out(sign_extend_immediateE),
				.S_out(S),
				.Cin_out(Cin),
				.Imm_out(Imm),
				.RegWrite_out(RegWriteE1),
				.MemToReg_out(MemToRegE1),
				.MemWrite_out(MemWriteE1),
				.SetFlags_out(SetFlagsE),
				.Lsl_out(LslE),
				.Lsr_out(LsrE),
				.shift_amount_out(shift_amountE));
	
	wire [63:0] bbus_alu;
	mux64 bbus_mux(.i0(bbusE), .i1(sign_extend_immediateE), .sel(Imm), .y(bbus_alu));

	wire [63:0] dbus_wire_alu, dbus_wire_shift;
	wire Cout_wire;

    wire N_raw, V_raw, Z_raw;
	alu64 alu_inst(.d(dbus_wire_alu), .Cout(Cout_wire), .V(V_raw), .a(abusE), .b(bbus_alu), .Cin(Cin), .S(S), .Z_flag(Z_raw), .N(N_raw));
	
	reg N_bit_reg, Z_bit_reg, V_bit_reg;
    always @(Z_raw or V_raw or N_raw) begin
        if (SetFlagsE) begin
            N_bit_reg <= N_raw;
            Z_bit_reg <= Z_raw;
            V_bit_reg <= V_raw;
        end
        // else keep previous values
    end

    assign N_bit = N_bit_reg;
    assign Z_bit = Z_bit_reg;
    assign V_bit = V_bit_reg;

	shift64 shift_inst(.d(dbus_wire_shift), .val(abusE), .shamt(shift_amountE), .lsl(LslE), .lsr(LsrE));

	wire [63:0] WriteDataE;
	wire [31:0] DselectM;
	assign WriteDataE = bbusE;
	wire MemWriteE2, MemToRegE2, RegWriteE2;
	assign MemWriteE2 = MemWriteE1;
	assign MemToRegE2 = MemToRegE1;
	assign RegWriteE2 = RegWriteE1;

	wire [63:0] WriteDataM1;
	wire MemWriteM, MemToRegM1, RegWriteM1;

	wire [63:0] dbus_wire;
	wire sl;
	assign sl = LslE | LsrE;
	mux64 op_out_mux(.i0(dbus_wire_alu), .i1(dbus_wire_shift), .sel(sl), .y(dbus_wire));

	EX_MEM_reg ex_mem(.clk(clk),
										.dbus_in(dbus_wire),
										.Dselect_in(DselectE),
										.WriteData_in(WriteDataE),
										.MemWrite_in(MemWriteE2),
										.MemToReg_in(MemToRegE2),
										.RegWrite_in(RegWriteE2),
										.dbus_out(daddrbus),
										.Dselect_out(DselectM),
										.WriteData_out(WriteDataM1),
										.MemWrite_out(MemWriteM),
										.MemToReg_out(MemToRegM1),
										.RegWrite_out(RegWriteM1));
	
	assign databus = (MemWriteM) ? WriteDataM1 : 64'hZZZZZZZZZZZZZZZZ;
	wire [63:0] WriteDataM2;
	assign WriteDataM2 = databus;

	wire MemToRegM2, RegWriteM2;
	wire [63:0] daddrbusM;
	assign MemToRegM2 = MemToRegM1;
	assign RegWriteM2 = RegWriteM1;
	assign daddrbusM = daddrbus;

	wire [63:0] daddrbusW, databus_wire;
	wire [31:0] DselectW;
	wire MemToRegW, RegWriteW;

	MEM_WB_reg mem_wb(.clk(clk),
										.daddrbus_in(daddrbusM),
										.databus_in(WriteDataM2),
										.Dselect_in(DselectM),
										.MemToReg_in(MemToRegM2),
										.RegWrite_in(RegWriteM2),
										.daddrbus_out(daddrbusW),
										.databus_out(databus_wire),
										.Dselect_out(DselectW),
										.MemToReg_out(MemToRegW),
										.RegWrite_out(RegWriteW));
	
	mux64 dbus_mux(.i0(daddrbusW), .i1(databus_wire), .sel(MemToRegW), .y(dbus_mem_wb_mux));
	mux32 dsel_mux(.i0(32'b10000000000000000000000000000000), .i1(DselectW), .sel(RegWriteW), .y(Dselect_wire_final));
endmodule


module legv8_decoder(instr, N_bit, Z_bit, V_bit, S, Cin, Imm, RegWrite, MemWrite, MemToReg, SetFlags, Lsl, Lsr, Branch, Cbz, Cbnz, Aselect, Bselect, Dselect, sign_extend_immediate, shift_amount);
	input [31:0] instr;
	input N_bit, Z_bit, V_bit;

	output [2:0] S;

	// control signals
	output Cin;
	output Imm;
	output RegWrite;
	output MemWrite;
	output MemToReg;
	output SetFlags;
	output Lsl;
	output Lsr;
	output Branch;
	output Cbz;
	output Cbnz;

	// Values to pass forward
  	output [31:0] Aselect, Bselect, Dselect;
	output [63:0] sign_extend_immediate;
  	output [5:0] shift_amount;

	// Values from instruction split up
	wire [4:0] Rd;
	assign Rd = instr[4:0];
	wire [4:0] Rt;
	assign Rt = instr[4:0];
	wire [4:0] Rn;
	assign Rn = instr[9:5];
	wire [4:0] Rm;
	assign Rm = instr[20:16];
	wire [5:0] shamt;
	assign shamt = instr[15:10];
	wire [11:0] i_imm;
	assign i_imm = instr[21:10];
	wire [8:0] d_addr;
	assign d_addr = instr[20:12];
	wire [1:0] op2;
	assign op2 = instr[11:10];
	wire [25:0] b_addr;
	assign b_addr = instr[25:0];
	wire [18:0] cb_addr;
	assign cb_addr = instr[23:5];
	wire [15:0] mov_imm;
	assign mov_imm = instr[20:5];
	wire [1:0] hw;
	assign hw = instr[22:21];

	// Extract relevant opcode fields
	wire [10:0] op11;
	assign op11 = instr[31:21]; // R-format, D-format
	wire [9:0] op10;
	assign op10 = instr[31:22]; // I-format
	wire [8:0] op9;
	assign op9 = instr[31:23]; // IM-format (MOVZ)
	wire [7:0] op8;
	assign op8 = instr[31:24]; // CB-format
	wire [5:0] op6;
	assign op6 = instr[31:26]; // B-format

	// Instruction identification

	// R-format
  	wire is_ADD, is_ADDS, is_AND, is_ANDS, is_EOR, is_ENOR, is_LSL, is_LSR, is_ORR, is_SUB, is_SUBS;
	assign is_ADD  = (op11 == 11'b00101000000);
	assign is_ADDS = (op11 == 11'b00101000001);
	assign is_AND  = (op11 == 11'b00101000010);
	assign is_ANDS = (op11 == 11'b00101000011);
	assign is_EOR  = (op11 == 11'b00101000100);
	assign is_ENOR = (op11 == 11'b00101000101);
	assign is_LSL  = (op11 == 11'b00101000110);
	assign is_LSR  = (op11 == 11'b00101000111);
	assign is_ORR  = (op11 == 11'b00101001000);
	assign is_SUB  = (op11 == 11'b00101001001);
	assign is_SUBS = (op11 == 11'b00101001010);

	// I-format
  	wire is_ADDI, is_ADDIS, is_ANDI, is_ANDIS, is_EORI, is_ENORI, is_ORRI, is_SUBI, is_SUBIS;
	assign is_ADDI  = (op10 == 10'b1000100000);
	assign is_ADDIS = (op10 == 10'b1000100001);
	assign is_ANDI  = (op10 == 10'b1000100010);
	assign is_ANDIS = (op10 == 10'b1000100011);
	assign is_EORI  = (op10 == 10'b1000100100);
	assign is_ENORI = (op10 == 10'b1000100101);
	assign is_ORRI  = (op10 == 10'b1000100110);
	assign is_SUBI  = (op10 == 10'b1000100111);
	assign is_SUBIS = (op10 == 10'b1000101000);
		
	// Loads/Stores (D-format)
  	wire is_LDUR, is_STUR;
	assign is_LDUR = (op11 == 11'b11010000000);
	assign is_STUR = (op11 == 11'b11010000001);

	// Immediate MOV
  	wire is_MOVZ;
	assign is_MOVZ = (op9 == 9'b110010101);

	// B-format
  	wire is_B;
	assign is_B    = (op6 == 6'b000011);

	// CB-format
  	wire is_CBZ, is_CBNZ, is_BEQ, is_BNE, is_BLT, is_BGE;
	assign is_CBZ  = (op8 == 8'b11110100);
	assign is_CBNZ = (op8 == 8'b11110101);
	assign is_BEQ  = (op8 == 8'b01110100);
	assign is_BNE  = (op8 == 8'b01110101);
	assign is_BLT  = (op8 == 8'b01110110);
	assign is_BGE  = (op8 == 8'b01110111);

	// ALU operation encoding
	assign S =
				is_ADD   ? 3'b010 :
				is_ADDS  ? 3'b010 :
				is_AND   ? 3'b110 :
				is_ANDS  ? 3'b110 :
				is_EOR   ? 3'b000 :
				is_ENOR  ? 3'b001 :
				is_LSL   ? 3'bxxx : //dont care
				is_LSR   ? 3'bxxx : //dont care
				is_ORR   ? 3'b100 :
				is_SUB   ? 3'b011 :
				is_SUBS  ? 3'b011 :
				is_ADDI  ? 3'b010 :
				is_ADDIS ? 3'b010 :
				is_ANDI  ? 3'b110 :
				is_ANDIS ? 3'b110 :
				is_EORI  ? 3'b000 :
				is_ENORI ? 3'b001 :
				is_ORRI  ? 3'b100 :
				is_SUBI  ? 3'b011 :
				is_SUBIS ? 3'b011 :
				is_LDUR  ? 3'b010 : // address calc = ADD
				is_STUR  ? 3'b010 :
				is_MOVZ  ? 3'b010 : // going to add 0
				is_B     ? 3'bxxx :
				is_CBZ   ? 3'bxxx :
				is_CBNZ  ? 3'bxxx :
				is_BEQ   ? 3'bxxx :
				is_BNE   ? 3'bxxx :
				is_BLT   ? 3'bxxx :
				is_BGE   ? 3'bxxx :
				3'bxxx;              // default NOP
	
	assign Cin = (S == 3'b011);
	assign Imm = is_ADDI | is_ADDIS | is_ANDI | is_ANDIS | is_EORI | is_ENORI | is_ORRI | is_SUBI | is_SUBIS | is_LDUR | is_STUR | is_MOVZ;

	// Control signals
	assign RegWrite = ~(is_STUR | is_B | is_CBZ | is_CBNZ | is_BEQ | is_BNE | is_BLT | is_BGE);
	assign MemToReg = is_LDUR;
	assign MemWrite = is_STUR;
	assign Lsl = is_LSL;
	assign Lsr = is_LSR;
	assign SetFlags = is_ADDS | is_ANDS | is_SUBS | is_ADDIS | is_ANDIS | is_SUBIS;
	assign Branch = is_B | (is_BEQ & Z_bit) | (is_BNE & ~Z_bit) | (is_BGE & (N_bit == V_bit)) | (is_BLT & ~(N_bit == V_bit));
	assign Cbz = is_CBZ;
	assign Cbnz = is_CBNZ;

	// Values for output
	assign shift_amount = shamt;
	
	assign sign_extend_immediate =
    // I-format (12-bit)
    (is_ADDI | is_ADDIS | is_ANDI  | is_ANDIS | is_EORI | is_ENORI | is_ORRI | is_SUBI | is_SUBIS) ? {{52{1'b0}}, i_imm} :
    // D-format (9-bit)
    (is_LDUR | is_STUR) ? {{55{1'b0}}, d_addr} :
    // CB-format (19-bit), sign-extend but DO NOT shift here
    (is_CBZ | is_CBNZ | is_BEQ | is_BNE | is_BLT | is_BGE) ? {{45{1'b0}}, cb_addr} :
    // B-format (26-bit), sign-extend but DO NOT shift here
    (is_B) ? {{38{1'b0}}, b_addr} :
    // MOVZ: zero-extend 16 bits and shift by hw*16
    (is_MOVZ) ? ({{48{1'b0}}, mov_imm} << (hw * 16)) :
		// Default
    64'hXXXXXXXXXXXXXXXX;
	
	assign Aselect = 
		// R-format, I-format, and D-format
		(is_ADD | is_ADDS | is_AND | is_ANDS | is_EOR | is_ENOR | is_LSL | is_LSR | is_ORR | is_SUB | is_SUBS | is_ADDI | is_ADDIS | is_ANDI  | is_ANDIS | is_EORI | is_ENORI | is_ORRI | is_SUBI | is_SUBIS | is_LDUR | is_STUR) ? (32'b1 << Rn) :
		// IM-format
		(is_MOVZ) ? 32'b10000000000000000000000000000000 :
		// B-format and CB-format
		32'hXXXXXXXX;
	
	assign Bselect =
		// R-format not LSL and LSR
		(is_ADD | is_ADDS | is_AND | is_ANDS | is_EOR | is_ENOR | is_ORR | is_SUB | is_SUBS) ? (32'b1 << Rm) :
		// CBZ and CBNZ and STUR
		(is_CBZ | is_CBNZ | is_STUR) ? (32'b1 << Rt) :
		// I-format, LDUR, B-format, IM-format, CB-format but not CBZ or CBNZ, LSL, LSR
		32'hXXXXXXXX;
	
	assign Dselect = (32'b1 << Rd);
endmodule


module mux32(i0, i1, sel, y);
	input [31:0] i0, i1;
	input sel;
	output [31:0] y;

	assign y = (sel === 1'b1) ? i1 : i0;
endmodule

module mux64(i0, i1, sel, y);
	input [63:0] i0, i1;
	input sel;
	output [63:0] y;

	assign y = (sel === 1'b1) ? i1 : i0;
endmodule


module se_adder(in0, in1, out);
	input [63:0] in0, in1;
	output [63:0] out;
	
	wire [63:0] in0by4;
	assign in0by4 = in0 << 2;
	
	assign out = in0by4 + in1;
endmodule

module pc_adder(in0, in1, out);
	input [63:0] in0;
	input [63:0] in1;
	output [63:0] out;
	
	assign out = in0 + in1;
endmodule

module program_counter(clk, reset, d, q);
	input clk, reset;
	input [63:0] d;
	output reg [63:0] q;
	
	always @(posedge clk or posedge reset) begin
		if (reset) q <= 64'h0000000000000000;
		else q <= d;
	end
endmodule


module IF_ID_reg(clk, id_if_in, id_if_out, pca_in, pca_out);
	input clk;
	input [31:0] id_if_in;
	input [63:0] pca_in;
	output reg [31:0] id_if_out;
	output reg [63:0] pca_out;

	always @(posedge clk) begin
		id_if_out <= id_if_in;
		pca_out <= pca_in;
	end
endmodule


module alu64(d, Cout, V, a, b, Cin, S, Z_flag, N);
	output[63:0] d;
	output Cout, V, Z_flag, N;
	input [63:0] a, b;
	input Cin;
	input [2:0] S;
	
	wire [63:0] c, g, p;
	wire gout, pout;

	alu_cell alucell[63:0] (
		.d(d),
		.g(g),
		.p(p),
		.a(a),
		.b(b),
		.c(c),
		.S(S)
	);
	
	lac6 laclevel6(
		.c(c),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(g),
		.p(p)
	);

	overflow over(
			.Cout(Cout),
			.V(V),
			.gout(gout),
			.pout(pout),
			.Cin(Cin),
			.c(c[63])   
	);
	
	assign Z_flag = (d == 64'h00000000);
	assign N = d[63];
endmodule

module alu_cell (d, g, p, a, b, c, S);
    output reg d, g, p;
    input a, b, c;
    input [2:0] S;
    reg cint, bint;
   
	always @(a or b or c or S or d or g or p or bint or cint) begin
		case(S)
			3'b100: begin
				bint = S[0] ^ b;
				g = a & bint;
				p = a^ bint;
				cint = S[1] & c;
				d = a|b;
			end
			3'b101: begin
				bint = S[0] ^ b;
				g = a & bint;
				p = a^ bint;
				cint = S[1] & c;
				d = ~(a|b);
			end
			3'b110: begin
				bint = S[0] ^ b;
				g = a & bint;
				p = a^ bint;
				cint = S[1] & c;
			d = a & b;
			end
			default: begin
				bint = S[0] ^ b;
				g = a & bint;
				p = a^ bint;
				cint = S[1] & c;
				d = p ^ cint;
			end
		endcase
	end
endmodule

module overflow (Cout, V, gout, pout, Cin, c);
	output Cout, V;
	input gout, pout, Cin, c;
	assign Cout = gout|(pout & Cin);
	assign V = Cout ^ c;
endmodule

module lac(c, gout, pout, Cin, g, p);
	output[1:0]c;
	output gout, pout;
	input Cin;
	input[1:0] g,p;

	assign c[0] = Cin;
	assign c[1] = g[0] | (p[0] & Cin);
	assign gout = g[1] | (p[1] & g[0]);
	assign pout = p[1] & p[0];
endmodule

module lac2(c, gout, pout, Cin, g, p);
	output[3:0] c;
	output gout, pout;
	input Cin;
	input [3:0]g,p;
	wire [1:0] cint, gint, pint;
	lac leaf0(
		.c(c[1:0]),
		.gout(gint[0]),
		.pout(pint[0]),
		.Cin(cint[0]),
		.g(g[1:0]),
		.p(p[1:0])
		);
	lac leaf1(
		.c(c[3:2]),
		.gout(gint[1]),
		.pout(pint[1]),
		.Cin(cint[1]),
		.g(g[3:2]),
		.p(p[3:2])
		);
	lac root(
		.c(cint),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(gint),
		.p(pint)
		);
endmodule  

module lac3(c, gout, pout, Cin, g, p);
	output[7:0] c;
	output gout, pout;
	input Cin;
	input [7:0]g,p;
	wire [1:0] cint, gint, pint;
	lac2 leaf0(
		.c(c[3:0]),
		.gout(gint[0]),
		.pout(pint[0]),
		.Cin(cint[0]),
		.g(g[3:0]),
		.p(p[3:0])
		);
	lac2 leaf1(
		.c(c[7:4]),
		.gout(gint[1]),
		.pout(pint[1]),
		.Cin(cint[1]),
		.g(g[7:4]),
		.p(p[7:4])
		);
	lac root(
		.c(cint),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(gint),
		.p(pint)
		);
endmodule

module lac4(c, gout, pout, Cin, g, p);
	output[15:0] c;
	output gout, pout;
	input Cin;
	input [15:0] g,p;
	wire [1:0] cint, gint, pint;
	lac3 leaf0(
		.c(c[7:0]),
		.gout(gint[0]),
		.pout(pint[0]),
		.Cin(cint[0]),
		.g(g[7:0]),
		.p(p[7:0])
		);
	lac3 leaf1(
		.c(c[15:8]),
		.gout(gint[1]),
		.pout(pint[1]),
		.Cin(cint[1]),
		.g(g[15:8]),
		.p(p[15:8])
		);
	lac root(
		.c(cint),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(gint),
		.p(pint)
		);
endmodule

module lac5(c, gout, pout, Cin, g, p);
	output[31:0] c;
	output gout, pout;
	input Cin;
	input [31:0] g,p;
	wire [1:0] cint, gint, pint;
	lac4 leaf0(
		.c(c[15:0]),
		.gout(gint[0]),
		.pout(pint[0]),
		.Cin(cint[0]),
		.g(g[15:0]),
		.p(p[15:0])
		);
	lac4 leaf1(
		.c(c[31:16]),
		.gout(gint[1]),
		.pout(pint[1]),
		.Cin(cint[1]),
		.g(g[31:16]),
		.p(p[31:16])
		);
	lac root(
		.c(cint),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(gint),
		.p(pint)
		);
endmodule

module lac6(c, gout, pout, Cin, g, p);
	output[63:0] c;
	output gout, pout;
	input Cin;
	input [63:0] g,p;
	wire [1:0] cint, gint, pint;
	lac5 leaf0(
		.c(c[31:0]),
		.gout(gint[0]),
		.pout(pint[0]),
		.Cin(cint[0]),
		.g(g[31:0]),
		.p(p[31:0])
			);
	lac5 leaf1(
		.c(c[63:32]),
		.gout(gint[1]),
		.pout(pint[1]),
		.Cin(cint[1]),
		.g(g[63:32]),
		.p(p[63:32])
			);
	lac root(
		.c(cint),
		.gout(gout),
		.pout(pout),
		.Cin(Cin),
		.g(gint),
		.p(pint)
		);
endmodule


module shift64(d, val, shamt, lsl, lsr);
	input [63:0] val;
	input [5:0] shamt;
	input lsl, lsr;
	output [63:0] d;

	assign d =
			lsl ? (val << shamt) :
			lsr ? (val >> shamt) :
			val;
endmodule


module regfile(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);
	input clk;
	input [31:0] Aselect, Bselect, Dselect;
	input [63:0] dbus;
	output [63:0] abus, bbus;
	
	reg_cell regcell[30:0](
		.clk(clk),
		.Aselect(Aselect[30:0]),
		.Bselect(Bselect[30:0]),
		.Dselect(Dselect[30:0]),
		.dbus(dbus),
		.abus(abus),
		.bbus(bbus)
	);
	
	zero_reg zeroreg(
		.clk(clk),
		.Aselect(Aselect[31]),
		.Bselect(Bselect[31]),
		.Dselect(Dselect[31]),
		.dbus(dbus),
		.abus(abus),
		.bbus(bbus)
	);

endmodule

module dff(d, clk, q, Dselect);
	input [63:0] d;
	input Dselect;
	input clk;
	output reg [63:0] q;

	always @(negedge clk) begin
		if (Dselect==1'b1) q = d;
	end
endmodule

module reg_cell(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);
	input clk;
	input Aselect, Bselect, Dselect;
	input [63:0] dbus;
	output [63:0] abus, bbus;

	wire [63:0] register;

	dff dff_inst(
		.d(dbus),
		.clk(clk),
		.q(register),
		.Dselect(Dselect)
	);
	
	assign abus = (Aselect == 1'b1) ? register : 64'hZZZZZZZZZZZZZZZZ;
	assign bbus = (Bselect == 1'b1) ? register : 64'hZZZZZZZZZZZZZZZZ;
endmodule

module zero_reg(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);
	input clk, Aselect, Bselect, Dselect;
	input [63:0] dbus;
	output [63:0] abus, bbus;
	
	assign abus = (Aselect == 1'b1) ? 64'h0000000000000000 : 64'hZZZZZZZZZZZZZZZZ;
	assign bbus = (Bselect == 1'b1) ? 64'h0000000000000000 : 64'hZZZZZZZZZZZZZZZZ;
endmodule


module ID_EX_reg(clk, abus_in, bbus_in, Dselect_in, sign_ext_in, S_in, Cin_in, Imm_in, RegWrite_in, MemToReg_in, MemWrite_in, SetFlags_in, Lsl_in, Lsr_in, shift_amount_in, abus_out, bbus_out, Dselect_out, sign_ext_out, S_out, Cin_out, Imm_out, RegWrite_out, MemToReg_out, MemWrite_out, SetFlags_out, Lsl_out, Lsr_out, shift_amount_out);
	input clk;
	input [63:0] abus_in, bbus_in, sign_ext_in;
	input [31:0] Dselect_in;
	input [2:0] S_in;
	input Cin_in, Imm_in, RegWrite_in, MemToReg_in, MemWrite_in, SetFlags_in, Lsl_in, Lsr_in;
	input [5:0] shift_amount_in;
	output reg [63:0] abus_out, bbus_out, sign_ext_out;
	output reg [31:0] Dselect_out;
	output reg [2:0] S_out;
	output reg Cin_out, Imm_out, RegWrite_out, MemToReg_out, MemWrite_out, SetFlags_out, Lsl_out, Lsr_out;
	output reg [5:0] shift_amount_out;

	always @(posedge clk) begin
		abus_out <= abus_in;
		bbus_out <= bbus_in;
		Dselect_out <= Dselect_in;
		sign_ext_out <= sign_ext_in;
		S_out <= S_in;
		Cin_out <= Cin_in;
		Imm_out <= Imm_in;
		RegWrite_out <= RegWrite_in;
		MemToReg_out <= MemToReg_in;
		MemWrite_out <= MemWrite_in;
		SetFlags_out <= SetFlags_in;
		Lsl_out <= Lsl_in;
		Lsr_out <= Lsr_in;
		shift_amount_out <= shift_amount_in;
	end
endmodule

module EX_MEM_reg(clk, dbus_in, Dselect_in, WriteData_in, MemWrite_in, MemToReg_in, RegWrite_in, dbus_out, Dselect_out, WriteData_out, MemWrite_out, MemToReg_out, RegWrite_out);
	input clk;
	input [63:0] dbus_in, WriteData_in;
	input [31:0] Dselect_in;
	input MemWrite_in, MemToReg_in, RegWrite_in;
	output reg [63:0] dbus_out, WriteData_out;
	output reg [31:0] Dselect_out;
	output reg MemWrite_out, MemToReg_out, RegWrite_out;
	
	always @(posedge clk) begin
		dbus_out <= dbus_in;
		Dselect_out <= Dselect_in;
		WriteData_out <= WriteData_in;
		MemWrite_out <= MemWrite_in;
		MemToReg_out <= MemToReg_in;
		RegWrite_out <= RegWrite_in;
	end
endmodule

module MEM_WB_reg(clk, daddrbus_in, databus_in, Dselect_in, MemToReg_in, RegWrite_in, daddrbus_out, databus_out, Dselect_out, MemToReg_out, RegWrite_out);
	input clk;
	input [63:0] daddrbus_in, databus_in;
	input [31:0] Dselect_in;
	input MemToReg_in, RegWrite_in;
	output reg [63:0] daddrbus_out, databus_out;
	output reg [31:0] Dselect_out;
	output reg MemToReg_out, RegWrite_out;

	always @(posedge clk) begin
		daddrbus_out <= daddrbus_in;
		databus_out <= databus_in;
		Dselect_out <= Dselect_in;
		MemToReg_out <= MemToReg_in;
		RegWrite_out <= RegWrite_in;
	end
endmodule
