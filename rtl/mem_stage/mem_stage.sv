`timescale 1ns/1ps

module mem_stage
#(
    parameter WIDTH_P = 32,
    parameter DEPTH_P = 32
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,
    input logic [0:0] flush_i,
    input logic [0:0] stall_i,

    // ex interface
    input logic [0:0] ex_mem_valid_i,
    output logic [0:0] mem_ex_ready_o,
    input logic [WIDTH_P-1:0] ex_mem_pc_i,
    input logic [WIDTH_P-1:0] ex_mem_pc4_i,
    input logic [WIDTH_P-1:0] ex_mem_alu_result_i,
    input logic [WIDTH_P-1:0] ex_mem_rs2_data_i,
    input logic [$clog2(DEPTH_P)-1:0] ex_mem_rd_addr_i,
    input logic [0:0] ex_mem_reg_write_i,
    input logic [0:0] ex_mem_mem_read_i,
    input logic [0:0] ex_mem_mem_write_i,
    input logic [2:0] ex_mem_funct3_i,
    input logic [0:0] ex_mem_instr_illegal_i,
    input logic [1:0] ex_mem_wb_sel_i,

    // cache request interface
    output logic [0:0] mem_cache_req_valid_o,
    input logic [0:0] cache_mem_req_ready_i,
    output logic [0:0] mem_cache_req_write_o,
    output logic [WIDTH_P-1:0] mem_cache_req_addr_o,
    output logic [WIDTH_P-1:0] mem_cache_req_wdata_o,
    output logic [(WIDTH_P/8)-1:0] mem_cache_req_wstrb_o,

    // cache response interface
    input logic [0:0] cache_mem_rsp_valid_i,
    output logic [0:0] mem_cache_rsp_ready_o,
    input logic [WIDTH_P-1:0] cache_mem_rsp_rdata_i,

    // wb interface
    output logic [0:0] mem_wb_valid_o,
    input logic [0:0] wb_mem_ready_i,
    output logic [WIDTH_P-1:0] mem_wb_pc_o,
    output logic [WIDTH_P-1:0] mem_wb_pc4_o,
    output logic [WIDTH_P-1:0] mem_wb_alu_result_o,
    output logic [WIDTH_P-1:0] mem_wb_load_data_o,
    output logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_o,
    output logic [0:0] mem_wb_reg_write_o,
    output logic [0:0] mem_wb_instr_illegal_o,
    output logic [1:0] mem_wb_wb_sel_o
);

    logic [0:0] cache_mem_req_pending_q;
    logic [0:0] cache_access_w;
    logic [WIDTH_P-1:0] store_data_w;
    logic [(WIDTH_P/8)-1:0] store_mask_w;
    logic [WIDTH_P-1:0] load_data_w;

    assign cache_access_w = ex_mem_valid_i & (ex_mem_mem_read_i | ex_mem_mem_write_i); // if no read or write for instr, then passthrough
    assign mem_ex_ready_o = ~stall_i & ~flush_i & (~mem_wb_valid_o | wb_mem_ready_i) & (~cache_access_w | (cache_mem_req_pending_q & cache_mem_rsp_valid_i));

    // store lane mask + shifted write data logic
    always_comb begin
        store_mask_w = 4'b0000;
        store_data_w = ex_mem_rs2_data_i;

        case (ex_mem_funct3_i)
            3'b000: begin
                store_mask_w = 4'b0001 << ex_mem_alu_result_i[1:0];
                store_data_w = {4{ex_mem_rs2_data_i[7:0]}} << (8 * ex_mem_alu_result_i[1:0]);
            end
            3'b001: begin
                store_mask_w = 4'b0011 << {ex_mem_alu_result_i[1], 1'b0};
                store_data_w = {2{ex_mem_rs2_data_i[15:0]}} << (8 * {ex_mem_alu_result_i[1], 1'b0});
            end
            default: begin
                store_mask_w = 4'b1111;
                store_data_w = ex_mem_rs2_data_i;
            end
        endcase
    end

    // load byte/halfword extract + sign extension logic
    always_comb begin
        case (ex_mem_funct3_i)
            3'b000: begin
                // byte lanes
                case (ex_mem_alu_result_i[1:0])
                    2'b00: load_data_w = {{24{cache_mem_rsp_rdata_i[7]}}, cache_mem_rsp_rdata_i[7:0]};
                    2'b01: load_data_w = {{24{cache_mem_rsp_rdata_i[15]}}, cache_mem_rsp_rdata_i[15:8]};
                    2'b10: load_data_w = {{24{cache_mem_rsp_rdata_i[23]}}, cache_mem_rsp_rdata_i[23:16]};
                    default: load_data_w = {{24{cache_mem_rsp_rdata_i[31]}}, cache_mem_rsp_rdata_i[31:24]};
                endcase
            end
            3'b001: begin
                if (ex_mem_alu_result_i[1]) begin
                    load_data_w = {{16{cache_mem_rsp_rdata_i[31]}}, cache_mem_rsp_rdata_i[31:16]};
                end else begin
                    load_data_w = {{16{cache_mem_rsp_rdata_i[15]}}, cache_mem_rsp_rdata_i[15:0]};
                end
            end
            3'b100: begin
                case (ex_mem_alu_result_i[1:0])
                    2'b00: load_data_w = {{24{1'b0}}, cache_mem_rsp_rdata_i[7:0]};
                    2'b01: load_data_w = {{24{1'b0}}, cache_mem_rsp_rdata_i[15:8]};
                    2'b10: load_data_w = {{24{1'b0}}, cache_mem_rsp_rdata_i[23:16]};
                    default: load_data_w = {{24{1'b0}}, cache_mem_rsp_rdata_i[31:24]};
                endcase
            end
            3'b101: begin
                if (ex_mem_alu_result_i[1]) begin
                    load_data_w = {{16{1'b0}}, cache_mem_rsp_rdata_i[31:16]};
                end else begin
                    load_data_w = {{16{1'b0}}, cache_mem_rsp_rdata_i[15:0]};
                end
            end
            default: load_data_w = cache_mem_rsp_rdata_i;
        endcase
    end

    // request issue/response accept block
    assign mem_cache_req_valid_o = ~stall_i & ~flush_i & cache_access_w & ~cache_mem_req_pending_q & (~mem_wb_valid_o | wb_mem_ready_i);
    assign mem_cache_req_write_o = ex_mem_mem_write_i;
    assign mem_cache_req_addr_o = ex_mem_alu_result_i;
    assign mem_cache_req_wdata_o = store_data_w;
    assign mem_cache_req_wstrb_o = ex_mem_mem_write_i ? store_mask_w : '0;
    assign mem_cache_rsp_ready_o = ~stall_i & ~flush_i & cache_mem_req_pending_q & (~mem_wb_valid_o | wb_mem_ready_i);

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            cache_mem_req_pending_q <= 1'b0;
        end else if (flush_i) begin
            cache_mem_req_pending_q <= 1'b0;
        end else begin
            if (mem_cache_req_valid_o & cache_mem_req_ready_i) begin
                cache_mem_req_pending_q <= 1'b1;
            end else if (cache_mem_rsp_valid_i & mem_cache_rsp_ready_o) begin
                cache_mem_req_pending_q <= 1'b0;
            end
        end
    end

    // mem wb latch
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            mem_wb_valid_o <= 1'b0;
            mem_wb_pc_o <= '0;
            mem_wb_pc4_o <= '0;
            mem_wb_alu_result_o <= '0;
            mem_wb_load_data_o <= '0;
            mem_wb_rd_addr_o <= '0;
            mem_wb_reg_write_o <= 1'b0;
            mem_wb_instr_illegal_o <= 1'b0;
            mem_wb_wb_sel_o <= pkg::WB_ALU;
        end else if (flush_i) begin
            mem_wb_valid_o <= 1'b0;
            mem_wb_pc_o <= '0;
            mem_wb_pc4_o <= '0;
            mem_wb_alu_result_o <= '0;
            mem_wb_load_data_o <= '0;
            mem_wb_rd_addr_o <= '0;
            mem_wb_reg_write_o <= 1'b0;
            mem_wb_instr_illegal_o <= 1'b0;
            mem_wb_wb_sel_o <= pkg::WB_ALU;
        end else if (mem_ex_ready_o) begin
            mem_wb_valid_o <= ex_mem_valid_i;
            mem_wb_pc_o <= ex_mem_pc_i;
            mem_wb_pc4_o <= ex_mem_pc4_i;
            mem_wb_alu_result_o <= ex_mem_alu_result_i;
            mem_wb_load_data_o <= ex_mem_mem_read_i ? load_data_w : '0;
            mem_wb_rd_addr_o <= ex_mem_rd_addr_i;
            mem_wb_reg_write_o <= ex_mem_reg_write_i;
            mem_wb_instr_illegal_o <= ex_mem_instr_illegal_i;
            mem_wb_wb_sel_o <= ex_mem_wb_sel_i;
        end
    end

endmodule
