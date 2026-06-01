`timescale 1ns/1ps

module branch_target_buffer
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 16
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,

    // lookup interface
    input logic [WIDTH_P-1:0] lookup_pc_i,
    output logic [0:0] pred_valid_o,
    output logic [0:0] pred_taken_o,
    output logic [WIDTH_P-1:0] pred_target_o,

    // update interface
    input logic [0:0] update_valid_i,
    input logic [WIDTH_P-1:0] update_pc_i,
    input logic [0:0] update_taken_i,
    input logic [WIDTH_P-1:0] update_target_i
);

    localparam INDEX_W = $clog2(DEPTH_P);
    localparam TAG_W = WIDTH_P - INDEX_W - 2;

    // 00 stronngly not taken
    // 01 weakly not taken
    // 10 weakly taken
    // 11 strongly taken

    logic [0:0] valid_q [DEPTH_P-1:0];
    logic [TAG_W-1:0] tag_q [DEPTH_P-1:0];
    logic [1:0] state_q [DEPTH_P-1:0];
    logic [WIDTH_P-1:0] target_q [DEPTH_P-1:0];
    logic [INDEX_W-1:0] lookup_index_w;
    logic [TAG_W-1:0] lookup_tag_w;
    logic [INDEX_W-1:0] update_index_w;
    logic [TAG_W-1:0] update_tag_w;
    logic [1:0] lookup_state_w;
    integer i;

    assign lookup_index_w = INDEX_W'(lookup_pc_i[INDEX_W+1:0] >> 2);
    assign lookup_tag_w = lookup_pc_i[WIDTH_P-1:INDEX_W+2];
    assign update_index_w = INDEX_W'(update_pc_i[INDEX_W+1:0] >> 2);
    assign update_tag_w = update_pc_i[WIDTH_P-1:INDEX_W+2];
    // to fix dumb icarus unpacked array selector warning
    assign lookup_state_w = state_q[lookup_index_w];

    // lookup block
    always_comb begin
        pred_valid_o = valid_q[lookup_index_w] & (tag_q[lookup_index_w] == lookup_tag_w); // entry exists and has been updated before
        pred_taken_o = pred_valid_o & (lookup_state_w >= 2'b10);
        pred_target_o = target_q[lookup_index_w];
    end

    // update block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            for (i = 0; i < DEPTH_P; i = i + 1) begin
                valid_q[i] <= 1'b0;
                tag_q[i] <= '0;
                state_q[i] <= 2'b01;
                target_q[i] <= '0;
            end
        end else if (update_valid_i) begin
            valid_q[update_index_w] <= 1'b1;
            tag_q[update_index_w] <= update_tag_w;
            target_q[update_index_w] <= update_target_i;

            // new entry
            if (!valid_q[update_index_w] || tag_q[update_index_w] != update_tag_w) begin
                // init to weakly states
                state_q[update_index_w] <= update_taken_i ? 2'b10 : 2'b01;
            end else begin
            // existing entry
                state_q[update_index_w] <= update_taken_i ? (state_q[update_index_w] != 2'b11 ? state_q[update_index_w] + 2'b01 : state_q[update_index_w]) : (state_q[update_index_w] != 2'b00 ? state_q[update_index_w] - 2'b01 : state_q[update_index_w]);
            end
        end
    end

endmodule
