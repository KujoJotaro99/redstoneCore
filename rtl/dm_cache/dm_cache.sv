`timescale 1ns/1ps

module dm_cache
#(
    parameter WIDTH_P = 32,
    parameter LINES_P = 16
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,

    // if request interface
    input logic [0:0] if_cache_req_valid_i, // valid request
    output logic [0:0] cache_if_req_ready_o, // ready to consume request
    input logic [WIDTH_P-1:0] if_cache_req_addr_i,

    // if response interface
    output logic [0:0] cache_if_rsp_valid_o, // valid response
    input logic [0:0] if_cache_rsp_ready_i, // ready to consume response
    output logic [WIDTH_P-1:0] cache_if_rsp_instr_o,

    // AXI read address channel
    output logic [WIDTH_P-1:0] axi_araddr_o,
    output logic [2:0] axi_arprot_o,
    output logic [0:0] axi_arvalid_o,
    input logic [0:0] axi_arready_i,

    // AXI read data channel
    input logic [WIDTH_P-1:0] axi_rdata_i,
    input logic [1:0] axi_rresp_i,
    input logic [0:0] axi_rvalid_i,
    output logic [0:0] axi_rready_o

);

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        MISS_AR,
        MISS_R,
        RESP
    } state_t;

    state_t current_state, next_state;
    logic [WIDTH_P-1:0] if_cache_req_addr_q;

    logic [0:0] valid_q [LINES_P-1:0];
    logic [WIDTH_P-$clog2(LINES_P)-2-1:0] tag_q [LINES_P-1:0]; // 32 - 4 -2
    logic [WIDTH_P-1:0] data_q [LINES_P-1:0];
    integer i;

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            current_state <= IDLE;
            if_cache_req_addr_q <= '0;
            for (i = 0; i < LINES_P; i = i + 1) begin
                valid_q[i] <= 1'b0;
                tag_q[i] <= '0;
                data_q[i] <= '0;
            end
        end else begin
            current_state <= next_state;

            if (current_state == IDLE && if_cache_req_valid_i && cache_if_req_ready_o) begin
                if_cache_req_addr_q <= if_cache_req_addr_i;
            end

            if (current_state == MISS_R && axi_rvalid_i && axi_rready_o) begin
                valid_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]] <= 1'b1;
                tag_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]] <= if_cache_req_addr_q[WIDTH_P-1:$clog2(LINES_P)+2];
                data_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]] <= axi_rdata_i;
            end
        end
    end

    always_comb begin
        // default
        next_state = current_state;
        cache_if_req_ready_o = 1'b0;
        cache_if_rsp_valid_o = 1'b0;
        cache_if_rsp_instr_o = '0;
        axi_araddr_o = if_cache_req_addr_q;
        axi_arprot_o = 3'b100;
        axi_arvalid_o = 1'b0;
        axi_rready_o = 1'b0;

        case (current_state)
            IDLE: begin
                cache_if_req_ready_o = 1'b1;
                if (if_cache_req_valid_i & cache_if_req_ready_o) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                if (valid_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]] & (tag_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]] == if_cache_req_addr_q[WIDTH_P-1:$clog2(LINES_P)+2])) begin
                    next_state = RESP;
                end else begin
                    next_state = MISS_AR;
                end
            end 
            RESP: begin
                cache_if_rsp_valid_o = 1'b1;
                cache_if_rsp_instr_o = data_q[if_cache_req_addr_q[$clog2(LINES_P)+1:2]];

                if (if_cache_rsp_ready_i) begin
                    next_state = IDLE;
                end
            end
            MISS_AR: begin
                // drive axi read request
                axi_arvalid_o = 1'b1;
                axi_araddr_o = if_cache_req_addr_q;
                // wait for handshake
                if (axi_arvalid_o & axi_arready_i) begin
                    next_state = MISS_R;
                end
            end
            MISS_R: begin
                axi_rready_o = 1'b1;
                // wait for mem response
                if (axi_rvalid_i & axi_rready_o) begin
                    next_state = RESP;
                end
            end
        endcase
    end

endmodule
