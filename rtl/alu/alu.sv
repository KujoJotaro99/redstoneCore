`timescale 1ns/1ps

module alu 
#(
    parameter WIDTH_P = 32
) (
    input logic [WIDTH_P-1:0] alu_src_a_i,
    input logic [WIDTH_P-1:0] alu_src_b_i,
    input logic [3:0] alu_op_i,
    
    output logic [WIDTH_P-1:0] alu_result_o,
    output logic [0:0] alu_zero_o,
    output logic [0:0] alu_neg_o,
    output logic [0:0] alu_borrow_o,
    output logic [0:0] alu_overflow_o
);

    logic [WIDTH_P:0] alu_add_ext_o;
    logic [WIDTH_P:0] alu_sub_ext_o;
    logic [WIDTH_P-1:0] alu_add_result_w;
    logic [WIDTH_P-1:0] alu_sub_result_w;
    logic [4:0] shamt_w;

    assign alu_add_ext_o = {1'b0, alu_src_a_i} + {1'b0, alu_src_b_i};
    assign alu_sub_ext_o = {1'b0, alu_src_a_i} - {1'b0, alu_src_b_i};
    assign alu_add_result_w = alu_add_ext_o[31:0];
    assign alu_sub_result_w = alu_sub_ext_o[31:0];
    assign shamt_w = alu_src_b_i[4:0];

    always_comb begin
        case (alu_op_i)
            pkg::ALU_ADD: alu_result_o = alu_add_result_w;
            pkg::ALU_SUB: alu_result_o = alu_sub_result_w;
            pkg::ALU_SLL: alu_result_o = alu_src_a_i << shamt_w;
            pkg::ALU_SLT: alu_result_o = {{31{1'b0}}, ($signed(alu_src_a_i) < $signed(alu_src_b_i))};
            pkg::ALU_SLTU: alu_result_o = {{31{1'b0}}, (alu_src_a_i < alu_src_b_i)};
            pkg::ALU_XOR: alu_result_o = alu_src_a_i ^ alu_src_b_i;
            pkg::ALU_SRL: alu_result_o = alu_src_a_i >> shamt_w;
            pkg::ALU_SRA: alu_result_o = $signed(alu_src_a_i) >>> shamt_w;
            pkg::ALU_OR: alu_result_o = alu_src_a_i | alu_src_b_i;
            pkg::ALU_AND: alu_result_o = alu_src_a_i & alu_src_b_i;
            pkg::ALU_PASS: alu_result_o = alu_src_b_i;
            default: alu_result_o = '0;
        endcase
    end

    assign alu_zero_o = (alu_result_o == '0);
    assign alu_neg_o = alu_result_o[31];
    assign alu_borrow_o = (alu_op_i == pkg::ALU_SUB) ? alu_sub_ext_o[32] : alu_add_ext_o[32];
    assign alu_overflow_o = 
        ((alu_op_i == pkg::ALU_ADD) && ((alu_src_a_i[31] == alu_src_b_i[31]) && (alu_result_o[31] != alu_src_a_i[31]))) | 
        ((alu_op_i == pkg::ALU_SUB) && ((alu_src_a_i[31] != alu_src_b_i[31]) && (alu_result_o[31] != alu_src_a_i[31])));

endmodule
