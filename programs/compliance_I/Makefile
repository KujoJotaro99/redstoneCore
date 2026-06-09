RISCV_PREFIX ?= riscv64-unknown-elf
CC := $(RISCV_PREFIX)-gcc
OBJCOPY := $(RISCV_PREFIX)-objcopy
OBJDUMP := $(RISCV_PREFIX)-objdump
SIZE := $(RISCV_PREFIX)-size

TEST_COMPLIANCE ?= 1
PURE_RV32I_HARNESS ?= 1
REFERENCE_MODEL ?= python
SAIL_SIM ?= /opt/sail-riscv/bin/sail_riscv_sim
SAIL_ARGS ?=
TESTS := $(patsubst %/program.S,%,$(wildcard I-*/program.S))

ARCH_FLAGS := -march=rv32i -mabi=ilp32
ifeq ($(PURE_RV32I_HARNESS),1)
    HARNESS_INCLUDE := -Ipure_env
else
    ARCH_FLAGS := -march=rv32i_zicsr_zifencei -mabi=ilp32
endif
COMMON_FLAGS := $(ARCH_FLAGS) -DTEST_COMPLIANCE=$(TEST_COMPLIANCE) -DTEST_FLEN=32 -I. $(HARNESS_INCLUDE)
ASFLAGS := $(COMMON_FLAGS) -x assembler-with-cpp
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -Wl,--no-relax -T link.ld

ELFS := $(addsuffix /program.elf,$(TESTS))
IMEM_BINS := $(addsuffix /program_imem.bin,$(TESTS))
DMEM_BINS := $(addsuffix /program_dmem.bin,$(TESTS))
IMEM_MEMS := $(addsuffix /program_imem.mem,$(TESTS))
DMEM_MEMS := $(addsuffix /program_dmem.mem,$(TESTS))
DUMPS := $(addsuffix /program.dump,$(TESTS))
MAPS := $(addsuffix /program.map,$(TESTS))
SIGNATURES := $(addsuffix /expected_signature.mem,$(TESTS))

.PHONY: all clean list FORCE
.SECONDARY:

all: $(ELFS) $(IMEM_BINS) $(DMEM_BINS) $(IMEM_MEMS) $(DMEM_MEMS) $(DUMPS) $(SIGNATURES)

list:
	@printf '%s ' $(TESTS)
	@printf '\n'

%/program.elf: %/program.S link.ld rvtest_config.h rvmodel_macros.h
	$(CC) $(ASFLAGS) $(LDFLAGS) -Wl,-Map=$*/program.map $< -o $@
	$(SIZE) $@

%/program_imem.bin: %/program.elf
	$(OBJCOPY) -O binary --only-section=.text $< $@

%/program_dmem.bin: %/program.elf
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data $< $@

%.mem: %.bin
	od -An -v -tx4 -w4 $< | awk '{print $$1}' > $@

%/program.dump: %/program.elf
	$(OBJDUMP) -d -s $< > $@

%/program.map: %/program.elf
	@true

%/expected_signature.mem: %/program_imem.mem %/program_dmem.mem %/program.map generate_expected.py generate_sail_expected.py FORCE
ifeq ($(REFERENCE_MODEL),sail)
	python3 generate_sail_expected.py $* --sail-sim $(SAIL_SIM) --sail-args '$(SAIL_ARGS)'
else
	python3 generate_expected.py $*
endif

clean:
	rm -f $(ELFS) $(IMEM_BINS) $(DMEM_BINS) $(IMEM_MEMS) $(DMEM_MEMS) $(DUMPS) $(MAPS) $(SIGNATURES)
