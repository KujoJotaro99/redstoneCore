SIM ?= icarus
TOPLEVEL_LANG ?= verilog

FILELIST_JSON := filelist.json

FILELIST_SOURCES := $(shell python3 -c "import json; print(' '.join(json.load(open('$(FILELIST_JSON)'))['files']))")
TOPLEVEL := $(shell python3 -c "import json; print(json.load(open('$(FILELIST_JSON)'))['top'])")

VERILOG_SOURCES := $(FILELIST_SOURCES)

MODULE := decode_test

COCOTB_LOG_LEVEL ?= INFO
SIM_BUILD ?= sim_build
WAVES ?= 1

ifeq ($(SIM),verilator)
    ifeq ($(WAVES),1)
        COMPILE_ARGS += --trace --trace-structs --trace-fst
        SIM_ARGS += --trace --trace-file $(SIM_BUILD)/$(TOPLEVEL).fst
    endif
    COMPILE_ARGS += --sv
else ifeq ($(SIM),icarus)
    COMPILE_ARGS += -g2012
else
    $(error unsupported SIM=$(SIM), use SIM=verilator or SIM=icarus)
endif

.PHONY: python lint clean

python: clean
	$(MAKE) results.xml MODULE=$(MODULE)

lint:
	verilator --lint-only -Wall --sv $(FILELIST_SOURCES) --top-module $(TOPLEVEL)

clean::
	rm -rf sim_build __pycache__ .pytest_cache
	rm -f *.pyc *.vcd *.fst results.xml

ifneq ($(filter lint clean,$(MAKECMDGOALS)),)
    # skip cocotb include for non-cocotb targets
else
include $(shell cocotb-config --makefile)/Makefile.sim
endif
