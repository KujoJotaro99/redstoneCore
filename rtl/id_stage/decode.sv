`timescale 1ns/1ps

module decode
#(
    parameter WIDTH_P = 32
) (
    input logic [0:0] instr_valid_i,
    input logic [WIDTH_P-1:0] instr_i,

    output logic [6:0] opcode_o,
    output logic [2:0] funct3_o,
    output logic [6:0] funct7_o,
    output logic [0:0] rs1_used_o,
    output logic [0:0] rs2_used_o,
    output logic [$clog2(WIDTH_P)-1:0] rs1_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] rs2_addr_o,
    output logic [$clog2(WIDTH_P)-1:0] rd_addr_o,
    output logic [WIDTH_P-1:0] imm_gen_o,
    output logic [3:0] id_ex_alu_op_o,
    output logic [1:0] id_ex_alu_src_a_sel_o,
    output logic [1:0] id_ex_alu_src_b_sel_o,
    output logic [0:0] instr_illegal_o
);

    assign opcode_o = instr_i[6:0];
    assign funct3_o = instr_i[14:12];
    assign funct7_o = instr_i[31:25];
    assign rs1_addr_o = instr_i[19:15];
    assign rs2_addr_o = instr_i[24:20];
    assign rd_addr_o = instr_i[11:7];


    always_comb begin
        instr_illegal_o = 1'b0;
        rs1_used_o = 1'b0;
        rs2_used_o = 1'b0;
        id_ex_alu_op_o = 4'd0;
        id_ex_alu_src_a_sel_o = 2'd0;
        id_ex_alu_src_b_sel_o = 2'd0;

        if (instr_valid_i) begin
            case (opcode_o)
                7'b0110011: begin // r-type
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                    case (funct3_o)
                        3'b000: begin
                            instr_illegal_o = ~((funct7_o == 7'b0000000) | (funct7_o == 7'b0100000));
                            id_ex_alu_op_o = (funct7_o == 7'b0100000) ? 4'd1 : 4'd0;
                        end
                        3'b001: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd2;
                        end
                        3'b010: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd3;
                        end
                        3'b011: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd4;
                        end
                        3'b100: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd5;
                        end
                        3'b101: begin
                            instr_illegal_o = ~((funct7_o == 7'b0000000) | (funct7_o == 7'b0100000));
                            id_ex_alu_op_o = (funct7_o == 7'b0100000) ? 4'd7 : 4'd6;
                        end
                        3'b110: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd8;
                        end
                        3'b111: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd9;
                        end
                        default: instr_illegal_o = 1'b1;
                    endcase
                end

                7'b0010011: begin // i-type alu
                    rs1_used_o = 1'b1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    case (funct3_o)
                        3'b000: id_ex_alu_op_o = 4'd0;
                        3'b001: begin
                            instr_illegal_o = ~(funct7_o == 7'b0000000);
                            id_ex_alu_op_o = 4'd2;
                        end
                        3'b010: id_ex_alu_op_o = 4'd3;
                        3'b011: id_ex_alu_op_o = 4'd4;
                        3'b100: id_ex_alu_op_o = 4'd5;
                        3'b101: begin
                            instr_illegal_o = ~((funct7_o == 7'b0000000) | (funct7_o == 7'b0100000));
                            id_ex_alu_op_o = (funct7_o == 7'b0100000) ? 4'd7 : 4'd6;
                        end
                        3'b110: id_ex_alu_op_o = 4'd8;
                        3'b111: id_ex_alu_op_o = 4'd9;
                        default: begin
                            instr_illegal_o = 1'b0;
                        end
                    endcase
                end

                7'b0000011: begin // load
                    rs1_used_o = 1'b1;
                    id_ex_alu_op_o = 4'd0;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = ~((funct3_o == 3'b000) | (funct3_o == 3'b001) | (funct3_o == 3'b010) | (funct3_o == 3'b100) | (funct3_o == 3'b101));
                end

                7'b0100011: begin // store
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                    id_ex_alu_op_o = 4'd0;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = ~((funct3_o == 3'b000) | (funct3_o == 3'b001) | (funct3_o == 3'b010));
                end

                7'b1100011: begin // branch
                    rs1_used_o = 1'b1;
                    rs2_used_o = 1'b1;
                    id_ex_alu_op_o = 4'd1;
                    instr_illegal_o = ~((funct3_o == 3'b000) | (funct3_o == 3'b001) | (funct3_o == 3'b100) | (funct3_o == 3'b101) | (funct3_o == 3'b110) | (funct3_o == 3'b111));
                end

                7'b1101111: begin // jal
                    id_ex_alu_op_o = 4'd0;
                    id_ex_alu_src_a_sel_o = 2'd1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = 1'b0;
                end

                7'b0110111: begin // lui
                    id_ex_alu_op_o = 4'd10;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = 1'b0;
                end

                7'b0010111: begin // auipc
                    id_ex_alu_op_o = 4'd0;
                    id_ex_alu_src_a_sel_o = 2'd1;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = 1'b0;
                end

                7'b1100111: begin // jalr
                    rs1_used_o = 1'b1;
                    id_ex_alu_op_o = 4'd0;
                    id_ex_alu_src_b_sel_o = 2'd1;
                    instr_illegal_o = ~(funct3_o == 3'b000);
                end

                7'b1110011: begin // system (tbd but perhaps ecall, ebreak, mret, and csr stuff)
                    rs1_used_o = (funct3_o == 3'b001) | (funct3_o == 3'b010) | (funct3_o == 3'b011);
                    instr_illegal_o = ~((instr_i == 32'h00000073) | (instr_i == 32'h00100073) | (instr_i == 32'h30200073) | (funct3_o != 3'b000));
                end

                default: begin
                    instr_illegal_o = 1'b1;
                end
            endcase
        end
    end

    // immediate generation
    always_comb begin
        case (opcode_o)
        // i-type
            7'b0010011, 7'b0000011, 7'b1100111: 
                imm_gen_o = {{(WIDTH_P-12){instr_i[31]}}, instr_i[31:20]};

            // s-type
            7'b0100011: 
                imm_gen_o = {{(WIDTH_P-12){instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

            // b-type
            7'b1100011: 
                imm_gen_o = {{(WIDTH_P-13){instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};

            // u-type
            7'b0110111, 7'b0010111: 
                imm_gen_o = {instr_i[31:12], 12'b0};

            // j-type
            7'b1101111: 
                imm_gen_o = {{(WIDTH_P-21){instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};

            default: 
                imm_gen_o = '0;
        endcase
    end

endmodule
