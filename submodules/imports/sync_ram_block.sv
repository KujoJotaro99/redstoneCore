`timescale 1ns/1ps

module sync_ram_block #(
    parameter WIDTH_P = 32, 
    parameter DEPTH_P = 128, 
    parameter filename_p = ""
) (
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [WIDTH_P-1:0] data_i,
    input logic [$clog2(DEPTH_P)-1:0] wr_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] rd_addr_i,
    input logic [0:0] wr_en_i,
    input logic [(WIDTH_P/8)-1:0] wr_mask_i,
    input logic [0:0] rd_en_i,
    output logic [WIDTH_P-1:0] data_o
);

    logic [WIDTH_P-1:0] mem_array [DEPTH_P-1:0];
    integer i;
    integer byte_idx;

    initial begin
        for (i = 0; i < DEPTH_P; i = i + 1) begin
            mem_array[i] = '0;
        end
        if (filename_p != "") begin
            $readmemh(filename_p, mem_array);
        end
// `ifndef SYNTHESIS
//         for (i = 0; i < DEPTH_P; i = i + 1) begin
//             $dumpvars(0, mem_array[i]);
//         end
// `endif
`ifndef SYNTHESIS
        $display("%m: depth_p is %d, width_p is %d", DEPTH_P, WIDTH_P);
`endif
    end

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin

        end else begin
            if (rd_en_i) begin
                data_o <= mem_array[rd_addr_i];
            end
            if (wr_en_i) begin
                for (byte_idx = 0; byte_idx < WIDTH_P/8; byte_idx = byte_idx + 1) begin
                    if (wr_mask_i[byte_idx]) begin
                        mem_array[wr_addr_i][byte_idx*8 +: 8] <= data_i[byte_idx*8 +: 8];
                    end
                end
            end
        end
    end
endmodule
