SIM ?= icarus
TOPLEVEL_LANG ?= verilog

FILELIST_JSON := filelist.json

FILELIST_SOURCES := $(shell python3 -c "import json; \
    j=json.load(open('$(FILELIST_JSON)')); \
    print(' '.join(j['files']))")

VERILOG_SOURCES := $(FILELIST_SOURCES)

TOPLEVEL := $(shell python3 -c "import json; \
    print(json.load(open('$(FILELIST_JSON)'))['top'])")
	
MODULE := branch_target_buffer_test

COCOTB_LOG_LEVEL ?= INFO

COMPILE_ARGS += -g2012

WAVES ?= 1

ifneq ($(filter lint clean,$(MAKECMDGOALS)),)
    # skip cocotb include for non-cocotb targets
else
include $(shell cocotb-config --makefile)/Makefile.sim
endif

.PHONY: clean
clean::
	rm -rf sim_build __pycache__ .pytest_cache *.pyc *.vcd *.fst results.xml sim_sv

lint:
	verilator --lint-only $(FILELIST_SOURCES) --top-module $(TOPLEVEL)

.PHONY: python
python: SIM=icarus
python: clean
	$(MAKE) MODULE=$(MODULE)
