`timescale 1ns/1ps

package pkg;

    // Instruction Fields unpacking struct
    typedef struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } instr_fields_t;

    // Opcode definitions
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

    // ALU op selection
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

    // ALU funct3 mappings
    typedef enum logic [2:0] {
        ALU_FUNCT3_ADD_SUB = 3'b000,
        ALU_FUNCT3_SLL = 3'b001,
        ALU_FUNCT3_SLT = 3'b010,
        ALU_FUNCT3_SLTU = 3'b011,
        ALU_FUNCT3_XOR = 3'b100,
        ALU_FUNCT3_SRL_SRA = 3'b101,
        ALU_FUNCT3_OR = 3'b110,
        ALU_FUNCT3_AND = 3'b111
    } alu_funct3_e;

    // Register file writeback mux selection
    typedef enum logic [1:0] {
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC4 = 2'd2
    } wb_sel_e;

    // Branch condition types (funct3 mappings)
    typedef enum logic [2:0] {
        BRANCH_BEQ  = 3'b000,
        BRANCH_BNE  = 3'b001,
        BRANCH_BLT  = 3'b100,
        BRANCH_BGE  = 3'b101,
        BRANCH_BLTU = 3'b110,
        BRANCH_BGEU = 3'b111
    } branch_type_e;

    // Load type widths (funct3 mappings)
    typedef enum logic [2:0] {
        LOAD_LB  = 3'b000,
        LOAD_LH  = 3'b001,
        LOAD_LW  = 3'b010,
        LOAD_LBU = 3'b100,
        LOAD_LHU = 3'b101
    } load_type_e;

    // Store type widths (funct3 mappings)
    typedef enum logic [2:0] {
        STORE_SB = 3'b000,
        STORE_SH = 3'b001,
        STORE_SW = 3'b010
    } store_type_e;

    // ALU Source Operand A Mux Selection
    typedef enum logic [1:0] {
        ALU_A_RS1 = 2'd0,
        ALU_A_PC = 2'd1,
        ALU_A_ZERO = 2'd2
    } alu_src_a_e;

    // ALU Source Operand B Mux Selection
    typedef enum logic {
        ALU_B_RS2 = 1'b0,
        ALU_B_IMM = 1'b1
    } alu_src_b_e;

endpackage
