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

    // forwarding interface from ex/mem/wb stages
    input logic [0:0] ex_mem_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] ex_mem_rd_addr_i,
    input logic [0:0] ex_mem_reg_write_i,
    input logic [1:0] ex_mem_wb_sel_i,
    input logic [0:0] mem_wb_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_i,
    input logic [0:0] mem_wb_reg_write_i,

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
    output logic [0:0] id_ex_reg_write_o,
    output logic [0:0] id_ex_mem_read_o,
    output logic [0:0] id_ex_mem_write_o,
    output logic [2:0] id_ex_funct3_o,
    output logic [0:0] id_ex_branch_o,
    output logic [0:0] id_ex_jal_o,
    output logic [0:0] id_ex_jalr_o,
    output logic [2:0] id_ex_branch_type_o,
    output logic [0:0] id_ex_pred_valid_o,
    output logic [0:0] id_ex_pred_taken_o,
    output logic [WIDTH_P-1:0] id_ex_pred_target_o,
    output logic [0:0] id_ex_instr_illegal_o,
    output logic [1:0] id_ex_rs1_fwd_sel_o,
    output logic [1:0] id_ex_rs2_fwd_sel_o,
    output logic [1:0] id_ex_wb_sel_o,

    // wb interface
    input logic [$clog2(DEPTH_P)-1:0] wb_id_rd_addr_i,
    input logic [WIDTH_P-1:0] wb_id_rd_data_i,
    input logic [0:0] wb_id_rd_we_i

);

    logic [6:0] id_ex_opcode_w;
    logic [2:0] id_ex_funct3_w;
    logic [6:0] id_ex_funct7_w;
    logic [0:0] id_ex_rs1_used_w;
    logic [0:0] id_ex_rs2_used_w;
    logic [$clog2(WIDTH_P)-1:0] id_ex_rs1_addr_w;
    logic [$clog2(WIDTH_P)-1:0] id_ex_rs2_addr_w;
    logic [$clog2(WIDTH_P)-1:0] id_ex_rd_addr_w;
    logic [WIDTH_P-1:0] id_ex_imm_w;
    logic [3:0] id_ex_alu_op_w;
    logic [1:0] id_ex_alu_src_a_sel_w;
    logic [1:0] id_ex_alu_src_b_sel_w;
    logic [0:0] id_ex_instr_illegal_w;
    logic [WIDTH_P-1:0] rs1_data_w;
    logic [WIDTH_P-1:0] rs2_data_w;
    logic [0:0] id_ex_reg_write_w;
    logic [0:0] id_ex_mem_read_w;
    logic [0:0] id_ex_mem_write_w;
    logic [0:0] id_ex_branch_w;
    logic [0:0] id_ex_jal_w;
    logic [0:0] id_ex_jalr_w;
    logic [2:0] id_ex_branch_type_w;
    logic [0:0] if_id_stall_w;
    logic [0:0] id_ex_bubble_w;
    logic [1:0] id_ex_wb_sel_w;

    // decode + immediate generation logic
    decode
    #(
        .WIDTH_P(WIDTH_P)
    )
    u_decode (
        .instr_valid_i(if_id_valid_i),
        .instr_i(if_id_instr_i),
        .id_ex_opcode_o(id_ex_opcode_w),
        .id_ex_funct3_o(id_ex_funct3_w),
        .id_ex_funct7_o(id_ex_funct7_w),
        .id_ex_rs1_used_o(id_ex_rs1_used_w),
        .id_ex_rs2_used_o(id_ex_rs2_used_w),
        .id_ex_rs1_addr_o(id_ex_rs1_addr_w),
        .id_ex_rs2_addr_o(id_ex_rs2_addr_w),
        .id_ex_rd_addr_o(id_ex_rd_addr_w),
        .id_ex_imm_o(id_ex_imm_w),
        .id_ex_alu_op_o(id_ex_alu_op_w),
        .id_ex_alu_src_a_sel_o(id_ex_alu_src_a_sel_w),
        .id_ex_alu_src_b_sel_o(id_ex_alu_src_b_sel_w),
        .id_ex_reg_write_o(id_ex_reg_write_w),
        .id_ex_mem_read_o(id_ex_mem_read_w),
        .id_ex_mem_write_o(id_ex_mem_write_w),
        .id_ex_instr_illegal_o(id_ex_instr_illegal_w),
        .id_ex_branch_o(id_ex_branch_w),
        .id_ex_jal_o(id_ex_jal_w),
        .id_ex_jalr_o(id_ex_jalr_w),
        .id_ex_branch_type_o(id_ex_branch_type_w),
        .id_ex_wb_sel_o(id_ex_wb_sel_w)
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

        .rs1_addr_i(id_ex_rs1_addr_w),
        .rs2_addr_i(id_ex_rs2_addr_w),
        .rd_addr_i(wb_id_rd_addr_i),
        .rd_data_i(wb_id_rd_data_i),
        .rd_we_i(wb_id_rd_we_i),

        .rs1_data_o(rs1_data_w),
        .rs2_data_o(rs2_data_w)
    );

    // hazard unit
    hazard_unit
    #(
        .DEPTH_P(DEPTH_P)
    )
    u_hazard_unit (
        .if_id_valid_i(if_id_valid_i),
        .id_ex_valid_i(id_ex_valid_o),
        .rs1_used_i(id_ex_rs1_used_w),
        .rs2_used_i(id_ex_rs2_used_w),
        .rs1_addr_i(id_ex_rs1_addr_w),
        .rs2_addr_i(id_ex_rs2_addr_w),
        .id_ex_rs1_used_i(id_ex_rs1_used_o),
        .id_ex_rs2_used_i(id_ex_rs2_used_o),
        .id_ex_rs1_addr_i(id_ex_rs1_addr_o),
        .id_ex_rs2_addr_i(id_ex_rs2_addr_o),
        .id_ex_rd_addr_i(id_ex_rd_addr_o),
        .id_ex_reg_write_i(id_ex_reg_write_o),
        .id_ex_mem_read_i(id_ex_mem_read_o),
        .ex_mem_valid_i(ex_mem_valid_i), 
        .ex_mem_rd_addr_i(ex_mem_rd_addr_i),
        .ex_mem_reg_write_i(ex_mem_reg_write_i),
        .ex_mem_wb_sel_i(ex_mem_wb_sel_i),
        .mem_wb_valid_i(mem_wb_valid_i), 
        .mem_wb_rd_addr_i(mem_wb_rd_addr_i),
        .mem_wb_reg_write_i(mem_wb_reg_write_i),
        .if_id_stall_o(if_id_stall_w),
        .id_ex_bubble_o(id_ex_bubble_w),
        .id_ex_rs1_fwd_sel_o(id_ex_rs1_fwd_sel_o),
        .id_ex_rs2_fwd_sel_o(id_ex_rs2_fwd_sel_o)
    );

    assign id_if_ready_o = ~stall_i & ~if_id_stall_w & (~id_ex_valid_o | ex_id_ready_i);

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
            id_ex_reg_write_o <= 1'b0;
            id_ex_mem_read_o <= 1'b0;
            id_ex_mem_write_o <= 1'b0;
            id_ex_funct3_o <= '0;
            id_ex_branch_o <= 1'b0;
            id_ex_jal_o <= 1'b0;
            id_ex_jalr_o <= 1'b0;
            id_ex_branch_type_o <= '0;
            id_ex_wb_sel_o <= pkg::WB_ALU;
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
            id_ex_reg_write_o <= 1'b0;
            id_ex_mem_read_o <= 1'b0;
            id_ex_mem_write_o <= 1'b0;
            id_ex_funct3_o <= '0;
            id_ex_branch_o <= 1'b0;
            id_ex_jal_o <= 1'b0;
            id_ex_jalr_o <= 1'b0;
            id_ex_branch_type_o <= '0;
            id_ex_wb_sel_o <= pkg::WB_ALU;
        end else if (id_ex_bubble_w & ex_id_ready_i) begin
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
            id_ex_reg_write_o <= 1'b0;
            id_ex_mem_read_o <= 1'b0;
            id_ex_mem_write_o <= 1'b0;
            id_ex_funct3_o <= '0;
            id_ex_branch_o <= 1'b0;
            id_ex_jal_o <= 1'b0;
            id_ex_jalr_o <= 1'b0;
            id_ex_branch_type_o <= '0;
            id_ex_wb_sel_o <= pkg::WB_ALU;
        end else if (id_if_ready_o) begin
            id_ex_valid_o <= if_id_valid_i;
            id_ex_pc_o <= if_id_pc_i;
            id_ex_pc4_o <= if_id_pc4_i;
            id_ex_rs1_data_o <= rs1_data_w;
            id_ex_rs2_data_o <= rs2_data_w;
            id_ex_imm_o <= id_ex_imm_w;
            id_ex_rs1_addr_o <= id_ex_rs1_addr_w;
            id_ex_rs2_addr_o <= id_ex_rs2_addr_w;
            id_ex_rd_addr_o <= id_ex_rd_addr_w;
            id_ex_rs1_used_o <= id_ex_rs1_used_w;
            id_ex_rs2_used_o <= id_ex_rs2_used_w;
            id_ex_alu_op_o <= id_ex_alu_op_w;
            id_ex_alu_src_a_sel_o <= id_ex_alu_src_a_sel_w;
            id_ex_alu_src_b_sel_o <= id_ex_alu_src_b_sel_w;
            id_ex_pred_valid_o <= if_id_pred_valid_i;
            id_ex_pred_taken_o <= if_id_pred_taken_i;
            id_ex_pred_target_o <= if_id_pred_target_i;
            id_ex_instr_illegal_o <= id_ex_instr_illegal_w;
            id_ex_reg_write_o <= id_ex_reg_write_w;
            id_ex_mem_read_o <= id_ex_mem_read_w;
            id_ex_mem_write_o <= id_ex_mem_write_w;
            id_ex_funct3_o <= id_ex_funct3_w;
            id_ex_branch_o <= id_ex_branch_w;
            id_ex_jal_o <= id_ex_jal_w;
            id_ex_jalr_o <= id_ex_jalr_w;
            id_ex_branch_type_o <= id_ex_branch_type_w;
            id_ex_wb_sel_o <= id_ex_wb_sel_w;
        end
    end
endmodule
