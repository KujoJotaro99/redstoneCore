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
    input logic [WIDTH_P-1:0] ex_mem_instr_i,
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
    input logic [0:0] ex_mem_instr_access_fault_i,
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
    input logic [1:0] cache_mem_rsp_resp_i,

    // id wb interface
    output logic [0:0] mem_wb_valid_o,
    output logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_o,
    output logic [0:0] mem_wb_reg_write_o,
    output logic [WIDTH_P-1:0] debug_pc_o,
    output logic [$clog2(DEPTH_P)-1:0] wb_id_rd_addr_o,
    output logic [WIDTH_P-1:0] wb_id_rd_data_o,
    output logic [0:0] wb_id_rd_we_o,
    output logic [WIDTH_P-1:0] mem_wb_fwd_data_o,
    output logic [0:0] debug_valid_o,
    output logic [0:0] debug_instr_illegal_o,
    output logic [0:0] mem_access_fault_o
);

    logic [0:0] cache_mem_req_pending_q;
    logic [0:0] cache_access_w;
    logic [0:0] wb_ready_w;
    logic [WIDTH_P-1:0] store_data_w;
    logic [(WIDTH_P/8)-1:0] store_mask_w;
    logic [WIDTH_P-1:0] load_data_w;
    logic [1:0] addr_low_w;
    logic [0:0] addr_half_w;
    logic [7:0] rs2_byte_w;
    logic [15:0] rs2_half_w;
    logic [WIDTH_P-1:0] store_byte0_w;
    logic [WIDTH_P-1:0] store_byte1_w;
    logic [WIDTH_P-1:0] store_byte2_w;
    logic [WIDTH_P-1:0] store_byte3_w;
    logic [WIDTH_P-1:0] store_half0_w;
    logic [WIDTH_P-1:0] store_half1_w;
    logic [WIDTH_P-1:0] load_byte0_signed_w;
    logic [WIDTH_P-1:0] load_byte1_signed_w;
    logic [WIDTH_P-1:0] load_byte2_signed_w;
    logic [WIDTH_P-1:0] load_byte3_signed_w;
    logic [WIDTH_P-1:0] load_half0_signed_w;
    logic [WIDTH_P-1:0] load_half1_signed_w;
    logic [WIDTH_P-1:0] load_byte0_unsigned_w;
    logic [WIDTH_P-1:0] load_byte1_unsigned_w;
    logic [WIDTH_P-1:0] load_byte2_unsigned_w;
    logic [WIDTH_P-1:0] load_byte3_unsigned_w;
    logic [WIDTH_P-1:0] load_half0_unsigned_w;
    logic [WIDTH_P-1:0] load_half1_unsigned_w;
    logic [WIDTH_P-1:0] mem_wb_pc_q;
    logic [WIDTH_P-1:0] mem_wb_pc4_q;
    logic [WIDTH_P-1:0] mem_wb_alu_result_q;
    logic [WIDTH_P-1:0] mem_wb_load_data_q;
    logic [0:0] mem_wb_instr_illegal_q;
    logic [1:0] mem_wb_wb_sel_q;

    assign cache_access_w = ex_mem_valid_i & (ex_mem_mem_read_i | ex_mem_mem_write_i); // if no read or write for instr, then passthrough
    assign wb_ready_w = ~stall_i;
    assign mem_ex_ready_o = ~stall_i & ~flush_i & (~mem_wb_valid_o | wb_ready_w) & (~cache_access_w | (cache_mem_req_pending_q & cache_mem_rsp_valid_i));
    assign addr_low_w = ex_mem_alu_result_i[1:0];
    assign addr_half_w = ex_mem_alu_result_i[1];
    assign rs2_byte_w = ex_mem_rs2_data_i[7:0];
    assign rs2_half_w = ex_mem_rs2_data_i[15:0];
    assign store_byte0_w = {24'b0, rs2_byte_w};
    assign store_byte1_w = {16'b0, rs2_byte_w, 8'b0};
    assign store_byte2_w = {8'b0, rs2_byte_w, 16'b0};
    assign store_byte3_w = {rs2_byte_w, 24'b0};
    assign store_half0_w = {16'b0, rs2_half_w};
    assign store_half1_w = {rs2_half_w, 16'b0};
    assign load_byte0_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[7:0]));
    assign load_byte1_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[15:8]));
    assign load_byte2_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[23:16]));
    assign load_byte3_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[31:24]));
    assign load_half0_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[15:0]));
    assign load_half1_signed_w = 32'(signed'(cache_mem_rsp_rdata_i[31:16]));
    assign load_byte0_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[7:0]));
    assign load_byte1_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[15:8]));
    assign load_byte2_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[23:16]));
    assign load_byte3_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[31:24]));
    assign load_half0_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[15:0]));
    assign load_half1_unsigned_w = 32'(unsigned'(cache_mem_rsp_rdata_i[31:16]));

    // store lane mask + shifted write data logic
    always_comb begin
        store_mask_w = 4'b0000;
        store_data_w = ex_mem_rs2_data_i;

        case (ex_mem_funct3_i)
            3'b000: begin
                case (addr_low_w)
                    2'b00: begin store_mask_w = 4'b0001; store_data_w = store_byte0_w; end
                    2'b01: begin store_mask_w = 4'b0010; store_data_w = store_byte1_w; end
                    2'b10: begin store_mask_w = 4'b0100; store_data_w = store_byte2_w; end
                    default: begin store_mask_w = 4'b1000; store_data_w = store_byte3_w; end
                endcase
            end
            3'b001: begin
                if (addr_half_w) begin
                    store_mask_w = 4'b1100;
                    store_data_w = store_half1_w;
                end else begin
                    store_mask_w = 4'b0011;
                    store_data_w = store_half0_w;
                end
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
                case (addr_low_w)
                    2'b00: load_data_w = load_byte0_signed_w;
                    2'b01: load_data_w = load_byte1_signed_w;
                    2'b10: load_data_w = load_byte2_signed_w;
                    default: load_data_w = load_byte3_signed_w;
                endcase
            end
            3'b001: begin
                if (addr_half_w) begin
                    load_data_w = load_half1_signed_w;
                end else begin
                    load_data_w = load_half0_signed_w;
                end
            end
            3'b100: begin
                case (addr_low_w)
                    2'b00: load_data_w = load_byte0_unsigned_w;
                    2'b01: load_data_w = load_byte1_unsigned_w;
                    2'b10: load_data_w = load_byte2_unsigned_w;
                    default: load_data_w = load_byte3_unsigned_w;
                endcase
            end
            3'b101: begin
                if (addr_half_w) begin
                    load_data_w = load_half1_unsigned_w;
                end else begin
                    load_data_w = load_half0_unsigned_w;
                end
            end
            default: load_data_w = cache_mem_rsp_rdata_i;
        endcase
    end

    // final writeback source mux
    always_comb begin
        case (mem_wb_wb_sel_q)
            pkg::WB_MEM: wb_id_rd_data_o = mem_wb_load_data_q;
            pkg::WB_PC4: wb_id_rd_data_o = mem_wb_pc4_q;
            default: wb_id_rd_data_o = mem_wb_alu_result_q;
        endcase
    end

    assign debug_pc_o = mem_wb_pc_q;
    assign wb_id_rd_addr_o = mem_wb_rd_addr_o;
    assign wb_id_rd_we_o = mem_wb_valid_o & wb_ready_w & mem_wb_reg_write_o & ~mem_wb_instr_illegal_q;
    assign mem_wb_fwd_data_o = wb_id_rd_data_o;
    assign debug_valid_o = mem_wb_valid_o & wb_ready_w;
    assign debug_instr_illegal_o = mem_wb_instr_illegal_q;
    assign mem_access_fault_o = cache_mem_rsp_valid_i & mem_cache_rsp_ready_o & (cache_mem_rsp_resp_i != 2'b00); // should never respond with issue in axi ram ip

    // request issue/response accept block
    assign mem_cache_req_valid_o = ~stall_i & ~flush_i & cache_access_w & ~cache_mem_req_pending_q & (~mem_wb_valid_o | wb_ready_w);
    assign mem_cache_req_write_o = ex_mem_mem_write_i;
    assign mem_cache_req_addr_o = ex_mem_alu_result_i;
    assign mem_cache_req_wdata_o = store_data_w;
    assign mem_cache_req_wstrb_o = ex_mem_mem_write_i ? store_mask_w : '0;
    assign mem_cache_rsp_ready_o = ~stall_i & ~flush_i & cache_mem_req_pending_q & (~mem_wb_valid_o | wb_ready_w);

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
            mem_wb_pc_q <= '0;
            mem_wb_pc4_q <= '0;
            mem_wb_alu_result_q <= '0;
            mem_wb_load_data_q <= '0;
            mem_wb_rd_addr_o <= '0;
            mem_wb_reg_write_o <= 1'b0;
            mem_wb_instr_illegal_q <= 1'b0;
            mem_wb_wb_sel_q <= pkg::WB_ALU;
        end else if (flush_i) begin
            mem_wb_valid_o <= 1'b0;
            mem_wb_pc_q <= '0;
            mem_wb_pc4_q <= '0;
            mem_wb_alu_result_q <= '0;
            mem_wb_load_data_q <= '0;
            mem_wb_rd_addr_o <= '0;
            mem_wb_reg_write_o <= 1'b0;
            mem_wb_instr_illegal_q <= 1'b0;
            mem_wb_wb_sel_q <= pkg::WB_ALU;
        end else if (mem_ex_ready_o) begin
            mem_wb_valid_o <= ex_mem_valid_i;
            mem_wb_pc_q <= ex_mem_pc_i;
            mem_wb_pc4_q <= ex_mem_pc4_i;
            mem_wb_alu_result_q <= ex_mem_alu_result_i;
            mem_wb_load_data_q <= ex_mem_mem_read_i ? load_data_w : '0;
            mem_wb_rd_addr_o <= ex_mem_rd_addr_i;
            mem_wb_reg_write_o <= ex_mem_reg_write_i;
            mem_wb_instr_illegal_q <= ex_mem_instr_illegal_i;
            mem_wb_wb_sel_q <= ex_mem_wb_sel_i;
        end
    end

endmodule
