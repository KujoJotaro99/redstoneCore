`timescale 1ns/1ps

module axil_master
#(
    parameter ADDR_WIDTH_P = 32,
    parameter DATA_WIDTH_P = 32
) (
    // meta interface
    input logic [0:0] clk_i,
    input logic [0:0] rstn_i,

    // cache request interface
    input logic [0:0] cache_mem_req_valid_i,
    output logic [0:0] mem_cache_req_ready_o,
    input logic [0:0] cache_mem_req_write_i,
    input logic [ADDR_WIDTH_P-1:0] cache_mem_req_addr_i,
    input logic [DATA_WIDTH_P-1:0] cache_mem_req_wdata_i,
    input logic [(DATA_WIDTH_P/8)-1:0] cache_mem_req_wstrb_i,

    // cache response interface
    output logic [0:0] mem_cache_rsp_valid_o,
    input logic [0:0] cache_mem_rsp_ready_i,
    output logic [DATA_WIDTH_P-1:0] mem_cache_rsp_rdata_o,
    output logic [1:0] mem_cache_rsp_resp_o,

    // axi4-lite write address channel
    output logic [0:0] m_axil_awvalid,
    input logic [0:0] m_axil_awready,
    output logic [ADDR_WIDTH_P-1:0] m_axil_awaddr,
    output logic [2:0] m_axil_awprot,

    // axi4-lite write data channel
    output logic [0:0] m_axil_wvalid,
    input logic [0:0] m_axil_wready,
    output logic [DATA_WIDTH_P-1:0] m_axil_wdata,
    output logic [(DATA_WIDTH_P/8)-1:0] m_axil_wstrb,

    // axi4-lite write response channel
    input logic [0:0] m_axil_bvalid,
    output logic [0:0] m_axil_bready,
    input logic [1:0] m_axil_bresp,

    // axi4-lite read address channel
    output logic [0:0] m_axil_arvalid,
    input logic [0:0] m_axil_arready,
    output logic [ADDR_WIDTH_P-1:0] m_axil_araddr,
    output logic [2:0] m_axil_arprot,

    // axi4-lite read data channel
    input logic [0:0] m_axil_rvalid,
    output logic [0:0] m_axil_rready,
    input logic [DATA_WIDTH_P-1:0] m_axil_rdata,
    input logic [1:0] m_axil_rresp
);

    localparam STRB_WIDTH_P = DATA_WIDTH_P / 8;

    logic [DATA_WIDTH_P-1:0] req_wdata_q;
    logic [ADDR_WIDTH_P-1:0] req_addr_q;
    logic [0:0] req_write_q;
    logic [STRB_WIDTH_P-1:0] req_wstrb_q;
    logic [DATA_WIDTH_P-1:0] rsp_rdata_q;
    logic [1:0] rsp_resp_q;
    logic [0:0] aw_done_q, w_done_q, ar_done_q, b_done_q, r_done_q;
    logic [0:0] aw_accept_w, w_accept_w, b_accept_w, ar_accept_w, r_accept_w;

    // i cant friggin read axi without i/o suffixes lol
    logic [0:0] m_axil_awvalid_o;
    logic [0:0] m_axil_awready_i;
    logic [ADDR_WIDTH_P-1:0] m_axil_awaddr_o;
    logic [2:0] m_axil_awprot_o;
    logic [0:0] m_axil_wvalid_o;
    logic [0:0] m_axil_wready_i;
    logic [DATA_WIDTH_P-1:0] m_axil_wdata_o;
    logic [STRB_WIDTH_P-1:0] m_axil_wstrb_o;
    logic [0:0] m_axil_bvalid_i;
    logic [0:0] m_axil_bready_o;
    logic [1:0] m_axil_bresp_i;
    logic [0:0] m_axil_arvalid_o;
    logic [0:0] m_axil_arready_i;
    logic [ADDR_WIDTH_P-1:0] m_axil_araddr_o;
    logic [2:0] m_axil_arprot_o;
    logic [0:0] m_axil_rvalid_i;
    logic [0:0] m_axil_rready_o;
    logic [DATA_WIDTH_P-1:0] m_axil_rdata_i;
    logic [1:0] m_axil_rresp_i;

    typedef enum logic [2:0] {
        IDLE,
        WRITE_TX,
        WRITE_RESP,
        READ_TX
    } state_t;

    state_t current_state, next_state;

    assign m_axil_awvalid = m_axil_awvalid_o;
    assign m_axil_awready_i = m_axil_awready;
    assign m_axil_awaddr = m_axil_awaddr_o;
    assign m_axil_awprot = m_axil_awprot_o;
    assign m_axil_wvalid = m_axil_wvalid_o;
    assign m_axil_wready_i = m_axil_wready;
    assign m_axil_wdata = m_axil_wdata_o;
    assign m_axil_wstrb = m_axil_wstrb_o;
    assign m_axil_bvalid_i = m_axil_bvalid;
    assign m_axil_bready = m_axil_bready_o;
    assign m_axil_bresp_i = m_axil_bresp;
    assign m_axil_arvalid = m_axil_arvalid_o;
    assign m_axil_arready_i = m_axil_arready;
    assign m_axil_araddr = m_axil_araddr_o;
    assign m_axil_arprot = m_axil_arprot_o;
    assign m_axil_rvalid_i = m_axil_rvalid;
    assign m_axil_rready = m_axil_rready_o;
    assign m_axil_rdata_i = m_axil_rdata;
    assign m_axil_rresp_i = m_axil_rresp;

    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            req_write_q <= 1'b0;
            req_addr_q <= '0;
            req_wdata_q <= '0;
            req_wstrb_q <= '0;
            rsp_rdata_q <= '0;
            rsp_resp_q <= 2'b00;
            aw_done_q <= 1'b0;
            w_done_q <= 1'b0;
            ar_done_q <= 1'b0;
            b_done_q <= 1'b0;
            r_done_q <= 1'b0;
            current_state <= IDLE;
        end else begin
            current_state <= next_state;

            if (current_state == IDLE && cache_mem_req_valid_i && mem_cache_req_ready_o) begin
                req_write_q <= cache_mem_req_write_i;
                req_addr_q <= cache_mem_req_addr_i;
                req_wdata_q <= cache_mem_req_wdata_i;
                req_wstrb_q <= cache_mem_req_wstrb_i;
                rsp_rdata_q <= '0;
                rsp_resp_q <= 2'b00;

                aw_done_q <= 1'b0;
                w_done_q <= 1'b0;
                ar_done_q <= 1'b0;
                b_done_q <= 1'b0;
                r_done_q <= 1'b0;
            end

            if (current_state == WRITE_TX) begin
                if (aw_accept_w) begin
                    aw_done_q <= 1'b1;
                end
                if (w_accept_w) begin
                    w_done_q <= 1'b1;
                end
            end

            if (current_state == WRITE_RESP && b_accept_w) begin
                b_done_q <= 1'b1;
            end

            if (current_state == READ_TX && ar_accept_w) begin
                ar_done_q <= 1'b1;
            end

            if (current_state == READ_TX && r_accept_w) begin
                r_done_q <= 1'b1;
            end

            if (b_accept_w) begin
                rsp_rdata_q <= '0;
                rsp_resp_q <= m_axil_bresp_i;
            end else if (r_accept_w) begin
                rsp_rdata_q <= m_axil_rdata_i;
                rsp_resp_q <= m_axil_rresp_i;
            end
        end
    end

    // channel relationships
    // IDLE: cache side sees mem_cache_req_ready_o high; accepted requests are latched.
    // AW: master drives awvalid_o/awaddr_o; slave answers with awready_i; accept sets aw_done_q.
    // W: master drives wvalid_o/wdata_o/wstrb_o; slave answers with wready_i; accept sets w_done_q.
    // B: slave drives bvalid_i/bresp_i; master answers with bready_o; accept sets b_done_q.
    // AR: master drives arvalid_o/araddr_o; slave answers with arready_i; accept sets ar_done_q.
    // R: slave drives rvalid_i/rdata_i/rresp_i; master answers with rready_o; accept sets r_done_q.
    // downstream sends back data
    assign aw_accept_w = m_axil_awvalid_o & m_axil_awready_i;
    assign w_accept_w = m_axil_wvalid_o & m_axil_wready_i;
    assign b_accept_w = m_axil_bvalid_i & m_axil_bready_o;
    assign ar_accept_w = m_axil_arvalid_o & m_axil_arready_i;
    assign r_accept_w = m_axil_rvalid_i & m_axil_rready_o;

    always_comb begin
        next_state = current_state;
        mem_cache_req_ready_o = 1'b0;
        mem_cache_rsp_valid_o = 1'b0;
        mem_cache_rsp_rdata_o = req_write_q ? '0 : rsp_rdata_q;
        mem_cache_rsp_resp_o = rsp_resp_q;
        m_axil_awvalid_o = 1'b0;
        m_axil_awaddr_o  = req_addr_q;
        m_axil_awprot_o  = 3'b000;
        m_axil_wvalid_o = 1'b0;
        m_axil_wdata_o  = req_wdata_q;
        m_axil_wstrb_o  = req_wstrb_q;
        m_axil_bready_o = 1'b0;
        m_axil_arvalid_o = 1'b0;
        m_axil_araddr_o  = req_addr_q;
        m_axil_arprot_o  = 3'b000;
        m_axil_rready_o = 1'b0;

        case (current_state)
            IDLE: begin
                // default state, allow requests
                mem_cache_req_ready_o = 1'b1;
                if (cache_mem_req_valid_i) begin
                    if (cache_mem_req_write_i) begin
                        next_state = WRITE_TX;
                    end else begin
                        next_state = READ_TX;
                    end
                end
            end

            WRITE_TX: begin
                // keep awvalid/wvalid high independently until each channel accepts
                m_axil_awvalid_o = ~aw_done_q;
                m_axil_wvalid_o = ~w_done_q;

                // write addr and write data can complete in either order
                if ((aw_done_q | aw_accept_w) & (w_done_q | w_accept_w)) begin
                    next_state = WRITE_RESP;
                end
            end

            WRITE_RESP: begin
                // accept one b response, then hold cache response valid until cache accepts
                m_axil_bready_o = ~b_done_q;
                mem_cache_rsp_valid_o = b_done_q;
                mem_cache_rsp_rdata_o = '0;

                if (mem_cache_rsp_valid_o & cache_mem_rsp_ready_i) begin
                    next_state = IDLE;
                end
            end

            READ_TX: begin
                // issue ar first, then accept one r response after ar is done
                m_axil_arvalid_o = ~ar_done_q;
                m_axil_rready_o = ar_done_q & ~r_done_q;
                mem_cache_rsp_valid_o = r_done_q;

                if (mem_cache_rsp_valid_o & cache_mem_rsp_ready_i) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    
endmodule
