`timescale 1ns/1ps

module decode
#(
    parameter WIDTH_P = 32
) (
    input logic [0:0] instr_valid_i,
    input logic [WIDTH_P-1:0] instr_i,

    output logic [6:0] id_ex_opcode_o,
    output logic [2:0] id_ex_funct3_o,
    output logic [6:0] id_ex_funct7_o,
    output logic [0:0] id_ex_rs1_used_o,
    output logic [0:0] id_ex_rs2_used_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rs1_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rs2_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rd_addr_o,
    output logic [WIDTH_P-1:0] id_ex_imm_o,
    output logic [3:0] id_ex_alu_op_o,
    output logic [1:0] id_ex_alu_src_a_sel_o,
    output logic [1:0] id_ex_alu_src_b_sel_o,
    output logic [0:0] id_ex_reg_write_o,
    output logic [0:0] id_ex_mem_read_o,
    output logic [0:0] id_ex_mem_write_o,
    output logic [0:0] id_ex_instr_illegal_o,
    output logic [0:0] id_ex_branch_o,
    output logic [0:0] id_ex_jal_o,
    output logic [0:0] id_ex_jalr_o,
    output logic [2:0] id_ex_branch_type_o,
    output logic [1:0] id_ex_wb_sel_o
);

    pkg::instr_fields_t instr_fields_w;

    assign instr_fields_w = instr_i;
    assign id_ex_opcode_o = instr_fields_w.opcode;
    assign id_ex_funct3_o = instr_fields_w.funct3;
    assign id_ex_funct7_o = instr_fields_w.funct7;
    assign id_ex_rs1_addr_o = instr_fields_w.rs1;
    assign id_ex_rs2_addr_o = instr_fields_w.rs2;
    assign id_ex_rd_addr_o = instr_fields_w.rd;

    always_comb begin
        id_ex_instr_illegal_o = 1'b0;
        id_ex_rs1_used_o = 1'b0;
        id_ex_rs2_used_o = 1'b0;
        id_ex_alu_op_o = 4'd0;
        id_ex_alu_src_a_sel_o = 2'd0;
        id_ex_alu_src_b_sel_o = 2'd0;
        id_ex_reg_write_o = 1'b0;
        id_ex_mem_read_o = 1'b0;
        id_ex_mem_write_o = 1'b0;
        id_ex_branch_o = 1'b0;
        id_ex_jal_o = 1'b0;
        id_ex_jalr_o = 1'b0;
        id_ex_branch_type_o = 3'd0;
        id_ex_wb_sel_o = pkg::WB_ALU;

        if (instr_valid_i) begin
            case (id_ex_opcode_o)
                pkg::OPCODE_ARITHMETIC: begin // r-type
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    case (instr_fields_w.funct3)
                        3'b000: begin
                            id_ex_instr_illegal_o = ~((instr_fields_w.funct7 == 7'b0000000) | (instr_fields_w.funct7 == 7'b0100000));
                            id_ex_alu_op_o = (instr_fields_w.funct7 == 7'b0100000) ? pkg::ALU_SUB : pkg::ALU_ADD;
                        end
                        3'b001: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLL;
                        end
                        3'b010: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLT;
                        end
                        3'b011: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLTU;
                        end
                        3'b100: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_XOR;
                        end
                        3'b101: begin
                            id_ex_instr_illegal_o = ~((instr_fields_w.funct7 == 7'b0000000) | (instr_fields_w.funct7 == 7'b0100000));
                            id_ex_alu_op_o = (instr_fields_w.funct7 == 7'b0100000) ? pkg::ALU_SRA : pkg::ALU_SRL;
                        end
                        3'b110: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_OR;
                        end
                        3'b111: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_AND;
                        end
                        default: id_ex_instr_illegal_o = 1'b1;
                    endcase
                end

                pkg::OPCODE_ARITHMETIC_IMM: begin // i-type alu
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    case (instr_fields_w.funct3)
                        3'b000: id_ex_alu_op_o = pkg::ALU_ADD;
                        3'b001: begin
                            id_ex_instr_illegal_o = ~(instr_fields_w.funct7 == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLL;
                        end
                        3'b010: id_ex_alu_op_o = pkg::ALU_SLT;
                        3'b011: id_ex_alu_op_o = pkg::ALU_SLTU;
                        3'b100: id_ex_alu_op_o = pkg::ALU_XOR;
                        3'b101: begin
                            id_ex_instr_illegal_o = ~((instr_fields_w.funct7 == 7'b0000000) | (instr_fields_w.funct7 == 7'b0100000));
                            id_ex_alu_op_o = (instr_fields_w.funct7 == 7'b0100000) ? pkg::ALU_SRA : pkg::ALU_SRL;
                        end
                        3'b110: id_ex_alu_op_o = pkg::ALU_OR;
                        3'b111: id_ex_alu_op_o = pkg::ALU_AND;
                        default: begin
                            id_ex_instr_illegal_o = 1'b0;
                        end
                    endcase
                end

                pkg::OPCODE_LOAD: begin // load
                    id_ex_reg_write_o = 1'b1;
                    id_ex_mem_read_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_wb_sel_o = pkg::WB_MEM;
                    id_ex_instr_illegal_o = ~((instr_fields_w.funct3 == 3'b000) | (instr_fields_w.funct3 == 3'b001) | (instr_fields_w.funct3 == 3'b010) | (instr_fields_w.funct3 == 3'b100) | (instr_fields_w.funct3 == 3'b101));
                end

                pkg::OPCODE_STORE: begin // store
                    id_ex_mem_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_instr_illegal_o = ~((instr_fields_w.funct3 == 3'b000) | (instr_fields_w.funct3 == 3'b001) | (instr_fields_w.funct3 == 3'b010));
                end

                pkg::OPCODE_BRANCH: begin // branch
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_SUB;
                    id_ex_branch_o = 1'b1;
                    id_ex_branch_type_o = instr_fields_w.funct3;
                    id_ex_instr_illegal_o = ~((instr_fields_w.funct3 == 3'b000) | (instr_fields_w.funct3 == 3'b001) | (instr_fields_w.funct3 == 3'b100) | (instr_fields_w.funct3 == 3'b101) | (instr_fields_w.funct3 == 3'b110) | (instr_fields_w.funct3 == 3'b111));
                end

                pkg::OPCODE_JAL: begin // jal
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_a_sel_o = 2'd1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_jal_o = 1'b1;
                    id_ex_wb_sel_o = pkg::WB_PC4;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_LUI: begin // lui
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_PASS;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_AUIPC: begin // auipc
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_a_sel_o = 2'd1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_JALR: begin // jalr
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    id_ex_jalr_o = 1'b1;
                    id_ex_wb_sel_o = pkg::WB_PC4;
                    id_ex_instr_illegal_o = ~(instr_fields_w.funct3 == 3'b000);
                end

                pkg::OPCODE_SYSTEM: begin // system (tbd but perhaps ecall, ebreak, mret, and csr stuff)
                    id_ex_rs1_used_o = (instr_fields_w.funct3 == 3'b001) | (instr_fields_w.funct3 == 3'b010) | (instr_fields_w.funct3 == 3'b011);
                    id_ex_instr_illegal_o = ~((instr_i == 32'h00000073) | (instr_i == 32'h00100073) | (instr_i == 32'h30200073) | (instr_fields_w.funct3 != 3'b000));
                end

                default: begin
                    id_ex_instr_illegal_o = 1'b1;
                end
            endcase
        end
    end

    // immediate generation
    always_comb begin
        case (id_ex_opcode_o)
        // i-type
            pkg::OPCODE_ARITHMETIC_IMM, pkg::OPCODE_LOAD, pkg::OPCODE_JALR: 
                id_ex_imm_o = {{(WIDTH_P-12){instr_fields_w.funct7[6]}}, instr_fields_w.funct7, instr_fields_w.rs2};

            // s-type
            pkg::OPCODE_STORE: 
                id_ex_imm_o = {{(WIDTH_P-12){instr_fields_w.funct7[6]}}, instr_fields_w.funct7, instr_fields_w.rd};

            // b-type
            pkg::OPCODE_BRANCH: 
                id_ex_imm_o = {{(WIDTH_P-13){instr_fields_w.funct7[6]}}, instr_fields_w.funct7[6], instr_fields_w.rd[0], instr_fields_w.funct7[5:0], instr_fields_w.rd[4:1], 1'b0};

            // u-type
            pkg::OPCODE_LUI, pkg::OPCODE_AUIPC: 
                id_ex_imm_o = {instr_fields_w.funct7, instr_fields_w.rs2, instr_fields_w.rs1, instr_fields_w.funct3, 12'b0};

            // j-type
            pkg::OPCODE_JAL: 
                id_ex_imm_o = {{(WIDTH_P-21){instr_fields_w.funct7[6]}}, instr_fields_w.funct7[6], instr_fields_w.rs1, instr_fields_w.funct3, instr_fields_w.rs2[0], instr_fields_w.funct7[5:0], instr_fields_w.rs2[4:1], 1'b0};

            default: 
                id_ex_imm_o = '0;
        endcase
    end

endmodule
