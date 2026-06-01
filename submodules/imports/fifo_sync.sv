`timescale 1ns/1ps

module fifo_sync 
#(
    parameter WIDTH_P = 8,
    parameter DEPTH_P = 16
) (
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [WIDTH_P-1:0] data_i,
    input logic [0:0] valid_i,
    input logic [0:0] ready_i,
    output logic [0:0] valid_o,
    output logic [0:0] ready_o,
    output logic [WIDTH_P-1:0] data_o
);

    logic [$clog2(DEPTH_P):0] wr_ptr_l, rd_ptr_l, rd_ptr_next_w;
    logic [WIDTH_P-1:0] data_o_bypass_l, data_o_l;
    logic [0:0] full_w;
    logic [0:0] empty_w;
    logic [0:0] one_entry_w;
    logic [0:0] bypass_w;

    // full empty and bypass logic
    assign full_w = ((wr_ptr_l[$clog2(DEPTH_P)] != rd_ptr_l[$clog2(DEPTH_P)]) && (wr_ptr_l[$clog2(DEPTH_P)-1:0] == rd_ptr_l[$clog2(DEPTH_P)-1:0]));
    assign empty_w = (wr_ptr_l[$clog2(DEPTH_P):0] == rd_ptr_l[$clog2(DEPTH_P):0]);
    assign one_entry_w = (wr_ptr_l[$clog2(DEPTH_P):0] == (rd_ptr_l[$clog2(DEPTH_P):0] + 1'b1));
    assign ready_o = ~full_w | (valid_o & ready_i);
    assign valid_o = ~empty_w;
    assign bypass_w = (wr_ptr_l[$clog2(DEPTH_P):0] == rd_ptr_next_w[$clog2(DEPTH_P):0]);

    // next ptr logic
    always_comb begin
        if (!rstn_i) begin
            rd_ptr_next_w = '0;
        end else if (valid_o & ready_i) begin
            rd_ptr_next_w = rd_ptr_l + 1'b1;
        end else begin
            rd_ptr_next_w = rd_ptr_l;
        end
    end

    // curr ptr logic
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            wr_ptr_l <= '0;
        end else if (flush_i) begin
            wr_ptr_l <= '0;
        end else if (valid_i & ready_o) begin
            wr_ptr_l <= wr_ptr_l + 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            rd_ptr_l <= '0;
        end else if (flush_i) begin
            rd_ptr_l <= '0;
        end else if (valid_o & ready_i) begin
            rd_ptr_l <= rd_ptr_l + 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            data_o_bypass_l <= '0;
        end else if (flush_i) begin
            data_o_bypass_l <= '0;
        end else if (valid_i & ready_o) begin
            data_o_bypass_l <= data_i;
        end
    end

    // sync ram
    sync_ram_block #(
        .WIDTH_P(WIDTH_P),
        .DEPTH_P(DEPTH_P)
    ) sync_fifo_ram (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .data_i(data_i),
        .wr_addr_i(wr_ptr_l[$clog2(DEPTH_P)-1:0]),
        .rd_addr_i(rd_ptr_next_w[$clog2(DEPTH_P)-1:0]),
        .wr_en_i(valid_i & ready_o),
        .wr_mask_i({(WIDTH_P/8){1'b1}}),
        .rd_en_i(1'b1),
        .data_o(data_o_l)
    );

    assign data_o = empty_w ? data_i : ((bypass_w | one_entry_w) ? data_o_bypass_l : data_o_l);

endmodule
