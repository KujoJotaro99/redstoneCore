SIM ?= verilator
TOPLEVEL_LANG ?= verilog

FILELIST_JSON := filelist.json

FILELIST_SOURCES := $(shell python3 -c "import json; print(' '.join(json.load(open('$(FILELIST_JSON)'))['files']))")
TOPLEVEL := $(shell python3 -c "import json; print(json.load(open('$(FILELIST_JSON)'))['top'])")

VERILOG_SOURCES := $(FILELIST_SOURCES)

COCOTB_TEST_MODULES := top_test

COCOTB_LOG_LEVEL ?= INFO
SIM_BUILD ?= sim_build
WAVES ?= 1
VERILATOR_WARNING_ARGS ?= -Wno-lint -Wno-style
TEST ?= add_two add_loop bitwise shift compare load_store sub_wrap immediate_ops branch_matrix function_call signed_load store_mask nested_loop dependency_chain bubble_sort binary_search prefix_sum
COMPLIANCE_REFERENCE ?= python

# Auto-discover all custom test dirs
CUSTOM_TESTS := $(shell ls -d ../../programs/rv32i/*/ 2>/dev/null | xargs -I {} basename {} | grep -v -E 'Makefile|link.ld|^\.' | tr '\n' ' ')

# Auto-discover all compliance test dirs
COMPLIANCE_TESTS := $(shell ls -d ../../programs/compliance_I/I-*/ 2>/dev/null | xargs -I {} basename {})

RAM_ADDR_WIDTH_P ?= 16
DMEM_RAM_BASE_P ?= 4096
VERILATOR_FATAL_WARNINGS ?= 0

ifeq ($(SIM),verilator)
    ifeq ($(WAVES),1)
        COMPILE_ARGS += --trace
        SIM_ARGS += --trace --trace-file $(SIM_BUILD)/$(TOPLEVEL).vcd
    endif
    ifeq ($(VERILATOR_FATAL_WARNINGS),0)
        COMPILE_ARGS += -Wno-fatal
    endif
    COMPILE_ARGS += $(VERILATOR_WARNING_ARGS) --sv -GRAM_ADDR_WIDTH_P=$(RAM_ADDR_WIDTH_P) -GDMEM_RAM_BASE_P=$(DMEM_RAM_BASE_P)
else
    $(error rtl/top only supports SIM=verilator)
endif

.PHONY: python python_one CUSTOM COMPLIANCE_I lint clean

python:
	@failures=""; \
	for test in $(TEST); do \
		echo "TEST_NAME=$$test"; \
		$(MAKE) python_one TEST_NAME=$$test || failures="$$failures $$test"; \
	done; \
	if [ -n "$$failures" ]; then \
		echo "FAILED:$$failures"; \
		exit 1; \
	fi

python_one: clean
	$(MAKE) results.xml MODULE=$(MODULE)

CUSTOM:
	@failures=""; \
	for test in $(CUSTOM_TESTS); do \
		echo "TEST_NAME=$$test"; \
		$(MAKE) python_one TEST_NAME=$$test || failures="$$failures $$test"; \
	done; \
	if [ -n "$$failures" ]; then \
		echo "FAILED:$$failures"; \
		exit 1; \
	fi

COMPLIANCE_I:
	@failures=""; \
	for test in $(COMPLIANCE_TESTS); do \
		echo "TEST_COMPLIANCE=1 TEST_NAME=$$test"; \
		$(MAKE) python_one TEST_COMPLIANCE=1 TEST_NAME=$$test RAM_ADDR_WIDTH_P=20 DMEM_RAM_BASE_P=524288 DMEM_BASE=524288 RUN_CYCLES=250000 || failures="$$failures $$test"; \
	done; \
	if [ -n "$$failures" ]; then \
		echo "FAILED:$$failures"; \
		exit 1; \
	fi

lint:
	verilator --lint-only -Wall $(VERILATOR_WARNING_ARGS) --sv $(FILELIST_SOURCES) --top-module $(TOPLEVEL)

clean::
	rm -rf sim_build __pycache__ .pytest_cache
	rm -f *.pyc *.vcd *.fst results.xml

ifneq ($(filter lint clean,$(MAKECMDGOALS)),)
    # skip cocotb include for non-cocotb targets
else
include $(shell cocotb-config --makefile)/Makefile.sim
endif
