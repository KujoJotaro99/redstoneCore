`timescale 1ns/1ps

module if_stage
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 16,
    parameter PREFETCH_DEPTH_P = 2
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [0:0] stall_i,

    // ex redirect
    input logic [0:0] ex_if_redirect_valid_i,
    input logic [WIDTH_P-1:0] ex_if_redirect_pc_i,

    // mem redirect
    input logic [0:0] mem_if_redirect_valid_i,
    input logic [WIDTH_P-1:0] mem_if_redirect_pc_i,

    // btb update interface
    input logic [0:0] btb_update_valid_i,
    input logic [WIDTH_P-1:0] btb_update_pc_i,
    input logic [0:0] btb_update_taken_i,
    input logic [WIDTH_P-1:0] btb_update_target_i,

    // cache request interface
    output logic [0:0] if_cache_req_valid_o, // valid request
    input logic [0:0] cache_if_req_ready_i, // ready to consume request
    output logic [WIDTH_P-1:0] if_cache_req_addr_o,

    // cache response interface
    input logic [0:0] cache_if_rsp_valid_i, // valid response
    output logic [0:0] if_cache_rsp_ready_o, // ready to consume response
    input logic [WIDTH_P-1:0] cache_if_rsp_instr_i,
    input logic [1:0] cache_if_rsp_resp_i,

    // fetch decode interface
    output logic [0:0] if_id_valid_o,
    input logic [0:0] id_if_ready_i,
    output logic [WIDTH_P-1:0] if_id_instr_o,
    output logic [WIDTH_P-1:0] if_id_pc_o,
    output logic [WIDTH_P-1:0] if_id_pc4_o,
    output logic [0:0] if_id_pred_valid_o,
    output logic [0:0] if_id_pred_taken_o,
    output logic [WIDTH_P-1:0] if_id_pred_target_o,
    output logic [0:0] if_id_instr_access_fault_o,
    output logic [0:0] instr_access_fault_o

);

    localparam FETCH_META_WIDTH_P = 104;
    localparam PREFETCH_WIDTH_P = 136;
    localparam OUTSTANDING_COUNT_W = $clog2(PREFETCH_DEPTH_P + 1);

    logic [WIDTH_P-1:0] pc_curr_q;
    logic [WIDTH_P-1:0] pc4_w;
    logic [WIDTH_P-1:0] pc_next_w;
    logic [0:0] btb_pred_valid_w;
    logic [0:0] btb_pred_taken_w;
    logic [WIDTH_P-1:0] btb_pred_target_w;
    logic [0:0] redirect_valid_w;
    logic [0:0] cache_if_rsp_discard_q;
    logic [OUTSTANDING_COUNT_W-1:0] outstanding_count_q;
    logic [FETCH_META_WIDTH_P-1:0] fetch_meta_fifo_rdata_w;
    logic [0:0] fetch_meta_fifo_valid_w;
    logic [0:0] fetch_meta_fifo_ready_w;
    logic [PREFETCH_WIDTH_P-1:0] prefetch_fifo_rdata_w;
    logic [0:0] prefetch_fifo_valid_w;
    logic [0:0] prefetch_fifo_ready_w;

    assign redirect_valid_w = mem_if_redirect_valid_i | ex_if_redirect_valid_i;

    // btb block
    branch_target_buffer
    #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    )
    u_branch_target_buffer (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .lookup_pc_i(pc_curr_q),
        .pred_valid_o(btb_pred_valid_w),
        .pred_taken_o(btb_pred_taken_w),
        .pred_target_o(btb_pred_target_w),
        .update_valid_i(btb_update_valid_i),
        .update_pc_i(btb_update_pc_i),
        .update_taken_i(btb_update_taken_i),
        .update_target_i(btb_update_target_i)
    );

    // outstanding fetch metadata fifo
    fifo_sync
    #(
        .WIDTH_P(FETCH_META_WIDTH_P),
        .DEPTH_P(PREFETCH_DEPTH_P)
    )
    u_fetch_meta_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i | redirect_valid_w),
        .data_i({6'b0, btb_pred_target_w, btb_pred_taken_w, btb_pred_valid_w, pc4_w, pc_curr_q}),
        .valid_i(if_cache_req_valid_o & cache_if_req_ready_i),
        .ready_i(cache_if_rsp_valid_i & if_cache_rsp_ready_o & ~cache_if_rsp_discard_q),
        .valid_o(fetch_meta_fifo_valid_w),
        .ready_o(fetch_meta_fifo_ready_w),
        .data_o(fetch_meta_fifo_rdata_w)
    );

    // prefetch response fifo
    fifo_sync
    #(
        .WIDTH_P(PREFETCH_WIDTH_P),
        .DEPTH_P(PREFETCH_DEPTH_P)
    )
    u_prefetch_fifo (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .flush_i(flush_i | redirect_valid_w),
        .data_i({5'b0, cache_if_rsp_resp_i != 2'b00, fetch_meta_fifo_rdata_w[97:66], fetch_meta_fifo_rdata_w[65], fetch_meta_fifo_rdata_w[64], fetch_meta_fifo_rdata_w[63:32], fetch_meta_fifo_rdata_w[31:0], cache_if_rsp_instr_i}),
        .valid_i(cache_if_rsp_valid_i & if_cache_rsp_ready_o & ~cache_if_rsp_discard_q),
        .ready_i(~stall_i & ~flush_i & ~redirect_valid_w & prefetch_fifo_valid_w & (~if_id_valid_o | id_if_ready_i)),
        .valid_o(prefetch_fifo_valid_w),
        .ready_o(prefetch_fifo_ready_w),
        .data_o(prefetch_fifo_rdata_w)
    );

    // request issue/response accept block
    // discard drains wrong-path cache responses after redirect because cache request cannot be canceled.
    assign if_cache_req_valid_o = ~stall_i & ~flush_i & ~redirect_valid_w & ~cache_if_rsp_discard_q & fetch_meta_fifo_ready_w;
    assign if_cache_req_addr_o = pc_curr_q;
    assign if_cache_rsp_ready_o = cache_if_rsp_discard_q | (fetch_meta_fifo_valid_w & prefetch_fifo_ready_w);
    assign instr_access_fault_o = cache_if_rsp_valid_i & if_cache_rsp_ready_o & (cache_if_rsp_resp_i != 2'b00);

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            outstanding_count_q <= '0;
            cache_if_rsp_discard_q <= 1'b0;
        end else if (flush_i | redirect_valid_w) begin
            outstanding_count_q <= outstanding_count_q - OUTSTANDING_COUNT_W'(cache_if_rsp_valid_i & if_cache_rsp_ready_o);
            cache_if_rsp_discard_q <= |(outstanding_count_q - OUTSTANDING_COUNT_W'(cache_if_rsp_valid_i & if_cache_rsp_ready_o));
        end else begin
            outstanding_count_q <= outstanding_count_q + OUTSTANDING_COUNT_W'(if_cache_req_valid_o & cache_if_req_ready_i) - OUTSTANDING_COUNT_W'(cache_if_rsp_valid_i & if_cache_rsp_ready_o);
            if (cache_if_rsp_discard_q && cache_if_rsp_valid_i && if_cache_rsp_ready_o && outstanding_count_q == OUTSTANDING_COUNT_W'(1)) begin
                cache_if_rsp_discard_q <= 1'b0;
            end
        end
    end

    // if id pipeline block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            if_id_valid_o <= '0;
            if_id_instr_o <= '0;
            if_id_pc_o <= '0;
            if_id_pc4_o <= '0;
            if_id_pred_valid_o <= 1'b0;
            if_id_pred_taken_o <= 1'b0;
            if_id_pred_target_o <= '0;
            if_id_instr_access_fault_o <= 1'b0;
        end else if (flush_i | redirect_valid_w) begin
            if_id_valid_o <= '0;
            if_id_instr_o <= '0;
            if_id_pc_o <= '0;
            if_id_pc4_o <= '0;
            if_id_pred_valid_o <= 1'b0;
            if_id_pred_taken_o <= 1'b0;
            if_id_pred_target_o <= '0;
            if_id_instr_access_fault_o <= 1'b0;
        end else if (~stall_i & prefetch_fifo_valid_w & (~if_id_valid_o | id_if_ready_i)) begin
            if_id_valid_o <= 1'b1;
            if_id_instr_o <= prefetch_fifo_rdata_w[31:0];
            if_id_pc_o <= prefetch_fifo_rdata_w[63:32];
            if_id_pc4_o <= prefetch_fifo_rdata_w[95:64];
            if_id_pred_valid_o <= prefetch_fifo_rdata_w[96];
            if_id_pred_taken_o <= prefetch_fifo_rdata_w[97];
            if_id_pred_target_o <= prefetch_fifo_rdata_w[129:98];
            if_id_instr_access_fault_o <= prefetch_fifo_rdata_w[130];
        end else if (if_id_valid_o & id_if_ready_i) begin
            if_id_valid_o <= 1'b0;
            if_id_instr_access_fault_o <= 1'b0;
        end
    end

    // pc/pc+4 block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            pc_curr_q <= '0;
        end else if (mem_if_redirect_valid_i) begin
            pc_curr_q <= mem_if_redirect_pc_i;
        end else if (ex_if_redirect_valid_i) begin
            pc_curr_q <= ex_if_redirect_pc_i;
        end else if (if_cache_req_valid_o & cache_if_req_ready_i) begin
            pc_curr_q <= pc_next_w;
        end
    end

    assign pc4_w = pc_curr_q + 32'd4;
    assign pc_next_w = (btb_pred_valid_w & btb_pred_taken_w) ? btb_pred_target_w : pc4_w;

endmodule
