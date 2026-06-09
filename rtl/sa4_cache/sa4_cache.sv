`timescale 1ns/1ps

module sa4_cache
#(
    parameter WIDTH_P = 32,
    parameter CACHE_SIZE_BYTES_P = 4096,
    parameter LINE_SIZE_BYTES_P = 16,
    parameter WAYS_P = 4
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
    output logic [1:0] cache_module_rsp_resp_o,

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
    input logic [WIDTH_P-1:0] mem_cache_rsp_rdata_i,
    input logic [1:0] mem_cache_rsp_resp_i
);

    // cache control state machine
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        WRITEBACK_REQ,
        WRITEBACK_RESP,
        REFILL_REQ,
        REFILL_RESP,
        UPDATE,
        RESP
    } state_t;

    state_t current_state, next_state;

    localparam BYTE_LANES_P = WIDTH_P / 8;
    localparam WORDS_PER_LINE_P = LINE_SIZE_BYTES_P / BYTE_LANES_P;
    localparam LINES_P = CACHE_SIZE_BYTES_P / LINE_SIZE_BYTES_P;
    localparam SETS_P = LINES_P / WAYS_P;
    localparam BYTE_OFFSET_W = $clog2(BYTE_LANES_P);
    localparam WORD_OFFSET_W = $clog2(WORDS_PER_LINE_P);
    localparam SET_W = $clog2(SETS_P);
    localparam TAG_W = WIDTH_P - SET_W - WORD_OFFSET_W - BYTE_OFFSET_W;
    localparam WAY_W = $clog2(WAYS_P);

    logic valid_q [SETS_P-1:0][WAYS_P-1:0];
    logic dirty_q [SETS_P-1:0][WAYS_P-1:0];
    logic [TAG_W-1:0] tag_q [SETS_P-1:0][WAYS_P-1:0];
    logic [WIDTH_P-1:0] data_q [SETS_P-1:0][WAYS_P-1:0][WORDS_PER_LINE_P-1:0];
    logic [WAY_W-1:0] random_line_q;

    logic [0:0] req_write_q;
    logic [WIDTH_P-1:0] req_addr_q;
    logic [WIDTH_P-1:0] req_wdata_q;
    logic [BYTE_LANES_P-1:0] req_wstrb_q;
    logic [WORD_OFFSET_W-1:0] req_word_w;
    logic [SET_W-1:0] req_set_w;
    logic [TAG_W-1:0] req_tag_w;
    logic [WAY_W-1:0] active_line_q;
    logic [WORD_OFFSET_W-1:0] line_word_counter_q;
    logic [WORD_OFFSET_W-1:0] refill_word_q;
    logic [WIDTH_P-1:0] refill_data_q;
    logic [WIDTH_P-1:0] rsp_rdata_q;
    logic [1:0] rsp_resp_q;

    logic [0:0] hit_w;
    logic [WAY_W-1:0] hit_line_w;
    logic [0:0] invalid_line_valid_w;
    logic [WAY_W-1:0] invalid_line_w;
    logic [WAY_W-1:0] replace_line_w;
    logic [0:0] replace_dirty_w;
    logic [0:0] final_word_w;
    logic [WIDTH_P-1:0] refill_addr_w;
    logic [WIDTH_P-1:0] writeback_addr_w;
    logic [WIDTH_P-1:0] store_byte_mask_w;
    logic [WIDTH_P-1:0] store_old_data_w;
    logic [WIDTH_P-1:0] store_merged_data_w;

    integer set_idx;
    integer line_idx;
    integer word_idx;

    assign req_word_w = req_addr_q[BYTE_OFFSET_W +: WORD_OFFSET_W];
    assign req_set_w = req_addr_q[BYTE_OFFSET_W + WORD_OFFSET_W +: SET_W];
    assign req_tag_w = req_addr_q[BYTE_OFFSET_W + WORD_OFFSET_W + SET_W +: TAG_W];
    assign final_word_w = (line_word_counter_q == WORD_OFFSET_W'(WORDS_PER_LINE_P-1));
    assign replace_dirty_w = valid_q[req_set_w][replace_line_w] & dirty_q[req_set_w][replace_line_w];
    assign refill_addr_w = {req_tag_w, req_set_w, line_word_counter_q, {BYTE_OFFSET_W{1'b0}}};
    assign writeback_addr_w = {tag_q[req_set_w][active_line_q], req_set_w, line_word_counter_q, {BYTE_OFFSET_W{1'b0}}};

    always_comb begin
        hit_w = 1'b0;
        hit_line_w = '0;
        invalid_line_valid_w = 1'b0;
        invalid_line_w = '0;
        store_byte_mask_w = '0;

        for (int i = 0; i < WAYS_P; i++) begin
            if (valid_q[req_set_w][i] && (tag_q[req_set_w][i] == req_tag_w)) begin
                hit_w = 1'b1;
                hit_line_w = WAY_W'(i);
            end

            if (!valid_q[req_set_w][i] && !invalid_line_valid_w) begin
                invalid_line_valid_w = 1'b1;
                invalid_line_w = WAY_W'(i);
            end
        end

        for (int i = 0; i < BYTE_LANES_P; i++) begin
            store_byte_mask_w[i*8 +: 8] = {8{req_wstrb_q[i]}};
        end
    end

    assign replace_line_w = invalid_line_valid_w ? invalid_line_w : random_line_q;
    assign store_old_data_w = data_q[req_set_w][active_line_q][req_word_w];
    assign store_merged_data_w = (store_old_data_w & ~store_byte_mask_w) | (req_wdata_q & store_byte_mask_w);

    // state + cache array update block
    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            current_state <= IDLE;
            req_write_q <= 1'b0;
            req_addr_q <= '0;
            req_wdata_q <= '0;
            req_wstrb_q <= '0;
            active_line_q <= '0;
            line_word_counter_q <= '0;
            refill_word_q <= '0;
            refill_data_q <= '0;
            random_line_q <= '0;
            rsp_rdata_q <= '0;
            rsp_resp_q <= 2'b00;

            for (set_idx = 0; set_idx < SETS_P; set_idx = set_idx + 1) begin
                for (line_idx = 0; line_idx < WAYS_P; line_idx = line_idx + 1) begin
                    valid_q[set_idx][line_idx] <= 1'b0;
                    dirty_q[set_idx][line_idx] <= 1'b0;
                    tag_q[set_idx][line_idx] <= '0;
                    for (word_idx = 0; word_idx < WORDS_PER_LINE_P; word_idx = word_idx + 1) begin
                        data_q[set_idx][line_idx][word_idx] <= '0;
                    end
                end
            end
        end else begin
            current_state <= next_state;

            // latch requests in idle
            if (current_state == IDLE && module_cache_req_valid_i && cache_module_req_ready_o) begin
                req_write_q <= module_cache_req_write_i;
                req_addr_q <= module_cache_req_addr_i;
                req_wdata_q <= module_cache_req_wdata_i;
                req_wstrb_q <= module_cache_req_wstrb_i;
                rsp_rdata_q <= '0;
                rsp_resp_q <= 2'b00;
            end

            // lookup line or write and set dirty
            if (current_state == LOOKUP) begin
                if (hit_w) begin
                    active_line_q <= hit_line_w;
                    rsp_resp_q <= 2'b00;
                    if (req_write_q) begin
                        // existing word cleared then new desired word masked over
                        data_q[req_set_w][hit_line_w][req_word_w] <= (data_q[req_set_w][hit_line_w][req_word_w] & ~store_byte_mask_w) | (req_wdata_q & store_byte_mask_w);
                        dirty_q[req_set_w][hit_line_w] <= 1'b1;
                        rsp_rdata_q <= '0;
                    end else begin
                        rsp_rdata_q <= data_q[req_set_w][hit_line_w][req_word_w];
                    end
                end else begin
                    active_line_q <= replace_line_w;
                    line_word_counter_q <= '0;
                    random_line_q <= random_line_q + WAY_W'(1);
                end
            end

            // write dirty line to mem
            if (current_state == WRITEBACK_RESP && mem_cache_rsp_valid_i) begin
                rsp_resp_q <= mem_cache_rsp_resp_i;
                // OKAY, axil never returns anything else but still
                if (mem_cache_rsp_resp_i == 2'b00) begin
                    if (final_word_w) begin
                        line_word_counter_q <= '0;
                        dirty_q[req_set_w][active_line_q] <= 1'b0;
                    end else begin
                        line_word_counter_q <= line_word_counter_q + WORD_OFFSET_W'(1);
                    end
                end
            end

            // request data from mem
            if (current_state == REFILL_RESP && mem_cache_rsp_valid_i) begin
                rsp_resp_q <= mem_cache_rsp_resp_i;
                // OKAY, axil never returns anything else but still
                if (mem_cache_rsp_resp_i == 2'b00) begin
                    refill_word_q <= line_word_counter_q;
                    refill_data_q <= mem_cache_rsp_rdata_i;
                    data_q[req_set_w][active_line_q][line_word_counter_q] <= mem_cache_rsp_rdata_i;
                    if (final_word_w) begin
                        line_word_counter_q <= '0;
                    end else begin
                        line_word_counter_q <= line_word_counter_q + WORD_OFFSET_W'(1);
                    end
                end
            end

            // evict
            if (current_state == UPDATE) begin
                valid_q[req_set_w][active_line_q] <= 1'b1;
                tag_q[req_set_w][active_line_q] <= req_tag_w;
                if (req_write_q) begin
                    data_q[req_set_w][active_line_q][req_word_w] <= store_merged_data_w;
                    dirty_q[req_set_w][active_line_q] <= 1'b1;
                    rsp_rdata_q <= '0;
                end else begin
                    dirty_q[req_set_w][active_line_q] <= 1'b0;
                    if (req_word_w == refill_word_q) begin
                        rsp_rdata_q <= refill_data_q;
                    end else begin
                        rsp_rdata_q <= data_q[req_set_w][active_line_q][req_word_w];
                    end
                end
            end
        end
    end

    // next state + ready/valid output logic
    always_comb begin
        next_state = current_state;
        cache_module_req_ready_o = 1'b0;
        cache_module_rsp_valid_o = 1'b0;
        cache_module_rsp_rdata_o = rsp_rdata_q;
        cache_module_rsp_resp_o = rsp_resp_q;
        cache_mem_req_valid_o = 1'b0;
        cache_mem_req_write_o = 1'b0;
        cache_mem_req_addr_o = refill_addr_w;
        cache_mem_req_wdata_o = '0;
        cache_mem_req_wstrb_o = '0;
        cache_mem_rsp_ready_o = 1'b0;

        case (current_state)
            IDLE: begin
                // accept one module request
                cache_module_req_ready_o = 1'b1;
                if (module_cache_req_valid_i) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                // hit completes immediately, miss writes back dirty line before refill
                if (hit_w) begin
                    next_state = RESP;
                end else if (replace_dirty_w) begin
                    next_state = WRITEBACK_REQ;
                end else begin
                    next_state = REFILL_REQ;
                end
            end
            WRITEBACK_REQ: begin
                // write one dirty line word back to memory
                cache_mem_req_valid_o = 1'b1;
                cache_mem_req_write_o = 1'b1;
                cache_mem_req_addr_o = writeback_addr_w;
                cache_mem_req_wdata_o = data_q[req_set_w][active_line_q][line_word_counter_q];
                cache_mem_req_wstrb_o = {BYTE_LANES_P{1'b1}};
                if (mem_cache_req_ready_i) begin
                    next_state = WRITEBACK_RESP;
                end
            end
            WRITEBACK_RESP: begin
                // wait for write response before issuing next word
                cache_mem_rsp_ready_o = 1'b1;
                if (mem_cache_rsp_valid_i) begin
                    if (mem_cache_rsp_resp_i != 2'b00) begin
                        next_state = RESP;
                    end else if (final_word_w) begin
                        next_state = REFILL_REQ;
                    end else begin
                        next_state = WRITEBACK_REQ;
                    end
                end
            end
            REFILL_REQ: begin
                // read one word of the requested cache line
                cache_mem_req_valid_o = 1'b1;
                cache_mem_req_write_o = 1'b0;
                cache_mem_req_addr_o = refill_addr_w;
                cache_mem_req_wdata_o = '0;
                cache_mem_req_wstrb_o = '0;
                if (mem_cache_req_ready_i) begin
                    next_state = REFILL_RESP;
                end
            end
            REFILL_RESP: begin
                // wait for refill data before issuing next word, total of 4 words per line
                cache_mem_rsp_ready_o = 1'b1;
                if (mem_cache_rsp_valid_i) begin
                    if (mem_cache_rsp_resp_i != 2'b00) begin
                        next_state = RESP;
                    end else if (final_word_w) begin
                        next_state = UPDATE;
                    end else begin
                        next_state = REFILL_REQ;
                    end
                end
            end
            UPDATE: begin
                // install refilled line and apply store miss for write-allocate
                next_state = RESP;
            end
            RESP: begin
                // return cache response to module
                cache_module_rsp_valid_o = 1'b1;
                if (module_cache_rsp_ready_i) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
