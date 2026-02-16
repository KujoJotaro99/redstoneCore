`timescale 1ns/1ps

package pkg;

    typedef struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instr_fields_t;

    typedef enum logic [6:0] {
        OPCODE_LOAD = 7'b0000011,
        OPCODE_STORE = 7'b0100011,
        OPCODE_ARITHMETIC_IMM = 7'b0010011,
        OPCODE_ARITHMETIC = 7'b0110011,
        OPCODE_BRANCH = 7'b1100011,
        OPCODE_JALR = 7'b1100111,
        OPCODE_JAL = 7'b1101111,
        OPCODE_LUI = 7'b0110111,
        OPCODE_AUIPC = 7'b0010111,
        OPCODE_SYSTEM = 7'b1110011
    } opcode_e;

    typedef enum logic [3:0] {
        ALU_ADD = 4'd0,
        ALU_SUB = 4'd1,
        ALU_SLL = 4'd2,
        ALU_SLT = 4'd3,
        ALU_SLTU = 4'd4,
        ALU_XOR = 4'd5,
        ALU_SRL = 4'd6,
        ALU_SRA = 4'd7,
        ALU_OR = 4'd8,
        ALU_AND = 4'd9,
        ALU_PASS = 4'd10
    } alu_op_e;

    typedef enum logic [1:0] {
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC4 = 2'd2
    } wb_sel_e;

endpackage
