`timescale 1ns/1ps

module wb_stage
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 32
) (
    // meta interface
    input logic [0:0] stall_i,

    // mem interface
    input logic [0:0] mem_wb_valid_i,
    output logic [0:0] wb_mem_ready_o,
    input logic [WIDTH_P-1:0] mem_wb_pc4_i,
    input logic [WIDTH_P-1:0] mem_wb_alu_result_i,
    input logic [WIDTH_P-1:0] mem_wb_load_data_i,
    input logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_i,
    input logic [0:0] mem_wb_reg_write_i,
    input logic [0:0] mem_wb_instr_illegal_i,
    input logic [1:0] mem_wb_wb_sel_i,

    // id/register file interface
    output logic [$clog2(DEPTH_P)-1:0] wb_id_rd_addr_o,
    output logic [WIDTH_P-1:0] wb_id_rd_data_o,
    output logic [0:0] wb_id_rd_we_o,

    // forwarding interface
    output logic [WIDTH_P-1:0] mem_wb_fwd_data_o,

    // commit metadata
    output logic [0:0] wb_commit_valid_o,
    output logic [0:0] wb_instr_illegal_o
);

    // final writeback source mux
    always_comb begin
        case (mem_wb_wb_sel_i)
            pkg::WB_MEM: wb_id_rd_data_o = mem_wb_load_data_i;
            pkg::WB_PC4: wb_id_rd_data_o = mem_wb_pc4_i;
            default: wb_id_rd_data_o = mem_wb_alu_result_i;
        endcase
    end

    assign wb_mem_ready_o = ~stall_i;
    assign wb_id_rd_addr_o = mem_wb_rd_addr_i;
    assign wb_id_rd_we_o = mem_wb_valid_i & wb_mem_ready_o & mem_wb_reg_write_i & ~mem_wb_instr_illegal_i;
    assign mem_wb_fwd_data_o = wb_id_rd_data_o;
    assign wb_commit_valid_o = mem_wb_valid_i & wb_mem_ready_o;
    assign wb_instr_illegal_o = mem_wb_instr_illegal_i;

endmodule
