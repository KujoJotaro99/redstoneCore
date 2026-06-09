`timescale 1ns/1ps

module top
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 32,
    parameter BTB_DEPTH_P = 16,
    parameter CACHE_SIZE_BYTES_P = 4096,
    parameter CACHE_LINE_SIZE_BYTES_P = 16,
    parameter CACHE_WAYS_P = 4,
    parameter RAM_ADDR_WIDTH_P = 16,
    parameter logic [RAM_ADDR_WIDTH_P-1:0] DMEM_RAM_BASE_P = 16'h1000
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [0:0] stall_i,

    // debug interface
    output logic [WIDTH_P-1:0] debug_pc_o,
    output logic [0:0] debug_valid_o,
    output logic [0:0] debug_instr_illegal_o,
    output logic [0:0] instr_access_fault_o,
    output logic [0:0] mem_access_fault_o
);

    localparam STRB_WIDTH_P = WIDTH_P / 8;

    logic [0:0] if_id_valid_w;
    logic [0:0] id_if_ready_w;
    logic [WIDTH_P-1:0] if_id_instr_w;
    logic [WIDTH_P-1:0] if_id_pc_w;
    logic [WIDTH_P-1:0] if_id_pc4_w;
    logic [0:0] if_id_pred_valid_w;
    logic [0:0] if_id_pred_taken_w;
    logic [WIDTH_P-1:0] if_id_pred_target_w;
    logic [0:0] if_id_instr_access_fault_w;

    logic [0:0] id_ex_valid_w;
    logic [0:0] ex_id_ready_w;
    logic [WIDTH_P-1:0] id_ex_instr_w;
    logic [WIDTH_P-1:0] id_ex_pc_w;
    logic [WIDTH_P-1:0] id_ex_pc4_w;
    logic [WIDTH_P-1:0] id_ex_rs1_data_w;
    logic [WIDTH_P-1:0] id_ex_rs2_data_w;
    logic [WIDTH_P-1:0] id_ex_imm_w;
    logic [$clog2(DEPTH_P)-1:0] id_ex_rd_addr_w;
    logic [3:0] id_ex_alu_op_w;
    logic [1:0] id_ex_alu_src_a_sel_w;
    logic [1:0] id_ex_alu_src_b_sel_w;
    logic [0:0] id_ex_reg_write_w;
    logic [0:0] id_ex_mem_read_w;
    logic [0:0] id_ex_mem_write_w;
    logic [2:0] id_ex_funct3_w;
    logic [0:0] id_ex_branch_w;
    logic [0:0] id_ex_jal_w;
    logic [0:0] id_ex_jalr_w;
    logic [2:0] id_ex_branch_type_w;
    logic [0:0] id_ex_pred_valid_w;
    logic [0:0] id_ex_pred_taken_w;
    logic [WIDTH_P-1:0] id_ex_pred_target_w;
    logic [0:0] id_ex_instr_illegal_w;
    logic [0:0] id_ex_instr_access_fault_w;
    logic [1:0] id_ex_rs1_fwd_sel_w;
    logic [1:0] id_ex_rs2_fwd_sel_w;
    logic [1:0] id_ex_wb_sel_w;

    logic [0:0] ex_if_redirect_valid_w;
    logic [WIDTH_P-1:0] ex_if_redirect_pc_w;
    logic [0:0] ex_if_redirect_valid_gated_w;
    logic [0:0] btb_update_valid_w;
    logic [WIDTH_P-1:0] btb_update_pc_w;
    logic [0:0] btb_update_taken_w;
    logic [WIDTH_P-1:0] btb_update_target_w;
    logic [0:0] btb_update_valid_gated_w;
    logic [WIDTH_P-1:0] ex_mem_fwd_data_w;
    logic [WIDTH_P-1:0] mem_wb_fwd_data_w;

    logic [0:0] ex_mem_valid_w;
    logic [0:0] mem_ex_ready_w;
    logic [WIDTH_P-1:0] ex_mem_instr_w;
    logic [WIDTH_P-1:0] ex_mem_pc_w;
    logic [WIDTH_P-1:0] ex_mem_pc4_w;
    logic [WIDTH_P-1:0] ex_mem_alu_result_w;
    logic [WIDTH_P-1:0] ex_mem_rs2_data_w;
    logic [$clog2(DEPTH_P)-1:0] ex_mem_rd_addr_w;
    logic [0:0] ex_mem_reg_write_w;
    logic [0:0] ex_mem_mem_read_w;
    logic [0:0] ex_mem_mem_write_w;
    logic [2:0] ex_mem_funct3_w;
    logic [0:0] ex_mem_instr_illegal_w;
    logic [0:0] ex_mem_instr_access_fault_w;
    logic [1:0] ex_mem_wb_sel_w;

    logic [0:0] mem_wb_valid_w;
    logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_w;
    logic [0:0] mem_wb_reg_write_w;
    logic [$clog2(DEPTH_P)-1:0] wb_id_rd_addr_w;
    logic [WIDTH_P-1:0] wb_id_rd_data_w;
    logic [0:0] wb_id_rd_we_w;

    logic [0:0] if_cache_req_valid_w;
    logic [0:0] cache_if_req_ready_w;
    logic [WIDTH_P-1:0] if_cache_req_addr_w;
    logic [0:0] cache_if_rsp_valid_w;
    logic [0:0] if_cache_rsp_ready_w;
    logic [WIDTH_P-1:0] cache_if_rsp_instr_w;
    logic [1:0] cache_if_rsp_resp_w;

    logic [0:0] mem_cache_req_valid_w;
    logic [0:0] cache_mem_req_ready_w;
    logic [0:0] mem_cache_req_write_w;
    logic [WIDTH_P-1:0] mem_cache_req_addr_w;
    logic [WIDTH_P-1:0] mem_cache_req_wdata_w;
    logic [STRB_WIDTH_P-1:0] mem_cache_req_wstrb_w;
    logic [0:0] cache_mem_rsp_valid_w;
    logic [0:0] mem_cache_rsp_ready_w;
    logic [WIDTH_P-1:0] cache_mem_rsp_rdata_w;
    logic [1:0] cache_mem_rsp_resp_w;

    logic [0:0] icache_axil_req_valid_w;
    logic [0:0] axil_icache_req_ready_w;
    logic [0:0] icache_axil_req_write_w;
    logic [WIDTH_P-1:0] icache_axil_req_addr_w;
    logic [WIDTH_P-1:0] icache_axil_req_wdata_w;
    logic [STRB_WIDTH_P-1:0] icache_axil_req_wstrb_w;
    logic [0:0] axil_icache_rsp_valid_w;
    logic [0:0] icache_axil_rsp_ready_w;
    logic [WIDTH_P-1:0] axil_icache_rsp_rdata_w;
    logic [1:0] axil_icache_rsp_resp_w;

    logic [0:0] dcache_axil_req_valid_w;
    logic [0:0] axil_dcache_req_ready_w;
    logic [0:0] dcache_axil_req_write_w;
    logic [WIDTH_P-1:0] dcache_axil_req_addr_w;
    logic [WIDTH_P-1:0] dcache_axil_req_wdata_w;
    logic [STRB_WIDTH_P-1:0] dcache_axil_req_wstrb_w;
    logic [0:0] axil_dcache_rsp_valid_w;
    logic [0:0] dcache_axil_rsp_ready_w;
    logic [WIDTH_P-1:0] axil_dcache_rsp_rdata_w;
    logic [1:0] axil_dcache_rsp_resp_w;

    logic [RAM_ADDR_WIDTH_P-1:0] icache_axil_req_addr_mapped_w;
    logic [RAM_ADDR_WIDTH_P-1:0] dcache_axil_req_addr_mapped_w;

    logic [0:0] i_axil_awvalid_w;
    logic [0:0] i_axil_awready_w;
    logic [RAM_ADDR_WIDTH_P-1:0] i_axil_awaddr_w;
    logic [2:0] i_axil_awprot_w;
    logic [0:0] i_axil_wvalid_w;
    logic [0:0] i_axil_wready_w;
    logic [WIDTH_P-1:0] i_axil_wdata_w;
    logic [STRB_WIDTH_P-1:0] i_axil_wstrb_w;
    logic [0:0] i_axil_bvalid_w;
    logic [0:0] i_axil_bready_w;
    logic [1:0] i_axil_bresp_w;
    logic [0:0] i_axil_arvalid_w;
    logic [0:0] i_axil_arready_w;
    logic [RAM_ADDR_WIDTH_P-1:0] i_axil_araddr_w;
    logic [2:0] i_axil_arprot_w;
    logic [0:0] i_axil_rvalid_w;
    logic [0:0] i_axil_rready_w;
    logic [WIDTH_P-1:0] i_axil_rdata_w;
    logic [1:0] i_axil_rresp_w;

    logic [0:0] d_axil_awvalid_w;
    logic [0:0] d_axil_awready_w;
    logic [RAM_ADDR_WIDTH_P-1:0] d_axil_awaddr_w;
    logic [2:0] d_axil_awprot_w;
    logic [0:0] d_axil_wvalid_w;
    logic [0:0] d_axil_wready_w;
    logic [WIDTH_P-1:0] d_axil_wdata_w;
    logic [STRB_WIDTH_P-1:0] d_axil_wstrb_w;
    logic [0:0] d_axil_bvalid_w;
    logic [0:0] d_axil_bready_w;
    logic [1:0] d_axil_bresp_w;
    logic [0:0] d_axil_arvalid_w;
    logic [0:0] d_axil_arready_w;
    logic [RAM_ADDR_WIDTH_P-1:0] d_axil_araddr_w;
    logic [2:0] d_axil_arprot_w;
    logic [0:0] d_axil_rvalid_w;
    logic [0:0] d_axil_rready_w;
    logic [WIDTH_P-1:0] d_axil_rdata_w;
    logic [1:0] d_axil_rresp_w;

    assign ex_if_redirect_valid_gated_w = ex_if_redirect_valid_w & ~flush_i;
    assign btb_update_valid_gated_w = btb_update_valid_w & ~flush_i;
    assign icache_axil_req_addr_mapped_w = icache_axil_req_addr_w[RAM_ADDR_WIDTH_P-1:0];
    assign dcache_axil_req_addr_mapped_w = (dcache_axil_req_addr_w[31:28] == 4'h1) ? (dcache_axil_req_addr_w[RAM_ADDR_WIDTH_P-1:0] + DMEM_RAM_BASE_P) : dcache_axil_req_addr_w[RAM_ADDR_WIDTH_P-1:0];

    if_stage
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(BTB_DEPTH_P)
    )
    u_if_stage (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i),
        .stall_i(stall_i),
        .ex_if_redirect_valid_i(ex_if_redirect_valid_gated_w),
        .ex_if_redirect_pc_i(ex_if_redirect_pc_w),
        .mem_if_redirect_valid_i(1'b0),
        .mem_if_redirect_pc_i('0),
        .btb_update_valid_i(btb_update_valid_gated_w),
        .btb_update_pc_i(btb_update_pc_w),
        .btb_update_taken_i(btb_update_taken_w),
        .btb_update_target_i(btb_update_target_w),
        .if_cache_req_valid_o(if_cache_req_valid_w),
        .cache_if_req_ready_i(cache_if_req_ready_w),
        .if_cache_req_addr_o(if_cache_req_addr_w),
        .cache_if_rsp_valid_i(cache_if_rsp_valid_w),
        .if_cache_rsp_ready_o(if_cache_rsp_ready_w),
        .cache_if_rsp_instr_i(cache_if_rsp_instr_w),
        .cache_if_rsp_resp_i(cache_if_rsp_resp_w),
        .if_id_valid_o(if_id_valid_w),
        .id_if_ready_i(id_if_ready_w),
        .if_id_instr_o(if_id_instr_w),
        .if_id_pc_o(if_id_pc_w),
        .if_id_pc4_o(if_id_pc4_w),
        .if_id_pred_valid_o(if_id_pred_valid_w),
        .if_id_pred_taken_o(if_id_pred_taken_w),
        .if_id_pred_target_o(if_id_pred_target_w),
        .if_id_instr_access_fault_o(if_id_instr_access_fault_w),
        .instr_access_fault_o(instr_access_fault_o)
    );

    id_stage
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    )
    u_id_stage (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i | ex_if_redirect_valid_gated_w),
        .stall_i(stall_i),
        .if_id_valid_i(if_id_valid_w),
        .id_if_ready_o(id_if_ready_w),
        .if_id_instr_i(if_id_instr_w),
        .if_id_pc_i(if_id_pc_w),
        .if_id_pc4_i(if_id_pc4_w),
        .if_id_pred_valid_i(if_id_pred_valid_w),
        .if_id_pred_taken_i(if_id_pred_taken_w),
        .if_id_pred_target_i(if_id_pred_target_w),
        .if_id_instr_access_fault_i(if_id_instr_access_fault_w),
        .ex_mem_valid_i(ex_mem_valid_w),
        .ex_mem_rd_addr_i(ex_mem_rd_addr_w),
        .ex_mem_reg_write_i(ex_mem_reg_write_w),
        .ex_mem_wb_sel_i(ex_mem_wb_sel_w),
        .mem_wb_valid_i(mem_wb_valid_w),
        .mem_wb_rd_addr_i(mem_wb_rd_addr_w),
        .mem_wb_reg_write_i(mem_wb_reg_write_w),
        .id_ex_valid_o(id_ex_valid_w),
        .ex_id_ready_i(ex_id_ready_w),
        .id_ex_instr_o(id_ex_instr_w),
        .id_ex_pc_o(id_ex_pc_w),
        .id_ex_pc4_o(id_ex_pc4_w),
        .id_ex_rs1_data_o(id_ex_rs1_data_w),
        .id_ex_rs2_data_o(id_ex_rs2_data_w),
        .id_ex_imm_o(id_ex_imm_w),
        .id_ex_rd_addr_o(id_ex_rd_addr_w),
        .id_ex_alu_op_o(id_ex_alu_op_w),
        .id_ex_alu_src_a_sel_o(id_ex_alu_src_a_sel_w),
        .id_ex_alu_src_b_sel_o(id_ex_alu_src_b_sel_w),
        .id_ex_reg_write_o(id_ex_reg_write_w),
        .id_ex_mem_read_o(id_ex_mem_read_w),
        .id_ex_mem_write_o(id_ex_mem_write_w),
        .id_ex_funct3_o(id_ex_funct3_w),
        .id_ex_branch_o(id_ex_branch_w),
        .id_ex_jal_o(id_ex_jal_w),
        .id_ex_jalr_o(id_ex_jalr_w),
        .id_ex_branch_type_o(id_ex_branch_type_w),
        .id_ex_pred_valid_o(id_ex_pred_valid_w),
        .id_ex_pred_taken_o(id_ex_pred_taken_w),
        .id_ex_pred_target_o(id_ex_pred_target_w),
        .id_ex_instr_illegal_o(id_ex_instr_illegal_w),
        .id_ex_instr_access_fault_o(id_ex_instr_access_fault_w),
        .id_ex_rs1_fwd_sel_o(id_ex_rs1_fwd_sel_w),
        .id_ex_rs2_fwd_sel_o(id_ex_rs2_fwd_sel_w),
        .id_ex_wb_sel_o(id_ex_wb_sel_w),
        .wb_id_rd_addr_i(wb_id_rd_addr_w),
        .wb_id_rd_data_i(wb_id_rd_data_w),
        .wb_id_rd_we_i(wb_id_rd_we_w)
    );

    ex_stage
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    )
    u_ex_stage (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i),
        .stall_i(stall_i),
        .ex_if_redirect_valid_o(ex_if_redirect_valid_w),
        .ex_if_redirect_pc_o(ex_if_redirect_pc_w),
        .btb_update_valid_o(btb_update_valid_w),
        .btb_update_pc_o(btb_update_pc_w),
        .btb_update_taken_o(btb_update_taken_w),
        .btb_update_target_o(btb_update_target_w),
        .id_ex_valid_i(id_ex_valid_w),
        .ex_id_ready_o(ex_id_ready_w),
        .id_ex_instr_i(id_ex_instr_w),
        .id_ex_pc_i(id_ex_pc_w),
        .id_ex_pc4_i(id_ex_pc4_w),
        .id_ex_rs1_data_i(id_ex_rs1_data_w),
        .id_ex_rs2_data_i(id_ex_rs2_data_w),
        .id_ex_imm_i(id_ex_imm_w),
        .id_ex_rd_addr_i(id_ex_rd_addr_w),
        .id_ex_alu_op_i(id_ex_alu_op_w),
        .id_ex_alu_src_a_sel_i(id_ex_alu_src_a_sel_w),
        .id_ex_alu_src_b_sel_i(id_ex_alu_src_b_sel_w),
        .id_ex_reg_write_i(id_ex_reg_write_w),
        .id_ex_mem_read_i(id_ex_mem_read_w),
        .id_ex_mem_write_i(id_ex_mem_write_w),
        .id_ex_funct3_i(id_ex_funct3_w),
        .id_ex_branch_i(id_ex_branch_w),
        .id_ex_jal_i(id_ex_jal_w),
        .id_ex_jalr_i(id_ex_jalr_w),
        .id_ex_branch_type_i(id_ex_branch_type_w),
        .id_ex_pred_valid_i(id_ex_pred_valid_w),
        .id_ex_pred_taken_i(id_ex_pred_taken_w),
        .id_ex_pred_target_i(id_ex_pred_target_w),
        .id_ex_instr_illegal_i(id_ex_instr_illegal_w),
        .id_ex_instr_access_fault_i(id_ex_instr_access_fault_w),
        .id_ex_rs1_fwd_sel_i(id_ex_rs1_fwd_sel_w),
        .id_ex_rs2_fwd_sel_i(id_ex_rs2_fwd_sel_w),
        .id_ex_wb_sel_i(id_ex_wb_sel_w),
        .ex_mem_fwd_data_i(ex_mem_fwd_data_w),
        .mem_wb_fwd_data_i(mem_wb_fwd_data_w),
        .ex_mem_fwd_data_o(ex_mem_fwd_data_w),
        .mem_ex_ready_i(mem_ex_ready_w),
        .ex_mem_valid_o(ex_mem_valid_w),
        .ex_mem_instr_o(ex_mem_instr_w),
        .ex_mem_pc_o(ex_mem_pc_w),
        .ex_mem_pc4_o(ex_mem_pc4_w),
        .ex_mem_alu_result_o(ex_mem_alu_result_w),
        .ex_mem_rs2_data_o(ex_mem_rs2_data_w),
        .ex_mem_rd_addr_o(ex_mem_rd_addr_w),
        .ex_mem_reg_write_o(ex_mem_reg_write_w),
        .ex_mem_mem_read_o(ex_mem_mem_read_w),
        .ex_mem_mem_write_o(ex_mem_mem_write_w),
        .ex_mem_funct3_o(ex_mem_funct3_w),
        .ex_mem_instr_illegal_o(ex_mem_instr_illegal_w),
        .ex_mem_instr_access_fault_o(ex_mem_instr_access_fault_w),
        .ex_mem_wb_sel_o(ex_mem_wb_sel_w)
    );

    mem_stage
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    )
    u_mem_stage (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i),
        .stall_i(stall_i),
        .ex_mem_valid_i(ex_mem_valid_w),
        .mem_ex_ready_o(mem_ex_ready_w),
        .ex_mem_instr_i(ex_mem_instr_w),
        .ex_mem_pc_i(ex_mem_pc_w),
        .ex_mem_pc4_i(ex_mem_pc4_w),
        .ex_mem_alu_result_i(ex_mem_alu_result_w),
        .ex_mem_rs2_data_i(ex_mem_rs2_data_w),
        .ex_mem_rd_addr_i(ex_mem_rd_addr_w),
        .ex_mem_reg_write_i(ex_mem_reg_write_w),
        .ex_mem_mem_read_i(ex_mem_mem_read_w),
        .ex_mem_mem_write_i(ex_mem_mem_write_w),
        .ex_mem_funct3_i(ex_mem_funct3_w),
        .ex_mem_instr_illegal_i(ex_mem_instr_illegal_w),
        .ex_mem_instr_access_fault_i(ex_mem_instr_access_fault_w),
        .ex_mem_wb_sel_i(ex_mem_wb_sel_w),
        .mem_cache_req_valid_o(mem_cache_req_valid_w),
        .cache_mem_req_ready_i(cache_mem_req_ready_w),
        .mem_cache_req_write_o(mem_cache_req_write_w),
        .mem_cache_req_addr_o(mem_cache_req_addr_w),
        .mem_cache_req_wdata_o(mem_cache_req_wdata_w),
        .mem_cache_req_wstrb_o(mem_cache_req_wstrb_w),
        .cache_mem_rsp_valid_i(cache_mem_rsp_valid_w),
        .mem_cache_rsp_ready_o(mem_cache_rsp_ready_w),
        .cache_mem_rsp_rdata_i(cache_mem_rsp_rdata_w),
        .cache_mem_rsp_resp_i(cache_mem_rsp_resp_w),
        .mem_wb_valid_o(mem_wb_valid_w),
        .mem_wb_rd_addr_o(mem_wb_rd_addr_w),
        .mem_wb_reg_write_o(mem_wb_reg_write_w),
        .debug_pc_o(debug_pc_o),
        .wb_id_rd_addr_o(wb_id_rd_addr_w),
        .wb_id_rd_data_o(wb_id_rd_data_w),
        .wb_id_rd_we_o(wb_id_rd_we_w),
        .mem_wb_fwd_data_o(mem_wb_fwd_data_w),
        .debug_valid_o(debug_valid_o),
        .debug_instr_illegal_o(debug_instr_illegal_o),
        .mem_access_fault_o(mem_access_fault_o)
    );

    sa4_cache
    #(
        .WIDTH_P(WIDTH_P),
        .CACHE_SIZE_BYTES_P(CACHE_SIZE_BYTES_P),
        .LINE_SIZE_BYTES_P(CACHE_LINE_SIZE_BYTES_P),
        .WAYS_P(CACHE_WAYS_P)
    )
    u_icache (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .module_cache_req_valid_i(if_cache_req_valid_w),
        .cache_module_req_ready_o(cache_if_req_ready_w),
        .module_cache_req_write_i(1'b0),
        .module_cache_req_addr_i(if_cache_req_addr_w),
        .module_cache_req_wdata_i('0),
        .module_cache_req_wstrb_i('0),
        .cache_module_rsp_valid_o(cache_if_rsp_valid_w),
        .module_cache_rsp_ready_i(if_cache_rsp_ready_w),
        .cache_module_rsp_rdata_o(cache_if_rsp_instr_w),
        .cache_module_rsp_resp_o(cache_if_rsp_resp_w),
        .cache_mem_req_valid_o(icache_axil_req_valid_w),
        .mem_cache_req_ready_i(axil_icache_req_ready_w),
        .cache_mem_req_write_o(icache_axil_req_write_w),
        .cache_mem_req_addr_o(icache_axil_req_addr_w),
        .cache_mem_req_wdata_o(icache_axil_req_wdata_w),
        .cache_mem_req_wstrb_o(icache_axil_req_wstrb_w),
        .mem_cache_rsp_valid_i(axil_icache_rsp_valid_w),
        .cache_mem_rsp_ready_o(icache_axil_rsp_ready_w),
        .mem_cache_rsp_rdata_i(axil_icache_rsp_rdata_w),
        .mem_cache_rsp_resp_i(axil_icache_rsp_resp_w)
    );

    sa4_cache
    #(
        .WIDTH_P(WIDTH_P),
        .CACHE_SIZE_BYTES_P(CACHE_SIZE_BYTES_P),
        .LINE_SIZE_BYTES_P(CACHE_LINE_SIZE_BYTES_P),
        .WAYS_P(CACHE_WAYS_P)
    )
    u_dcache (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .module_cache_req_valid_i(mem_cache_req_valid_w),
        .cache_module_req_ready_o(cache_mem_req_ready_w),
        .module_cache_req_write_i(mem_cache_req_write_w),
        .module_cache_req_addr_i(mem_cache_req_addr_w),
        .module_cache_req_wdata_i(mem_cache_req_wdata_w),
        .module_cache_req_wstrb_i(mem_cache_req_wstrb_w),
        .cache_module_rsp_valid_o(cache_mem_rsp_valid_w),
        .module_cache_rsp_ready_i(mem_cache_rsp_ready_w),
        .cache_module_rsp_rdata_o(cache_mem_rsp_rdata_w),
        .cache_module_rsp_resp_o(cache_mem_rsp_resp_w),
        .cache_mem_req_valid_o(dcache_axil_req_valid_w),
        .mem_cache_req_ready_i(axil_dcache_req_ready_w),
        .cache_mem_req_write_o(dcache_axil_req_write_w),
        .cache_mem_req_addr_o(dcache_axil_req_addr_w),
        .cache_mem_req_wdata_o(dcache_axil_req_wdata_w),
        .cache_mem_req_wstrb_o(dcache_axil_req_wstrb_w),
        .mem_cache_rsp_valid_i(axil_dcache_rsp_valid_w),
        .cache_mem_rsp_ready_o(dcache_axil_rsp_ready_w),
        .mem_cache_rsp_rdata_i(axil_dcache_rsp_rdata_w),
        .mem_cache_rsp_resp_i(axil_dcache_rsp_resp_w)
    );

    axil_master
    #(
        .ADDR_WIDTH_P(RAM_ADDR_WIDTH_P),
        .DATA_WIDTH_P(WIDTH_P)
    )
    u_i_axil_master (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .cache_mem_req_valid_i(icache_axil_req_valid_w),
        .mem_cache_req_ready_o(axil_icache_req_ready_w),
        .cache_mem_req_write_i(icache_axil_req_write_w),
        .cache_mem_req_addr_i(icache_axil_req_addr_mapped_w),
        .cache_mem_req_wdata_i(icache_axil_req_wdata_w),
        .cache_mem_req_wstrb_i(icache_axil_req_wstrb_w),
        .mem_cache_rsp_valid_o(axil_icache_rsp_valid_w),
        .cache_mem_rsp_ready_i(icache_axil_rsp_ready_w),
        .mem_cache_rsp_rdata_o(axil_icache_rsp_rdata_w),
        .mem_cache_rsp_resp_o(axil_icache_rsp_resp_w),
        .m_axil_awvalid(i_axil_awvalid_w),
        .m_axil_awready(i_axil_awready_w),
        .m_axil_awaddr(i_axil_awaddr_w),
        .m_axil_awprot(i_axil_awprot_w),
        .m_axil_wvalid(i_axil_wvalid_w),
        .m_axil_wready(i_axil_wready_w),
        .m_axil_wdata(i_axil_wdata_w),
        .m_axil_wstrb(i_axil_wstrb_w),
        .m_axil_bvalid(i_axil_bvalid_w),
        .m_axil_bready(i_axil_bready_w),
        .m_axil_bresp(i_axil_bresp_w),
        .m_axil_arvalid(i_axil_arvalid_w),
        .m_axil_arready(i_axil_arready_w),
        .m_axil_araddr(i_axil_araddr_w),
        .m_axil_arprot(i_axil_arprot_w),
        .m_axil_rvalid(i_axil_rvalid_w),
        .m_axil_rready(i_axil_rready_w),
        .m_axil_rdata(i_axil_rdata_w),
        .m_axil_rresp(i_axil_rresp_w)
    );

    axil_master
    #(
        .ADDR_WIDTH_P(RAM_ADDR_WIDTH_P),
        .DATA_WIDTH_P(WIDTH_P)
    )
    u_d_axil_master (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .cache_mem_req_valid_i(dcache_axil_req_valid_w),
        .mem_cache_req_ready_o(axil_dcache_req_ready_w),
        .cache_mem_req_write_i(dcache_axil_req_write_w),
        .cache_mem_req_addr_i(dcache_axil_req_addr_mapped_w),
        .cache_mem_req_wdata_i(dcache_axil_req_wdata_w),
        .cache_mem_req_wstrb_i(dcache_axil_req_wstrb_w),
        .mem_cache_rsp_valid_o(axil_dcache_rsp_valid_w),
        .cache_mem_rsp_ready_i(dcache_axil_rsp_ready_w),
        .mem_cache_rsp_rdata_o(axil_dcache_rsp_rdata_w),
        .mem_cache_rsp_resp_o(axil_dcache_rsp_resp_w),
        .m_axil_awvalid(d_axil_awvalid_w),
        .m_axil_awready(d_axil_awready_w),
        .m_axil_awaddr(d_axil_awaddr_w),
        .m_axil_awprot(d_axil_awprot_w),
        .m_axil_wvalid(d_axil_wvalid_w),
        .m_axil_wready(d_axil_wready_w),
        .m_axil_wdata(d_axil_wdata_w),
        .m_axil_wstrb(d_axil_wstrb_w),
        .m_axil_bvalid(d_axil_bvalid_w),
        .m_axil_bready(d_axil_bready_w),
        .m_axil_bresp(d_axil_bresp_w),
        .m_axil_arvalid(d_axil_arvalid_w),
        .m_axil_arready(d_axil_arready_w),
        .m_axil_araddr(d_axil_araddr_w),
        .m_axil_arprot(d_axil_arprot_w),
        .m_axil_rvalid(d_axil_rvalid_w),
        .m_axil_rready(d_axil_rready_w),
        .m_axil_rdata(d_axil_rdata_w),
        .m_axil_rresp(d_axil_rresp_w)
    );

    axil_dp_ram
    #(
        .DATA_WIDTH(WIDTH_P),
        .ADDR_WIDTH(RAM_ADDR_WIDTH_P),
        .STRB_WIDTH(STRB_WIDTH_P),
        .PIPELINE_OUTPUT(0)
    )
    u_axil_dp_ram (
        .a_clk(clk_i),
        .a_rst(~rstn_i),
        .b_clk(clk_i),
        .b_rst(~rstn_i),
        .s_axil_a_awaddr(i_axil_awaddr_w),
        .s_axil_a_awprot(i_axil_awprot_w),
        .s_axil_a_awvalid(i_axil_awvalid_w),
        .s_axil_a_awready(i_axil_awready_w),
        .s_axil_a_wdata(i_axil_wdata_w),
        .s_axil_a_wstrb(i_axil_wstrb_w),
        .s_axil_a_wvalid(i_axil_wvalid_w),
        .s_axil_a_wready(i_axil_wready_w),
        .s_axil_a_bresp(i_axil_bresp_w),
        .s_axil_a_bvalid(i_axil_bvalid_w),
        .s_axil_a_bready(i_axil_bready_w),
        .s_axil_a_araddr(i_axil_araddr_w),
        .s_axil_a_arprot(i_axil_arprot_w),
        .s_axil_a_arvalid(i_axil_arvalid_w),
        .s_axil_a_arready(i_axil_arready_w),
        .s_axil_a_rdata(i_axil_rdata_w),
        .s_axil_a_rresp(i_axil_rresp_w),
        .s_axil_a_rvalid(i_axil_rvalid_w),
        .s_axil_a_rready(i_axil_rready_w),
        .s_axil_b_awaddr(d_axil_awaddr_w),
        .s_axil_b_awprot(d_axil_awprot_w),
        .s_axil_b_awvalid(d_axil_awvalid_w),
        .s_axil_b_awready(d_axil_awready_w),
        .s_axil_b_wdata(d_axil_wdata_w),
        .s_axil_b_wstrb(d_axil_wstrb_w),
        .s_axil_b_wvalid(d_axil_wvalid_w),
        .s_axil_b_wready(d_axil_wready_w),
        .s_axil_b_bresp(d_axil_bresp_w),
        .s_axil_b_bvalid(d_axil_bvalid_w),
        .s_axil_b_bready(d_axil_bready_w),
        .s_axil_b_araddr(d_axil_araddr_w),
        .s_axil_b_arprot(d_axil_arprot_w),
        .s_axil_b_arvalid(d_axil_arvalid_w),
        .s_axil_b_arready(d_axil_arready_w),
        .s_axil_b_rdata(d_axil_rdata_w),
        .s_axil_b_rresp(d_axil_rresp_w),
        .s_axil_b_rvalid(d_axil_rvalid_w),
        .s_axil_b_rready(d_axil_rready_w)
    );

endmodule
