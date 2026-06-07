#ifndef RISCV_ARCH_TEST_H
#define RISCV_ARCH_TEST_H

#ifndef TEST_COMPLIANCE
#error "TEST_COMPLIANCE must be defined for compliance_I builds"
#endif

#define SIG_STRIDE 4
#define REGWIDTH 4
#define ALIGNSZ 4
#define RVTEST_WORD_PTR .word

#define LA(_REG, _SYM) la _REG, _SYM
#define LI(_REG, _IMM) li _REG, _IMM
#define LREG lw
#define SREG sw

#define RVTEST_BEGIN \
    .section .text.init; \
    .global rvtest_entry_point; \
rvtest_entry_point:; \
    LA(x2, rvtest_sig_begin); \
    LA(x3, rvtest_data_begin); \
    j rvtest_code_begin; \
    .section .text.rvtest; \
    .global rvtest_code_begin; \
rvtest_code_begin:

#define RVTEST_CODE_END \
    .section .text.rvtest; \
    .global rvtest_code_end; \
rvtest_code_end:; \
    j rvtest_code_end

#define RVTEST_DATA_BEGIN \
    .data; \
    .align 4; \
scratch:; \
    .space 512; \
    .align 4; \
    .global rvtest_data_begin; \
rvtest_data_begin:

#define RVTEST_DATA_END \
    .align 4; \
    .global rvtest_data_end; \
rvtest_data_end:

#define RVTEST_SIG_SETUP \
    .data; \
    .align 4; \
    .global begin_signature; \
begin_signature:; \
    .global rvtest_sig_begin; \
rvtest_sig_begin:; \
    .fill SIGUPD_COUNT,4,0xdeadbeef; \
    .global rvtest_sig_end; \
rvtest_sig_end:; \
    .global end_signature; \
end_signature:

#define RVTEST_TESTDATA_LOAD_INT(_DATA_PTR, _DEST_REG) \
    LREG _DEST_REG, 0(_DATA_PTR); \
    addi _DATA_PTR, _DATA_PTR, SIG_STRIDE

#define RVTEST_SIGUPD(_SIG_PTR, _LINK_REG, _TEMP_REG, _R, _INST_PTR, _STR_PTR) \
    SREG _R, 0(_SIG_PTR); \
    addi _SIG_PTR, _SIG_PTR, SIG_STRIDE

#endif
