module hazard_unit 
#(
    parameter DEPTH_P = 32
) (
    // id interface
    input logic [0:0] if_id_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] rs1_addr_i,
    input logic [$clog2(DEPTH_P)-1:0] rs2_addr_i,
    input logic [0:0] rs1_used_i,
    input logic [0:0] rs2_used_i,

    // ex interface
    input logic [0:0] id_ex_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rs1_addr_i, // already latched previous isntr
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rs2_addr_i, // already latched previous isntr
    input logic [0:0] id_ex_rs1_used_i,
    input logic [0:0] id_ex_rs2_used_i,
    input logic [$clog2(DEPTH_P)-1:0] id_ex_rd_addr_i,
    input logic [0:0] id_ex_reg_write_i,
    input logic [0:0] id_ex_mem_read_i,
    input logic [1:0] id_ex_wb_sel_i,

    // mem interface
    input logic [0:0] ex_mem_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] ex_mem_rd_addr_i,
    input logic [0:0] ex_mem_reg_write_i,
    input logic [1:0] ex_mem_wb_sel_i,

    // wb interface
    input logic [0:0] mem_wb_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] mem_wb_rd_addr_i,
    input logic [0:0] mem_wb_reg_write_i,
    input logic [0:0] pending_load_valid_i,
    input logic [$clog2(DEPTH_P)-1:0] pending_load_rd_addr_i,

    // hazard output
    output logic [0:0] if_id_stall_o,
    output logic [0:0] id_ex_bubble_o,
    output logic [1:0] id_ex_rs1_fwd_sel_o,
    output logic [1:0] id_ex_rs2_fwd_sel_o
);

    always_comb begin
        if_id_stall_o = 1'b0;
        id_ex_bubble_o = 1'b0;
        id_ex_rs1_fwd_sel_o = 2'd0;
        id_ex_rs2_fwd_sel_o = 2'd0;

        // load hazard: covers the initial load-use cycle (load in id/ex, pending not set yet)
        // and all subsequent cycles while the load is in flight (pending set, not yet written back).
        if (if_id_valid_i) begin
            if ((id_ex_valid_i && id_ex_reg_write_i && id_ex_mem_read_i && id_ex_rd_addr_i != '0 && (rs1_used_i && id_ex_rd_addr_i == rs1_addr_i || rs2_used_i && id_ex_rd_addr_i == rs2_addr_i)) || (pending_load_valid_i && pending_load_rd_addr_i != '0&& (rs1_used_i && pending_load_rd_addr_i == rs1_addr_i || rs2_used_i && pending_load_rd_addr_i == rs2_addr_i))) begin
                if_id_stall_o = 1'b1;
                id_ex_bubble_o = 1'b1;
            end
        end

        // ex/mem forwarding: instruction in EX/MEM is valid and writes a register.
        if (ex_mem_valid_i && ex_mem_reg_write_i && (ex_mem_wb_sel_i != pkg::WB_MEM)) begin
            // ID/EX instruction uses rs1, EX/MEM destination is not x0, and EX/MEM destination matches ID/EX rs1.
            if (id_ex_rs1_used_i && ex_mem_rd_addr_i != 0 && ex_mem_rd_addr_i == id_ex_rs1_addr_i) begin
                id_ex_rs1_fwd_sel_o = 2'd1;
            end
            // ID/EX instruction uses rs2, EX/MEM destination is not x0, and EX/MEM destination matches ID/EX rs2.
            if (id_ex_rs2_used_i && ex_mem_rd_addr_i != 0 && ex_mem_rd_addr_i == id_ex_rs2_addr_i) begin
                id_ex_rs2_fwd_sel_o = 2'd1;
            end
        end

        // mem/wb forwarding: instruction in MEM/WB is valid and writes a register.
        if (mem_wb_valid_i && mem_wb_reg_write_i) begin
            // ID/EX instruction uses rs1, MEM/WB destination is not x0, MEM/WB destination matches ID/EX rs1, and EX/MEM was not already selected.
            if (id_ex_rs1_used_i && mem_wb_rd_addr_i != 0 && mem_wb_rd_addr_i == id_ex_rs1_addr_i && id_ex_rs1_fwd_sel_o == 2'd0) begin
                id_ex_rs1_fwd_sel_o = 2'd2;
            end
            // ID/EX instruction uses rs2, MEM/WB destination is not x0, MEM/WB destination matches ID/EX rs2, and EX/MEM was not already selected.
            if (id_ex_rs2_used_i && mem_wb_rd_addr_i != 0 && mem_wb_rd_addr_i == id_ex_rs2_addr_i && id_ex_rs2_fwd_sel_o == 2'd0) begin
                id_ex_rs2_fwd_sel_o = 2'd2;
            end
        end
    end

endmodule