`timescale 1ns/1ps

module decode
#(
    parameter WIDTH_P = 32
) (
    input logic [0:0] instr_valid_i,
    input logic [WIDTH_P-1:0] instr_i,

    output logic [2:0] id_ex_funct3_o,
    output logic [0:0] id_ex_rs1_used_o,
    output logic [0:0] id_ex_rs2_used_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rs1_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rs2_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] id_ex_rd_addr_o,
    output logic [WIDTH_P-1:0] id_ex_imm_o,
    output logic [3:0] id_ex_alu_op_o,
    output logic [1:0] id_ex_alu_src_a_sel_o,
    output logic [1:0] id_ex_alu_src_b_sel_o,
    output logic [1:0] id_ex_wb_sel_o,
    output logic [0:0] id_ex_reg_write_o,
    output logic [0:0] id_ex_mem_read_o,
    output logic [0:0] id_ex_mem_write_o,
    output logic [0:0] id_ex_branch_o,
    output logic [0:0] id_ex_jal_o,
    output logic [0:0] id_ex_jalr_o,
    output logic [2:0] id_ex_branch_type_o,
    output logic [0:0] id_ex_instr_illegal_o

);

    pkg::instr_fields_t instr_fields_w;
    logic [6:0] funct7_w;
    logic [4:0] rs2_w;
    logic [4:0] rs1_w;
    logic [2:0] funct3_w;
    logic [4:0] rd_w;
    logic [6:0] opcode_w;
    logic [WIDTH_P-1:0] imm_i_w;
    logic [WIDTH_P-1:0] imm_s_w;
    logic [WIDTH_P-1:0] imm_b_w;
    logic [WIDTH_P-1:0] imm_u_w;
    logic [WIDTH_P-1:0] imm_j_w;

    assign instr_fields_w = instr_i;
    assign funct7_w = instr_fields_w.funct7;
    assign rs2_w = instr_fields_w.rs2;
    assign rs1_w = instr_fields_w.rs1;
    assign funct3_w = instr_fields_w.funct3;
    assign rd_w = instr_fields_w.rd;
    assign opcode_w = instr_fields_w.opcode;

    assign id_ex_funct3_o = funct3_w;
    assign id_ex_rs1_addr_o = rs1_w;
    assign id_ex_rs2_addr_o = rs2_w;
    assign id_ex_rd_addr_o = rd_w;
    assign imm_i_w = {{20{funct7_w[6]}}, funct7_w, rs2_w};
    assign imm_s_w = {{20{funct7_w[6]}}, funct7_w, rd_w};
    assign imm_b_w = {{19{funct7_w[6]}}, funct7_w[6], rd_w[0], funct7_w[5:0], rd_w[4:1], 1'b0};
    assign imm_u_w = {funct7_w, rs2_w, rs1_w, funct3_w, 12'b0};
    assign imm_j_w = {{11{funct7_w[6]}}, funct7_w[6], rs1_w, funct3_w, rs2_w[0], funct7_w[5:0], rs2_w[4:1], 1'b0};

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
            case (opcode_w)
                pkg::OPCODE_ARITHMETIC: begin // r-type
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    case (funct3_w)
                        pkg::ALU_FUNCT3_ADD_SUB: begin
                            id_ex_instr_illegal_o = ~((funct7_w == 7'b0000000) | (funct7_w == 7'b0100000));
                            id_ex_alu_op_o = (funct7_w == 7'b0100000) ? pkg::ALU_SUB : pkg::ALU_ADD;
                        end
                        pkg::ALU_FUNCT3_SLL: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLL;
                        end
                        pkg::ALU_FUNCT3_SLT: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLT;
                        end
                        pkg::ALU_FUNCT3_SLTU: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLTU;
                        end
                        pkg::ALU_FUNCT3_XOR: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_XOR;
                        end
                        pkg::ALU_FUNCT3_SRL_SRA: begin
                            id_ex_instr_illegal_o = ~((funct7_w == 7'b0000000) | (funct7_w == 7'b0100000));
                            id_ex_alu_op_o = (funct7_w == 7'b0100000) ? pkg::ALU_SRA : pkg::ALU_SRL;
                        end
                        pkg::ALU_FUNCT3_OR: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_OR;
                        end
                        pkg::ALU_FUNCT3_AND: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_AND;
                        end
                        default: id_ex_instr_illegal_o = 1'b1;
                    endcase
                end

                pkg::OPCODE_ARITHMETIC_IMM: begin // i-type alu
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    case (funct3_w)
                        pkg::ALU_FUNCT3_ADD_SUB: id_ex_alu_op_o = pkg::ALU_ADD;
                        pkg::ALU_FUNCT3_SLL: begin
                            id_ex_instr_illegal_o = ~(funct7_w == 7'b0000000);
                            id_ex_alu_op_o = pkg::ALU_SLL;
                        end
                        pkg::ALU_FUNCT3_SLT: id_ex_alu_op_o = pkg::ALU_SLT;
                        pkg::ALU_FUNCT3_SLTU: id_ex_alu_op_o = pkg::ALU_SLTU;
                        pkg::ALU_FUNCT3_XOR: id_ex_alu_op_o = pkg::ALU_XOR;
                        pkg::ALU_FUNCT3_SRL_SRA: begin
                            id_ex_instr_illegal_o = ~((funct7_w == 7'b0000000) | (funct7_w == 7'b0100000));
                            id_ex_alu_op_o = (funct7_w == 7'b0100000) ? pkg::ALU_SRA : pkg::ALU_SRL;
                        end
                        pkg::ALU_FUNCT3_OR: id_ex_alu_op_o = pkg::ALU_OR;
                        pkg::ALU_FUNCT3_AND: id_ex_alu_op_o = pkg::ALU_AND;
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
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_wb_sel_o = pkg::WB_MEM;
                    id_ex_instr_illegal_o = ~((funct3_w == pkg::LOAD_LB) | (funct3_w == pkg::LOAD_LH) | (funct3_w == pkg::LOAD_LW) | (funct3_w == pkg::LOAD_LBU) | (funct3_w == pkg::LOAD_LHU));
                end

                pkg::OPCODE_STORE: begin // store
                    id_ex_mem_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_instr_illegal_o = ~((funct3_w == pkg::STORE_SB) | (funct3_w == pkg::STORE_SH) | (funct3_w == pkg::STORE_SW));
                end

                pkg::OPCODE_BRANCH: begin // branch
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_rs2_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_SUB;
                    id_ex_branch_o = 1'b1;
                    id_ex_branch_type_o = funct3_w;
                    id_ex_instr_illegal_o = ~((funct3_w == pkg::BRANCH_BEQ) | (funct3_w == pkg::BRANCH_BNE) | (funct3_w == pkg::BRANCH_BLT) | (funct3_w == pkg::BRANCH_BGE) | (funct3_w == pkg::BRANCH_BLTU) | (funct3_w == pkg::BRANCH_BGEU));
                end

                pkg::OPCODE_JAL: begin // jal
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_a_sel_o = pkg::ALU_A_PC;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_jal_o = 1'b1;
                    id_ex_wb_sel_o = pkg::WB_PC4;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_LUI: begin // lui
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_PASS;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_AUIPC: begin // auipc
                    id_ex_reg_write_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_a_sel_o = pkg::ALU_A_PC;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_instr_illegal_o = 1'b0;
                end

                pkg::OPCODE_JALR: begin // jalr
                    id_ex_reg_write_o = 1'b1;
                    id_ex_rs1_used_o = 1'b1;
                    id_ex_alu_op_o = pkg::ALU_ADD;
                    id_ex_alu_src_b_sel_o = pkg::ALU_B_IMM;
                    id_ex_jalr_o = 1'b1;
                    id_ex_wb_sel_o = pkg::WB_PC4;
                    id_ex_instr_illegal_o = ~(funct3_w == pkg::ALU_FUNCT3_ADD_SUB);
                end

                pkg::OPCODE_SYSTEM: begin // system
                    id_ex_instr_illegal_o = 1'b1; // under construction for now
                end

                default: begin
                    id_ex_instr_illegal_o = 1'b1;
                end
            endcase
        end
    end

    // immediate generation
    always_comb begin
        case (opcode_w)
        // i-type
            pkg::OPCODE_ARITHMETIC_IMM, pkg::OPCODE_LOAD, pkg::OPCODE_JALR:
                id_ex_imm_o = imm_i_w;

            // s-type
            pkg::OPCODE_STORE: 
                id_ex_imm_o = imm_s_w;

            // b-type
            pkg::OPCODE_BRANCH: 
                id_ex_imm_o = imm_b_w;

            // u-type
            pkg::OPCODE_LUI, pkg::OPCODE_AUIPC: 
                id_ex_imm_o = imm_u_w;

            // j-type
            pkg::OPCODE_JAL: 
                id_ex_imm_o = imm_j_w;

            default: 
                id_ex_imm_o = '0;
        endcase
    end

endmodule
