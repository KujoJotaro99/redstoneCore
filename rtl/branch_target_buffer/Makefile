SIM ?= icarus
TOPLEVEL_LANG ?= verilog

FILELIST_JSON := filelist.json

RTL_SOURCES := $(shell python3 -c "import json; \
    j=json.load(open('$(FILELIST_JSON)')); \
    print(' '.join(j['files']))")

TOPLEVEL := $(shell python3 -c "import json; \
    print(json.load(open('$(FILELIST_JSON)'))['top'])")
	
MODULE := branch_target_buffer_test

COCOTB_LOG_LEVEL ?= INFO

COMPILE_ARGS += -g2012

WAVES ?= 1

include $(shell cocotb-config --makefile)/Makefile.sim

.PHONY: clean
clean::
	rm -rf sim_build __pycache__ .pytest_cache *.pyc *.vcd *.fst results.xml sim_sv

lint:
	verilator --lint-only $(RTL_SOURCES) --top-module $(TOPLEVEL)

.PHONY: python
python: SIM=icarus
python: clean
	$(MAKE) MODULE=$(MODULE)
