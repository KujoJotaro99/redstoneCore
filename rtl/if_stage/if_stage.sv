`timescale 1ns/1ps

module if_stage 
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 16
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [0:0] stall_i,

    // ex redirect
    input logic [0:0] ex_if_redirect_valid_i,
    input logic [WIDTH_P-1:0] ex_if_redirect_pc_i,

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

    // fetch decode interface
    output logic [0:0] if_id_valid_o,
    input logic [0:0] id_if_ready_i,
    output logic [WIDTH_P-1:0] if_id_instr_o,
    output logic [WIDTH_P-1:0] if_id_pc_o,
    output logic [WIDTH_P-1:0] if_id_pc4_o,
    output logic [0:0] if_id_pred_valid_o,
    output logic [0:0] if_id_pred_taken_o,
    output logic [WIDTH_P-1:0] if_id_pred_target_o

);

    logic [WIDTH_P-1:0] pc_curr_q;
    logic [WIDTH_P-1:0] pc4_w;
    logic [WIDTH_P-1:0] pc_next_w;
    logic [0:0] btb_pred_valid_w;
    logic [0:0] btb_pred_taken_w;
    logic [WIDTH_P-1:0] btb_pred_target_w;
    logic [WIDTH_P-1:0] if_req_pc_q;
    logic [WIDTH_P-1:0] if_req_pc4_q;
    logic [0:0] if_req_pred_valid_q;
    logic [0:0] if_req_pred_taken_q;
    logic [WIDTH_P-1:0] if_req_pred_target_q;
    logic [0:0] if_req_pending_q;

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

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            if_req_pc_q <= '0;
            if_req_pc4_q <= '0;
            if_req_pred_valid_q <= 1'b0;
            if_req_pred_taken_q <= 1'b0;
            if_req_pred_target_q <= '0;
        end else if (flush_i) begin
            if_req_pc_q <= '0;
            if_req_pc4_q <= '0;
            if_req_pred_valid_q <= 1'b0;
            if_req_pred_taken_q <= 1'b0;
            if_req_pred_target_q <= '0;
        end else if (if_cache_req_valid_o & cache_if_req_ready_i) begin
            if_req_pc_q <= pc_curr_q;
            if_req_pc4_q <= pc4_w;
            if_req_pred_valid_q <= btb_pred_valid_w;
            if_req_pred_taken_q <= btb_pred_taken_w;
            if_req_pred_target_q <= btb_pred_target_w;
        end
    end

    // request issue/response accept block
    assign if_cache_req_valid_o = ~stall_i & ~flush_i & (~if_req_pending_q | (cache_if_rsp_valid_i & if_cache_rsp_ready_o));
    assign if_cache_rsp_ready_o = ~stall_i & ~flush_i & if_req_pending_q & (~if_id_valid_o | id_if_ready_i);
    assign if_cache_req_addr_o = pc_curr_q;

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            if_req_pending_q <= 1'b0;
        end else if (flush_i) begin
            if_req_pending_q <= 1'b0;
        end else begin
            if ((if_cache_req_valid_o & cache_if_req_ready_i) && !(cache_if_rsp_valid_i & if_cache_rsp_ready_o)) begin
                if_req_pending_q <= 1'b1;
            end else if (!(if_cache_req_valid_o & cache_if_req_ready_i) && (cache_if_rsp_valid_i & if_cache_rsp_ready_o)) begin
                if_req_pending_q <= 1'b0;
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
        end else if (flush_i) begin
            if_id_valid_o <= '0;
            if_id_instr_o <= '0;
            if_id_pc_o <= '0;
            if_id_pc4_o <= '0;
            if_id_pred_valid_o <= 1'b0;
            if_id_pred_taken_o <= 1'b0;
            if_id_pred_target_o <= '0;
        end else if (cache_if_rsp_valid_i & if_cache_rsp_ready_o) begin
            if_id_valid_o <= 1'b1;
            if_id_instr_o <= cache_if_rsp_instr_i;
            if_id_pc_o <= if_req_pc_q;
            if_id_pc4_o <= if_req_pc4_q;
            if_id_pred_valid_o <= if_req_pred_valid_q;
            if_id_pred_taken_o <= if_req_pred_taken_q;
            if_id_pred_target_o <= if_req_pred_target_q;
        end else if (if_id_valid_o & id_if_ready_i) begin
            if_id_valid_o <= 1'b0;
        end
    end

    // pc/pc+4 block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            pc_curr_q <= '0;
        end else if (ex_if_redirect_valid_i) begin
            pc_curr_q <= ex_if_redirect_pc_i;
        end else if (if_cache_req_valid_o & cache_if_req_ready_i) begin
            pc_curr_q <= pc_next_w;
        end
    end

    assign pc4_w = pc_curr_q + {{(WIDTH_P-3){1'b0}}, 3'd4};
    assign pc_next_w = (btb_pred_valid_w & btb_pred_taken_w) ? btb_pred_target_w : pc4_w;

endmodule
