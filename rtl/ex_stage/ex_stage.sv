`timescale 1ns/1ps

module ex_stage 
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
    output logic [0:0] ex_if_redirect_valid_o, 
    output logic [WIDTH_P-1:0] ex_if_redirect_pc_o, 
    output logic [0:0] btb_update_valid_o, 
    output logic [WIDTH_P-1:0] btb_update_pc_o, 
    output logic [0:0] btb_update_taken_o, 
    output logic [WIDTH_P-1:0] btb_update_target_o,

    // id interface
    input logic [0:0] id_ex_valid_i,
    output logic [0:0] ex_id_ready_o,
    input logic [WIDTH_P-1:0] id_ex_pc_i,
    input logic [WIDTH_P-1:0] id_ex_pc4_i,
    input logic [WIDTH_P-1:0] id_ex_rs1_data_i,
    input logic [WIDTH_P-1:0] id_ex_rs2_data_i,
    input logic [WIDTH_P-1:0] id_ex_imm_i,
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rs1_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rs2_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rd_addr_i,
    input logic [0:0] id_ex_rs1_used_i,
    input logic [0:0] id_ex_rs2_used_i,
    input logic [3:0] id_ex_alu_op_i,
    input logic [1:0] id_ex_alu_src_a_sel_i,
    input logic [1:0] id_ex_alu_src_b_sel_i,
    input logic [0:0] id_ex_reg_write_i,
    input logic [0:0] id_ex_mem_read_i,
    input logic [0:0] id_ex_mem_write_i,
    input logic [2:0] id_ex_funct3_i,
    input logic [0:0] id_ex_branch_i,
    input logic [0:0] id_ex_jal_i,
    input logic [0:0] id_ex_jalr_i,
    input logic [2:0] id_ex_branch_type_i,
    input logic [0:0] id_ex_pred_valid_i,
    input logic [0:0] id_ex_pred_taken_i,
    input logic [WIDTH_P-1:0] id_ex_pred_target_i,
    input logic [0:0] id_ex_instr_illegal_i,
    input logic [1:0] id_ex_rs1_fwd_sel_i,
    input logic [1:0] id_ex_rs2_fwd_sel_i,
    input logic [1:0] id_ex_wb_sel_i,

    // forwarding interface
    input logic [WIDTH_P-1:0] ex_mem_fwd_data_i,
    input logic [WIDTH_P-1:0] mem_wb_fwd_data_i,

    // mem interface
    input logic [0:0] mem_ex_ready_i,
    output logic [0:0] ex_mem_valid_o, 
    output logic [WIDTH_P-1:0] ex_mem_pc_o, 
    output logic [WIDTH_P-1:0] ex_mem_pc4_o, 
    output logic [WIDTH_P-1:0] ex_mem_alu_result_o, 
    output logic [WIDTH_P-1:0] ex_mem_rs2_data_o, 
    output logic [$clog2(DEPTH_P)-1:0] ex_mem_rd_addr_o, 
    output logic [0:0] ex_mem_reg_write_o, 
    output logic [0:0] ex_mem_mem_read_o, 
    output logic [0:0] ex_mem_mem_write_o,
    output logic [2:0] ex_mem_funct3_o,
    output logic [0:0] ex_mem_instr_illegal_o,
    output logic [1:0] ex_mem_wb_sel_o

);

    logic [WIDTH_P-1:0] rs1_data_w;
    logic [WIDTH_P-1:0] rs2_data_w;
    logic [WIDTH_P-1:0] alu_src_a_w;
    logic [WIDTH_P-1:0] alu_src_b_w;
    logic [WIDTH_P-1:0] alu_result_w;
    logic [0:0] alu_zero_w;
    logic [0:0] alu_neg_w;
    logic [0:0] alu_borrow_w;
    logic [0:0] alu_overflow_w;

    assign ex_id_ready_o = ~stall_i & (~ex_mem_valid_o | mem_ex_ready_i);

    // forwarding mux logic
    always_comb begin
        case (id_ex_rs1_fwd_sel_i)
            2'd1: rs1_data_w = ex_mem_fwd_data_i;
            2'd2: rs1_data_w = mem_wb_fwd_data_i;
            default: rs1_data_w = id_ex_rs1_data_i;
        endcase

        case (id_ex_rs2_fwd_sel_i)
            2'd1: rs2_data_w = ex_mem_fwd_data_i;
            2'd2: rs2_data_w = mem_wb_fwd_data_i;
            default: rs2_data_w = id_ex_rs2_data_i;
        endcase
    end

    // alu source mux logic
    always_comb begin
        case (id_ex_alu_src_a_sel_i)
            2'd1: alu_src_a_w = id_ex_pc_i;
            default: alu_src_a_w = rs1_data_w;
        endcase

        case (id_ex_alu_src_b_sel_i)
            2'd1: alu_src_b_w = id_ex_imm_i;
            default: alu_src_b_w = rs2_data_w;
        endcase
    end

    // alu + branch resolve logic
    alu 
    #(
        .WIDTH_P(WIDTH_P)
    ) 
    u_alu (
        .alu_src_a_i(alu_src_a_w),
        .alu_src_b_i(alu_src_b_w),
        .alu_op_i(id_ex_alu_op_i),
        .alu_result_o(alu_result_w),
        .alu_zero_o(alu_zero_w),
        .alu_neg_o(alu_neg_w),
        .alu_borrow_o(alu_borrow_w),
        .alu_overflow_o(alu_overflow_w)
    );

    // branch flag + btb buffer logic 
    logic [0:0] beq_w;
    logic [0:0] bne_w;
    logic [0:0] blt_w;
    logic [0:0] bge_w;
    logic [0:0] bltu_w;
    logic [0:0] bgeu_w;
    logic [0:0] branch_taken_w;
    logic [0:0] pred_taken_w;
    logic [0:0] pred_mismatch_w;
    logic [WIDTH_P-1:0] branch_target_w;
    logic [WIDTH_P-1:0] jalr_target_w;

    assign beq_w = alu_zero_w;
    assign bne_w = ~alu_zero_w;
    assign blt_w = alu_neg_w ^ alu_overflow_w;
    assign bge_w = ~(alu_neg_w ^ alu_overflow_w);
    assign bltu_w = alu_borrow_w;
    assign bgeu_w = ~alu_borrow_w;
    assign branch_target_w = id_ex_pc_i + id_ex_imm_i;
    assign jalr_target_w = {alu_result_w[WIDTH_P-1:1], 1'b0};
    assign pred_taken_w = id_ex_pred_valid_i & id_ex_pred_taken_i;
    assign btb_update_valid_o = id_ex_valid_i & (id_ex_branch_i | id_ex_jal_i | id_ex_jalr_i);
    assign btb_update_pc_o = id_ex_pc_i;
    assign btb_update_taken_o = id_ex_jal_i | id_ex_jalr_i | branch_taken_w;
    assign btb_update_target_o = id_ex_jalr_i ? jalr_target_w : branch_target_w;
    assign pred_mismatch_w = (btb_update_taken_o != pred_taken_w) | (btb_update_taken_o & pred_taken_w & (btb_update_target_o != id_ex_pred_target_i));
    assign ex_if_redirect_valid_o = btb_update_valid_o & pred_mismatch_w;
    assign ex_if_redirect_pc_o = btb_update_taken_o ? btb_update_target_o : id_ex_pc4_i;

    always_comb begin
        case (id_ex_branch_type_i)
            3'b000: branch_taken_w = beq_w;
            3'b001: branch_taken_w = bne_w;
            3'b100: branch_taken_w = blt_w;
            3'b101: branch_taken_w = bge_w;
            3'b110: branch_taken_w = bltu_w;
            3'b111: branch_taken_w = bgeu_w;
            default: branch_taken_w = 1'b0;
        endcase
    end

    // ex mem pipeline block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            ex_mem_valid_o <= 1'b0;
            ex_mem_pc_o <= '0;
            ex_mem_pc4_o <= '0;
            ex_mem_alu_result_o <= '0;
            ex_mem_rs2_data_o <= '0;
            ex_mem_rd_addr_o <= '0;
            ex_mem_reg_write_o <= 1'b0;
            ex_mem_mem_read_o <= 1'b0;
            ex_mem_mem_write_o <= 1'b0;
            ex_mem_funct3_o <= '0;
            ex_mem_instr_illegal_o <= 1'b0;
            ex_mem_wb_sel_o <= '0;
        end else if (flush_i) begin
            ex_mem_valid_o <= 1'b0;
            ex_mem_pc_o <= '0;
            ex_mem_pc4_o <= '0;
            ex_mem_alu_result_o <= '0;
            ex_mem_rs2_data_o <= '0;
            ex_mem_rd_addr_o <= '0;
            ex_mem_reg_write_o <= 1'b0;
            ex_mem_mem_read_o <= 1'b0;
            ex_mem_mem_write_o <= 1'b0;
            ex_mem_funct3_o <= '0;
            ex_mem_instr_illegal_o <= 1'b0;
            ex_mem_wb_sel_o <= '0;
        end else if (ex_id_ready_o) begin
            ex_mem_valid_o <= id_ex_valid_i;
            ex_mem_pc_o <= id_ex_pc_i;
            ex_mem_pc4_o <= id_ex_pc4_i;
            ex_mem_alu_result_o <= alu_result_w;
            ex_mem_rs2_data_o <= rs2_data_w;
            ex_mem_rd_addr_o <= id_ex_rd_addr_i;
            ex_mem_reg_write_o <= id_ex_reg_write_i;
            ex_mem_mem_read_o <= id_ex_mem_read_i;
            ex_mem_mem_write_o <= id_ex_mem_write_i;
            ex_mem_funct3_o <= id_ex_funct3_i;
            ex_mem_instr_illegal_o <= id_ex_instr_illegal_i;
            ex_mem_wb_sel_o <= id_ex_wb_sel_i;
        end
    end
endmodule
