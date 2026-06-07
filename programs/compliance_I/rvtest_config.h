#ifndef RVTEST_CONFIG_H
#define RVTEST_CONFIG_H

#ifndef TEST_COMPLIANCE
#error "TEST_COMPLIANCE must be defined for compliance_I builds"
#endif

#define UDB_MXLEN 32
#define UDB_MXLEN_32
#define UDB_NUM_PMP_ENTRIES 0
#define UDB_MTVEC_MODES_0
#define UDB_MTVEC_BASE_ALIGNMENT_DIRECT 4
#define UDB_MTVEC_BASE_ALIGNMENT_VECTORED 4

#endif
