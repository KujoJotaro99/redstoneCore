`timescale 1ns/1ps

module branch_target_buffer
#(
    parameter WIDTH_P = 32,
    parameter ENTRIES_P = 16
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

    logic [0:0] valid_q [ENTRIES_P-1:0];
    logic [WIDTH_P-$clog2(ENTRIES_P)-2-1:0] tag_q [ENTRIES_P-1:0];
    logic [0:0] taken_q [ENTRIES_P-1:0];
    logic [WIDTH_P-1:0] target_q [ENTRIES_P-1:0];
    integer i;

    // lookup block
    always_comb begin // lookup_pc[5:2] is row
        pred_valid_o = valid_q[lookup_pc_i[$clog2(ENTRIES_P)+1:2]] & (tag_q[lookup_pc_i[$clog2(ENTRIES_P)+1:2]] == lookup_pc_i[WIDTH_P-1:$clog2(ENTRIES_P)+2]);
        pred_taken_o = pred_valid_o & taken_q[lookup_pc_i[$clog2(ENTRIES_P)+1:2]];
        pred_target_o = target_q[lookup_pc_i[$clog2(ENTRIES_P)+1:2]];
    end

    // update block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            for (i = 0; i < ENTRIES_P; i = i + 1) begin
                valid_q[i] <= 1'b0;
                tag_q[i] <= '0;
                taken_q[i] <= 1'b0;
                target_q[i] <= '0;
            end
        end else if (update_valid_i) begin
            valid_q[update_pc_i[$clog2(ENTRIES_P)+1:2]] <= 1'b1;
            tag_q[update_pc_i[$clog2(ENTRIES_P)+1:2]] <= update_pc_i[WIDTH_P-1:$clog2(ENTRIES_P)+2];
            taken_q[update_pc_i[$clog2(ENTRIES_P)+1:2]] <= update_taken_i;
            target_q[update_pc_i[$clog2(ENTRIES_P)+1:2]] <= update_target_i;
        end
    end

endmodule
