`timescale 1ns/1ps

module regfile 
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 32
) (
    // clock/reset
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,

    input logic [$clog2(DEPTH_P)-1:0] rs1_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] rs2_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] rd_addr_i,
    input logic [WIDTH_P-1:0] rd_data_i,
    input logic [0:0] rd_we_i,

    output logic [WIDTH_P-1:0] rs1_data_o,
    output logic [WIDTH_P-1:0] rs2_data_o
);

    logic [WIDTH_P-1:0] regs [DEPTH_P-1:0];

    always_ff @(posedge clk_i) begin
        if (rd_we_i && (rd_addr_i != '0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

    always_comb begin
        if (rs1_addr_i == '0) begin
            rs1_data_o = '0;
        end else begin
            rs1_data_o = regs[rs1_addr_i];
        end

        if (rs2_addr_i == '0) begin
            rs2_data_o = '0;
        end else begin
            rs2_data_o = regs[rs2_addr_i];
        end
    end

endmodule
