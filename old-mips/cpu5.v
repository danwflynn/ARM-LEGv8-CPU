`timescale 1ns/1ps

module cpu5(ibus, clk, reset, daddrbus, iaddrbus, databus);
    input [31:0] ibus;
    input clk, reset;
    output [31:0] daddrbus, iaddrbus;
    inout [31:0] databus;
    
    wire [31:0] pc_mux_out;
    program_counter pc(.clk(clk), .reset(reset), .d(pc_mux_out), .q(iaddrbus));
    
    wire [31:0] pc_adder_out;
    pc_adder pca(.in0(32'h00000004), .in1(iaddrbus), .out(pc_adder_out));

    wire [31:0] id_if_out, pc_adder_wire;
    IF_ID_reg if_id(.clk(clk), .id_if_in(ibus), .id_if_out(id_if_out), .pca_in(pc_adder_out), .pca_out(pc_adder_wire));

    wire [5:0] opcode, func;
    wire [4:0] rs, rt, rd;

    assign opcode = id_if_out[31:26];
    assign rs = id_if_out[25:21];
    assign rt = id_if_out[20:16];
    assign rd = id_if_out[15:11];
    assign func = id_if_out[5:0];

    wire [31:0] rs_out, rt_out, rd_out;
    
    reg_decoder rs_dec(.reg_in(rs), .reg_out(rs_out));
    reg_decoder rt_dec(.reg_in(rt), .reg_out(rt_out));
    reg_decoder rd_dec(.reg_in(rd), .reg_out(rd_out));

    wire [2:0] s_dec;
    wire cin_dec, imm_dec, MemWriteD, MemToRegD, RegWriteD, BeqD, BneD, SltD, SleD;

    opcode_decoder op_dec(.opcode(opcode), 
                          .func(func), 
                          .S(s_dec), 
                          .Cin(cin_dec), 
                          .Imm(imm_dec), 
                          .MemWrite(MemWriteD), 
                          .MemToReg(MemToRegD),
                          .RegWrite(RegWriteD),
                          .Beq(BeqD),
                          .Bne(BneD),
                          .Slt(SltD),
                          .Sle(SleD));
    
    wire [31:0] se_imm_value_wire;
    sign_ext_decoder se_dec(.in(id_if_out[15:0]), .out(se_imm_value_wire));

    wire [31:0] Dselect_wire1;
    mux Dselect_mux(.i0(rd_out), .i1(rt_out), .sel(imm_dec), .y(Dselect_wire1));

    wire [31:0] Dselect_wire_final, abus_wire, bbus_wire1;
    wire [31:0] dbus_mem_wb_mux; // declaring this now
    wire result_equal;
    regfile regfile_inst(.clk(clk), .Aselect(rs_out), .Bselect(rt_out), .Dselect(Dselect_wire_final), .dbus(dbus_mem_wb_mux), .abus(abus_wire), .bbus(bbus_wire1));

    // sign ext pass to adder
    wire [31:0] se_adder_out;
    adder sea(.in0(se_imm_value_wire), .in1(pc_adder_wire), .out(se_adder_out));
    
    wire pc_sel;
    assign pc_sel = (BeqD && (abus_wire == bbus_wire1)) | (BneD && (~((abus_wire == bbus_wire1))));
    mux pc_mux(.i0(pc_adder_out), .i1(se_adder_out), .sel(pc_sel), .y(pc_mux_out));

    wire [31:0] bbus_wire2, sign_ext_wire, abus, Dselect_wire2;
    wire [2:0] S;
    wire Imm, Cin, MemWriteE1, MemToRegE1, RegWriteE1, SltE1, SleE1;

    ID_EX_reg id_ex(.clk(clk),
                    .abus_in(abus_wire),
                    .bbus_in(bbus_wire1),
                    .Dselect_in(Dselect_wire1),
                    .sign_ext_in(se_imm_value_wire),
                    .S_in(s_dec),
                    .Cin_in(cin_dec),
                    .Imm_in(imm_dec),
                    .RegWrite_in(RegWriteD),
                    .MemToReg_in(MemToRegD),
                    .MemWrite_in(MemWriteD),
                    .Slt_in(SltD),
                    .Sle_in(SleD),
                    .abus_out(abus),
                    .bbus_out(bbus_wire2),
                    .Dselect_out(Dselect_wire2), 
                    .sign_ext_out(sign_ext_wire),
                    .S_out(S),
                    .Cin_out(Cin),
                    .Imm_out(Imm),
                    .RegWrite_out(RegWriteE1),
                    .MemToReg_out(MemToRegE1),
                    .MemWrite_out(MemWriteE1),
                    .Slt_out(SltE1),
                    .Sle_out(SleE1));
    
    wire [31:0] bbus;
    mux bbus_mux(.i0(bbus_wire2), .i1(sign_ext_wire), .sel(Imm), .y(bbus));

    wire [31:0] dbus_wire_alu, dbus_wire_comp;
    wire Cout_wire, V_wire, Z_wire;
    
    alu32 alu_inst(.d(dbus_wire_alu), .Cout(Cout_wire), .V(V_wire), .a(abus), .b(bbus), .Cin(Cin), .S(S), .Z(Z_wire));
    Compare32 comp32(.C(Cout_wire), .Z(Z_wire), .ctrl_slt(SltE1), .ctrl_sle(SleE1), .Result(dbus_wire_comp));

    wire [31:0] WriteDataE, Dselect_wire3;
    assign WriteDataE = bbus_wire2;
    wire MemWriteE2, MemToRegE2, RegWriteE2;
    assign MemWriteE2 = MemWriteE1;
    assign MemToRegE2 = MemToRegE1;
    assign RegWriteE2 = RegWriteE1;

    wire [31:0] WriteDataM1;
    wire MemWriteM, MemToRegM1, RegWriteM1;

    wire [31:0] dbus_wire;
    wire sl;
    assign sl = SltE1 | SleE1;
    mux op_out_mux(.i0(dbus_wire_alu), .i1(dbus_wire_comp), .sel(sl), .y(dbus_wire));

    EX_MEM_reg ex_mem(.clk(clk),
                      .dbus_in(dbus_wire),
                      .Dselect_in(Dselect_wire2),
                      .WriteData_in(WriteDataE),
                      .MemWrite_in(MemWriteE2),
                      .MemToReg_in(MemToRegE2),
                      .RegWrite_in(RegWriteE2),
                      .dbus_out(daddrbus),
                      .Dselect_out(Dselect_wire3),
                      .WriteData_out(WriteDataM1),
                      .MemWrite_out(MemWriteM),
                      .MemToReg_out(MemToRegM1),
                      .RegWrite_out(RegWriteM1));
    
    assign databus = (MemWriteM) ? WriteDataM1 : 32'hZZZZZZZZ;
    wire [31:0] WriteDataM2;
    assign WriteDataM2 = databus;

    wire MemToRegM2, RegWriteM2;
    wire [31:0] daddrbus_wire1;
    assign MemToRegM2 = MemToRegM1;
    assign RegWriteM2 = RegWriteM1;
    assign daddrbus_wire1 = daddrbus;

    wire [31:0] daddrbus_wire2, Dselect_wire4, databus_wire;
    wire MemToRegW, RegWriteW;

    MEM_WB_reg mem_wb(.clk(clk),
                      .daddrbus_in(daddrbus_wire1),
                      .databus_in(WriteDataM2),
                      .Dselect_in(Dselect_wire3),
                      .MemToReg_in(MemToRegM2),
                      .RegWrite_in(RegWriteM2),
                      .daddrbus_out(daddrbus_wire2),
                      .databus_out(databus_wire),
                      .Dselect_out(Dselect_wire4),
                      .MemToReg_out(MemToRegW),
                      .RegWrite_out(RegWriteW));
    
    mux dbus_mux(.i0(daddrbus_wire2), .i1(databus_wire), .sel(MemToRegW), .y(dbus_mem_wb_mux));
    mux dsel_mux(.i0(32'h00000001), .i1(Dselect_wire4), .sel(RegWriteW), .y(Dselect_wire_final));

endmodule

module adder(in0, in1, out);
  input [31:0] in0, in1;
  output [31:0] out;
  
  wire [31:0] in0by4;
  assign in0by4 = in0 << 2;
  
  assign out = in0by4 + in1;
  
endmodule

module pc_adder(in0, in1, out);
  input [31:0] in0;
  input [31:0] in1;
  output [31:0] out;
  
  assign out = in0 + in1;
  
endmodule

module program_counter(clk, reset, d, q);
  input clk, reset;
  input [31:0] d;
  output reg [31:0] q;
  
  always @(posedge clk or posedge reset) begin
    if (reset) q <= 32'h00000000;
    else q <= d;
  end
endmodule

module IF_ID_reg(clk, id_if_in, id_if_out, pca_in, pca_out);
    input clk;
    input [31:0] id_if_in, pca_in;
    output reg [31:0] id_if_out, pca_out;

    always @(posedge clk) begin
        id_if_out <= id_if_in;
        pca_out <= pca_in;
    end
endmodule

module reg_decoder(reg_in, reg_out);
    input [4:0] reg_in;
    output [31:0] reg_out;
    assign reg_out = 32'b1 << reg_in;
endmodule

module opcode_decoder(opcode, func, S, Cin, Imm, MemWrite, MemToReg, RegWrite, Beq, Bne, Slt, Sle);
    input [5:0] opcode, func;
    output [2:0] S;
    output Cin, Imm, MemWrite, MemToReg, RegWrite, Beq, Bne, Slt, Sle;
    assign S =
        (opcode == 6'b000011) ? 3'b010 :
        (opcode == 6'b000010) ? 3'b011 :
        (opcode == 6'b000001) ? 3'b000 :
        (opcode == 6'b001111) ? 3'b110 :
        (opcode == 6'b001100) ? 3'b100 :
        ((opcode == 6'b000000) && (func == 6'b000011)) ? 3'b010 :
        ((opcode == 6'b000000) && (func == 6'b000010)) ? 3'b011 :
        ((opcode == 6'b000000) && (func == 6'b000001)) ? 3'b000 :
        ((opcode == 6'b000000) && (func == 6'b000111)) ? 3'b110 :
        ((opcode == 6'b000000) && (func == 6'b000100)) ? 3'b100 :
        ((opcode == 6'b000000) && (func == 6'b110110)) ? 3'b011 : // slt
        ((opcode == 6'b000000) && (func == 6'b110111)) ? 3'b011 : // sle
        (opcode == 6'b011110) ? 3'b010 :
        (opcode == 6'b011111) ? 3'b010 :
        (opcode == 6'b110000) ? 3'b011 : // beq
        (opcode == 6'b110001) ? 3'b011 : // bne
        3'bxxx;
    assign Cin = (opcode == 6'b000010) | ((opcode == 6'b000000) && func == 6'b000010) | ((opcode == 6'b000000) && (func == 6'b110110)) | ((opcode == 6'b000000) && (func == 6'b110111)) | (opcode == 6'b110000) | (opcode == 6'b110001);
    assign Imm = (opcode == 6'b000011) | (opcode == 6'b000010) | (opcode == 6'b000001) | (opcode == 6'b001111) | (opcode == 6'b001100) | (opcode == 6'b011110) | (opcode == 6'b011111) | (opcode == 6'b110000) | (opcode == 6'b110001);
    assign RegWrite = ~((opcode == 6'b011111) | (opcode == 6'b110000) | (opcode == 6'b110001)); //not sw or branch
    assign MemToReg = (opcode == 6'b011110); //lw
    assign MemWrite = (opcode == 6'b011111); //sw
    assign Beq = (opcode == 6'b110000);
    assign Bne = (opcode == 6'b110001);
    assign Slt = ((opcode == 6'b000000) && (func == 6'b110110));
    assign Sle = ((opcode == 6'b000000) && (func == 6'b110111));
endmodule

module sign_ext_decoder(in, out);
    input [15:0] in;
    output [31:0] out;
    assign out = {{16{in[15]}}, in};
endmodule


module mux(i0, i1, sel, y);
    input [31:0] i0, i1;
    input sel;
    output [31:0] y;

    assign y = (sel === 1'b1) ? i1 : i0;
endmodule


module regfile(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);

    input clk;
    input [31:0] Aselect, Bselect, Dselect, dbus;
    output [31:0] abus, bbus;
    
    reg_cell regcell[31:1](
        .clk(clk),
        .Aselect(Aselect[31:1]),
        .Bselect(Bselect[31:1]),
        .Dselect(Dselect[31:1]),
        .dbus(dbus),
        .abus(abus),
        .bbus(bbus)
    );
    
    zero_reg zeroreg(
        .clk(clk),
        .Aselect(Aselect[0]),
        .Bselect(Bselect[0]),
        .Dselect(Dselect[0]),
        .dbus(dbus),
        .abus(abus),
        .bbus(bbus)
    );

endmodule

module dff(d, clk, q, Dselect);

    input [31:0] d;
  	input Dselect;
    input clk;
    output reg [31:0] q;

	always @(negedge clk) begin
      if (Dselect==1'b1) q = d;
	end

endmodule

module reg_cell(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);
    input clk;
    input Aselect, Bselect, Dselect;
    input [31:0] dbus;
    output [31:0] abus, bbus;

    wire [31:0] register;
    

    dff dff_inst(
      .d(dbus),
      .clk(clk),
      .q(register),
      .Dselect(Dselect)
    );
    
    assign abus = (Aselect == 1'b1) ? register : 32'hZZZZZZZZ;
    assign bbus = (Bselect == 1'b1) ? register : 32'hZZZZZZZZ;

endmodule

module zero_reg(clk, Aselect, Bselect, Dselect, dbus, abus, bbus);

    input clk, Aselect, Bselect, Dselect;
    input [31:0] dbus;
    output [31:0] abus, bbus;
    
    assign abus = (Aselect == 1'b1) ? 32'h00000000 : 32'hZZZZZZZZ;
    assign bbus = (Bselect == 1'b1) ? 32'h00000000 : 32'hZZZZZZZZ;

endmodule


module ID_EX_reg(clk, abus_in, bbus_in, Dselect_in, sign_ext_in, S_in, Cin_in, Imm_in, RegWrite_in, MemToReg_in, MemWrite_in, Slt_in, Sle_in, abus_out, bbus_out, Dselect_out, sign_ext_out, S_out, Cin_out, Imm_out, RegWrite_out, MemToReg_out, MemWrite_out, Slt_out, Sle_out);
    input clk;
    input [31:0] abus_in, bbus_in, Dselect_in, sign_ext_in;
    input [2:0] S_in;
    input Cin_in, Imm_in, RegWrite_in, MemToReg_in, MemWrite_in, Slt_in, Sle_in;
    output reg [31:0] abus_out, bbus_out, Dselect_out, sign_ext_out;
    output reg [2:0] S_out;
    output reg Cin_out, Imm_out, RegWrite_out, MemToReg_out, MemWrite_out, Slt_out, Sle_out;

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
        Slt_out <= Slt_in;
        Sle_out <= Sle_in;
    end
endmodule


module alu32 (d, Cout, V, a, b, Cin, S, Z);
   output[31:0] d;
   output Cout, V, Z;
   input [31:0] a, b;
   input Cin;
   input [2:0] S;
   
   wire [31:0] c, g, p;
   wire gout, pout;

 
   alu_cell alucell[31:0] (
      .d(d),
      .g(g),
      .p(p),
      .a(a),
      .b(b),
      .c(c),
      .S(S)
   );
   
   lac5 laclevel5(
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
       .c(c[31])   
   );
   
   assign Z = (d == 32'h00000000);
 
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
    input [15:0]g,p;
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
    input [31:0]g,p;
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

module Compare32 (C, Z, ctrl_slt, ctrl_sle, Result);
    input C, Z, ctrl_slt, ctrl_sle;
    output [31:0] Result;

    wire slt_result;
    wire sle_result;

    assign slt_result = (~C & ~Z);
    assign sle_result = (~C | Z);

    assign Result = ({31'b0, (ctrl_slt & slt_result) | (ctrl_sle & sle_result)});

endmodule


module EX_MEM_reg(clk, dbus_in, Dselect_in, WriteData_in, MemWrite_in, MemToReg_in, RegWrite_in, dbus_out, Dselect_out, WriteData_out, MemWrite_out, MemToReg_out, RegWrite_out);
    input clk;
    input [31:0] dbus_in, Dselect_in, WriteData_in;
    input MemWrite_in, MemToReg_in, RegWrite_in;
    output reg [31:0] dbus_out, Dselect_out, WriteData_out;
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
    input [31:0] daddrbus_in, databus_in, Dselect_in;
    input MemToReg_in, RegWrite_in;
    output reg [31:0] daddrbus_out, databus_out, Dselect_out;
    output reg MemToReg_out, RegWrite_out;

    always @(posedge clk) begin
        daddrbus_out <= daddrbus_in;
        databus_out <= databus_in;
        Dselect_out <= Dselect_in;
        MemToReg_out <= MemToReg_in;
        RegWrite_out <= RegWrite_in;
    end
endmodule
