#ifndef RVMODEL_MACROS_H
#define RVMODEL_MACROS_H

#ifndef TEST_COMPLIANCE
#error "TEST_COMPLIANCE must be defined for compliance_I builds"
#endif

#define RVMODEL_DATA_SECTION \
    .align 4;

#define RVMODEL_HALT_PASS \
    j .

#define RVMODEL_HALT_FAIL \
    j .

#define RVMODEL_IO_WRITE_STR(_SP, _A0, _A1, _STR) \
    nop

#define RVMODEL_INTERRUPT_LATENCY 0
#define RVMODEL_TIMER_INT_SOON_DELAY 0

#define RVMODEL_SET_MEXT_INT(_A, _B) nop
#define RVMODEL_CLR_MEXT_INT(_A, _B) nop
#define RVMODEL_SET_MSW_INT(_A, _B) nop
#define RVMODEL_CLR_MSW_INT(_A, _B) nop
#define RVMODEL_SET_SEXT_INT(_A, _B) nop
#define RVMODEL_CLR_SEXT_INT(_A, _B) nop
#define RVMODEL_SET_SSW_INT(_A, _B) nop
#define RVMODEL_CLR_SSW_INT(_A, _B) nop

#endif
