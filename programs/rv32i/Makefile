RISCV_PREFIX ?= riscv64-unknown-elf
CC := $(RISCV_PREFIX)-gcc
OBJCOPY := $(RISCV_PREFIX)-objcopy
OBJDUMP := $(RISCV_PREFIX)-objdump

ARCH_FLAGS := -march=rv32i -mabi=ilp32
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fno-delete-null-pointer-checks -msmall-data-limit=0
CFLAGS := $(COMMON_FLAGS) -O2 -Wall -Wextra
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -Wl,--no-relax -T link.ld

C_TESTS := add_two add_loop bitwise shift compare load_store sub_wrap immediate_ops branch_matrix function_call signed_load store_mask nested_loop dependency_chain bubble_sort binary_search prefix_sum
TESTS := $(C_TESTS)

ELFS := $(addsuffix /program.elf,$(TESTS))
IMEM_BINS := $(addsuffix /program_imem.bin,$(TESTS))
DMEM_BINS := $(addsuffix /program_dmem.bin,$(TESTS))
IMEM_MEMS := $(addsuffix /program_imem.mem,$(TESTS))
DMEM_MEMS := $(addsuffix /program_dmem.mem,$(TESTS))
DUMPS := $(addsuffix /program.dump,$(TESTS))
ASMS := $(addsuffix /program.s,$(C_TESTS))

.PHONY: all clean
.SECONDARY:

all: $(ELFS) $(IMEM_BINS) $(DMEM_BINS) $(IMEM_MEMS) $(DMEM_MEMS) $(DUMPS) $(ASMS)

%/program.s: %/program.c
	$(CC) $(CFLAGS) -S $< -o $@

$(addsuffix /program.elf,$(C_TESTS)): %/program.elf: %/program.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

%/program_imem.bin: %/program.elf
	$(OBJCOPY) -O binary --only-section=.text $< $@

%/program_dmem.bin: %/program.elf
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data $< $@

%.mem: %.bin
	od -An -v -tx4 -w4 $< | awk '{print $$1}' > $@

%/program.dump: %/program.elf
	$(OBJDUMP) -d -s $< > $@

clean:
	rm -f $(ELFS) $(IMEM_BINS) $(DMEM_BINS) $(IMEM_MEMS) $(DMEM_MEMS) $(DUMPS) $(ASMS)
