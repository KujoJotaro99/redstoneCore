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

    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_SLL = 4'd2;
    localparam ALU_SLT = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR = 4'd5;
    localparam ALU_SRL = 4'd6;
    localparam ALU_SRA = 4'd7;
    localparam ALU_OR = 4'd8;
    localparam ALU_AND = 4'd9;
    localparam ALU_PASS = 4'd10;

    assign alu_add_ext_o = {1'b0, alu_src_a_i} + {1'b0, alu_src_b_i};
    assign alu_sub_ext_o = {1'b0, alu_src_a_i} - {1'b0, alu_src_b_i};

    always_comb begin
        case (alu_op_i)
            ALU_ADD: alu_result_o = alu_add_ext_o[WIDTH_P-1:0];
            ALU_SUB: alu_result_o = alu_sub_ext_o[WIDTH_P-1:0];
            ALU_SLL: alu_result_o = alu_src_a_i << alu_src_b_i[$clog2(WIDTH_P)-1:0];
            ALU_SLT: alu_result_o = {{(WIDTH_P-1){1'b0}}, ($signed(alu_src_a_i) < $signed(alu_src_b_i))};
            ALU_SLTU: alu_result_o = {{(WIDTH_P-1){1'b0}}, (alu_src_a_i < alu_src_b_i)};
            ALU_XOR: alu_result_o = alu_src_a_i ^ alu_src_b_i;
            ALU_SRL: alu_result_o = alu_src_a_i >> alu_src_b_i[$clog2(WIDTH_P)-1:0];
            ALU_SRA: alu_result_o = $signed(alu_src_a_i) >>> alu_src_b_i[$clog2(WIDTH_P)-1:0];
            ALU_OR: alu_result_o = alu_src_a_i | alu_src_b_i;
            ALU_AND: alu_result_o = alu_src_a_i & alu_src_b_i;
            ALU_PASS: alu_result_o = alu_src_b_i;
            default: alu_result_o = '0;
        endcase
    end

    assign alu_zero_o = (alu_result_o == '0);
    assign alu_neg_o = alu_result_o[WIDTH_P-1];
    assign alu_borrow_o = (alu_op_i == ALU_SUB) ? alu_sub_ext_o[WIDTH_P] : alu_add_ext_o[WIDTH_P];
    assign alu_overflow_o = 
        ((alu_op_i == ALU_ADD) && ((alu_src_a_i[WIDTH_P-1] == alu_src_b_i[WIDTH_P-1]) && (alu_result_o[WIDTH_P-1] != alu_src_a_i[WIDTH_P-1]))) | 
        ((alu_op_i == ALU_SUB) && ((alu_src_a_i[WIDTH_P-1] != alu_src_b_i[WIDTH_P-1]) && (alu_result_o[WIDTH_P-1] != alu_src_a_i[WIDTH_P-1])));

endmodule
