`timescale 1ns/1ps

module id_stage 
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 32
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [0:0] stall_i,

    // if interface
    input logic [0:0] if_id_valid_i, // valid response
    output logic [0:0] id_if_ready_o, // ready to consume response
    input logic [WIDTH_P-1:0] if_id_instr_i,
    input logic [WIDTH_P-1:0] if_id_pc_i,
    input logic [WIDTH_P-1:0] if_id_pc4_i,
    input logic [0:0] if_id_pred_valid_i,
    input logic [0:0] if_id_pred_taken_i,
    input logic [WIDTH_P-1:0] if_id_pred_target_i,

    // ex interface
    output logic [0:0] id_ex_valid_o,
    input logic [0:0] ex_id_ready_i,
    output logic [WIDTH_P-1:0] id_ex_pc_o,
    output logic [WIDTH_P-1:0] id_ex_pc4_o,
    output logic [WIDTH_P-1:0] id_ex_rs1_data_o,
    output logic [WIDTH_P-1:0] id_ex_rs2_data_o,
    output logic [WIDTH_P-1:0] id_ex_imm_o,
    output logic [$clog2(DEPTH_P)-1:0] id_ex_rs1_addr_o,
    output logic [$clog2(DEPTH_P)-1:0] id_ex_rs2_addr_o,
    output logic [$clog2(DEPTH_P)-1:0] id_ex_rd_addr_o,
    output logic [0:0] id_ex_rs1_used_o,
    output logic [0:0] id_ex_rs2_used_o,
    output logic [3:0] id_ex_alu_op_o,
    output logic [1:0] id_ex_alu_src_a_sel_o,
    output logic [1:0] id_ex_alu_src_b_sel_o,
    output logic [0:0] id_ex_pred_valid_o,
    output logic [0:0] id_ex_pred_taken_o,
    output logic [WIDTH_P-1:0] id_ex_pred_target_o,
    output logic [0:0] id_ex_instr_illegal_o,

    // wb interface
    input logic [$clog2(DEPTH_P)-1:0] wb_id_rd_addr_i,
    input logic [WIDTH_P-1:0] wb_id_rd_data_i,
    input logic [0:0] wb_id_rd_we_i

);

    logic [6:0] opcode_w;
    logic [2:0] funct3_w;
    logic [6:0] funct7_w;
    logic [0:0] rs1_used_w;
    logic [0:0] rs2_used_w;
    logic [$clog2(WIDTH_P)-1:0] rs1_addr_w;
    logic [$clog2(WIDTH_P)-1:0] rs2_addr_w;
    logic [$clog2(WIDTH_P)-1:0] rd_addr_w;
    logic [WIDTH_P-1:0] imm_gen_w;
    logic [3:0] id_ex_alu_op_w;
    logic [1:0] id_ex_alu_src_a_sel_w;
    logic [1:0] id_ex_alu_src_b_sel_w;
    logic [0:0] instr_illegal_w;
    logic [WIDTH_P-1:0] rs1_data_w;
    logic [WIDTH_P-1:0] rs2_data_w;

    // decode + immediate generation logic
    decode
    #(
        .WIDTH_P(WIDTH_P)
    )
    u_decode (
        .instr_valid_i(if_id_valid_i),
        .instr_i(if_id_instr_i),
        .opcode_o(opcode_w),
        .funct3_o(funct3_w),
        .funct7_o(funct7_w),
        .rs1_used_o(rs1_used_w),
        .rs2_used_o(rs2_used_w),
        .rs1_addr_o(rs1_addr_w),
        .rs2_addr_o(rs2_addr_w),
        .rd_addr_o(rd_addr_w),
        .imm_gen_o(imm_gen_w),
        .id_ex_alu_op_o(id_ex_alu_op_w),
        .id_ex_alu_src_a_sel_o(id_ex_alu_src_a_sel_w),
        .id_ex_alu_src_b_sel_o(id_ex_alu_src_b_sel_w),
        .instr_illegal_o(instr_illegal_w)
    );

    // register file
    regfile 
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    ) 
    u_regfile (
        .clk_i(clk_i),
        .rstn_i(rstn_i),

        .rs1_addr_i(rs1_addr_w),
        .rs2_addr_i(rs2_addr_w),
        .rd_addr_i(wb_id_rd_addr_i),
        .rd_data_i(wb_id_rd_data_i),
        .rd_we_i(wb_id_rd_we_i),

        .rs1_data_o(rs1_data_w),
        .rs2_data_o(rs2_data_w)
    );

    // hazard unit
    assign id_if_ready_o = ~stall_i & (~id_ex_valid_o | ex_id_ready_i);

    // id ex pipeline block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            id_ex_valid_o <= 1'b0;
            id_ex_pc_o <= '0;
            id_ex_pc4_o <= '0;
            id_ex_rs1_data_o <= '0;
            id_ex_rs2_data_o <= '0;
            id_ex_imm_o <= '0;
            id_ex_rs1_addr_o <= '0;
            id_ex_rs2_addr_o <= '0;
            id_ex_rd_addr_o <= '0;
            id_ex_rs1_used_o <= 1'b0;
            id_ex_rs2_used_o <= 1'b0;
            id_ex_alu_op_o <= '0;
            id_ex_alu_src_a_sel_o <= '0;
            id_ex_alu_src_b_sel_o <= '0;
            id_ex_pred_valid_o <= 1'b0;
            id_ex_pred_taken_o <= 1'b0;
            id_ex_pred_target_o <= '0;
            id_ex_instr_illegal_o <= 1'b0;
        end else if (flush_i) begin
            id_ex_valid_o <= 1'b0;
            id_ex_pc_o <= '0;
            id_ex_pc4_o <= '0;
            id_ex_rs1_data_o <= '0;
            id_ex_rs2_data_o <= '0;
            id_ex_imm_o <= '0;
            id_ex_rs1_addr_o <= '0;
            id_ex_rs2_addr_o <= '0;
            id_ex_rd_addr_o <= '0;
            id_ex_rs1_used_o <= 1'b0;
            id_ex_rs2_used_o <= 1'b0;
            id_ex_alu_op_o <= '0;
            id_ex_alu_src_a_sel_o <= '0;
            id_ex_alu_src_b_sel_o <= '0;
            id_ex_pred_valid_o <= 1'b0;
            id_ex_pred_taken_o <= 1'b0;
            id_ex_pred_target_o <= '0;
            id_ex_instr_illegal_o <= 1'b0;
        end else if (id_if_ready_o) begin
            id_ex_valid_o <= if_id_valid_i;
            id_ex_pc_o <= if_id_pc_i;
            id_ex_pc4_o <= if_id_pc4_i;
            id_ex_rs1_data_o <= rs1_data_w;
            id_ex_rs2_data_o <= rs2_data_w;
            id_ex_imm_o <= imm_gen_w;
            id_ex_rs1_addr_o <= rs1_addr_w;
            id_ex_rs2_addr_o <= rs2_addr_w;
            id_ex_rd_addr_o <= rd_addr_w;
            id_ex_rs1_used_o <= rs1_used_w;
            id_ex_rs2_used_o <= rs2_used_w;
            id_ex_alu_op_o <= id_ex_alu_op_w;
            id_ex_alu_src_a_sel_o <= id_ex_alu_src_a_sel_w;
            id_ex_alu_src_b_sel_o <= id_ex_alu_src_b_sel_w;
            id_ex_pred_valid_o <= if_id_pred_valid_i;
            id_ex_pred_taken_o <= if_id_pred_taken_i;
            id_ex_pred_target_o <= if_id_pred_target_i;
            id_ex_instr_illegal_o <= instr_illegal_w;
        end
    end
endmodule
