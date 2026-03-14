`timescale 1ns/1ps

module dm_cache
#(
    parameter WIDTH_P = 32,
    parameter LINES_P = 16
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,

    // module request interface
    input logic [0:0] module_cache_req_valid_i,
    output logic [0:0] cache_module_req_ready_o,
    input logic [0:0] module_cache_req_write_i,
    input logic [WIDTH_P-1:0] module_cache_req_addr_i,
    input logic [WIDTH_P-1:0] module_cache_req_wdata_i,
    input logic [(WIDTH_P/8)-1:0] module_cache_req_wstrb_i,

    // module response interface
    output logic [0:0] cache_module_rsp_valid_o,
    input logic [0:0] module_cache_rsp_ready_i,
    output logic [WIDTH_P-1:0] cache_module_rsp_rdata_o,

    // backend request interface
    output logic [0:0] cache_mem_req_valid_o,
    input logic [0:0] mem_cache_req_ready_i,
    output logic [0:0] cache_mem_req_write_o,
    output logic [WIDTH_P-1:0] cache_mem_req_addr_o,
    output logic [WIDTH_P-1:0] cache_mem_req_wdata_o,
    output logic [(WIDTH_P/8)-1:0] cache_mem_req_wstrb_o,

    // backend response interface
    input logic [0:0] mem_cache_rsp_valid_i,
    output logic [0:0] cache_mem_rsp_ready_o,
    input logic [WIDTH_P-1:0] mem_cache_rsp_rdata_i
);

    // cache control state machine
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MEM_REQ,
        MEM_RESP,
        RESP
    } state_t;

    state_t current_state, next_state;
    logic [WIDTH_P-1:0] req_addr_q;
    logic [WIDTH_P-1:0] req_wdata_q;
    logic [(WIDTH_P/8)-1:0] req_wstrb_q;
    logic [0:0] req_write_q;

    localparam INDEX_W = $clog2(LINES_P);
    localparam TAG_W = WIDTH_P - INDEX_W - 2;

    logic [0:0] valid_q [LINES_P-1:0];
    logic [TAG_W-1:0] tag_q [LINES_P-1:0];
    logic [WIDTH_P-1:0] data_q [LINES_P-1:0];
    logic [INDEX_W-1:0] req_index_w;
    logic [TAG_W-1:0] req_tag_w;
    logic [0:0] hit_w;
    logic [WIDTH_P-1:0] req_addr_aligned_w;
    logic [WIDTH_P-1:0] store_merged_data_w;
    integer i;

    // request decode logic
    assign req_index_w = req_addr_q[INDEX_W+1:2];
    assign req_tag_w = req_addr_q[WIDTH_P-1:INDEX_W+2];
    assign hit_w = valid_q[req_index_w] & (tag_q[req_index_w] == req_tag_w);
    assign req_addr_aligned_w = {req_addr_q[WIDTH_P-1:2], 2'b00};

    // cache line partial store merge logic
    always_comb begin
        store_merged_data_w = data_q[req_index_w];
        for (int byte_idx = 0; byte_idx < WIDTH_P/8; byte_idx = byte_idx + 1) begin
            if (req_wstrb_q[byte_idx]) begin
                store_merged_data_w[(8*byte_idx) +: 8] = req_wdata_q[(8*byte_idx) +: 8];
            end
        end
    end

    // state + cache array update block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            current_state <= IDLE;
            req_addr_q <= '0;
            req_wdata_q <= '0;
            req_wstrb_q <= '0;
            req_write_q <= 1'b0;
            for (i = 0; i < LINES_P; i = i + 1) begin
                valid_q[i] <= 1'b0;
                tag_q[i] <= '0;
                data_q[i] <= '0;
            end
        end else begin
            current_state <= next_state;

            // latch module request when cache accepts it
            if (current_state == IDLE && module_cache_req_valid_i && cache_module_req_ready_o) begin
                req_addr_q <= module_cache_req_addr_i;
                req_wdata_q <= module_cache_req_wdata_i;
                req_wstrb_q <= module_cache_req_wstrb_i;
                req_write_q <= module_cache_req_write_i;
            end

            // fill cache line from backend read response on miss
            if (current_state == MEM_RESP && mem_cache_rsp_valid_i && cache_mem_rsp_ready_o && !req_write_q) begin
                valid_q[req_index_w] <= 1'b1;
                tag_q[req_index_w] <= req_tag_w;
                data_q[req_index_w] <= mem_cache_rsp_rdata_i;
            // update cached word for store hit using byte mask
            end else if (current_state == LOOKUP && req_write_q && hit_w) begin
                data_q[req_index_w] <= store_merged_data_w;
            end
        end
    end

    // next state + ready/valid output logic
    always_comb begin
        next_state = current_state;
        cache_module_req_ready_o = 1'b0;
        cache_module_rsp_valid_o = 1'b0;
        cache_module_rsp_rdata_o = data_q[req_index_w];
        cache_mem_req_valid_o = 1'b0;
        cache_mem_req_write_o = req_write_q;
        cache_mem_req_addr_o = req_addr_aligned_w;
        cache_mem_req_wdata_o = req_wdata_q;
        cache_mem_req_wstrb_o = req_wstrb_q;
        cache_mem_rsp_ready_o = 1'b0;

        case (current_state)
            IDLE: begin
                // accept one module request
                cache_module_req_ready_o = 1'b1;
                if (module_cache_req_valid_i & cache_module_req_ready_o) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                // choose hit response, read miss refill, or store write-through
                if (!req_write_q && hit_w) begin
                    next_state = RESP;
                end else begin
                    next_state = MEM_REQ;
                end
            end
            MEM_REQ: begin
                // issue one simple backend read or write request
                cache_mem_req_valid_o = 1'b1;
                if (cache_mem_req_valid_o & mem_cache_req_ready_i) begin
                    next_state = MEM_RESP;
                end
            end
            MEM_RESP: begin
                // wait for backend data or write completion
                cache_mem_rsp_ready_o = 1'b1;
                if (mem_cache_rsp_valid_i & cache_mem_rsp_ready_o) begin
                    next_state = RESP;
                end
            end
            RESP: begin
                // return raw cache word or store completion to module
                cache_module_rsp_valid_o = 1'b1;
                cache_module_rsp_rdata_o = req_write_q ? '0 : data_q[req_index_w];
                if (module_cache_rsp_ready_i) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
