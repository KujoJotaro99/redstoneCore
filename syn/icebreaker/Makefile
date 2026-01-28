TOP := top_synth
DEVICE := up5k
PACKAGE := sg48
FREQ ?= 25
BUILD_DIR := build
SYNTH_MEM := program.mem

RTL_SOURCES := \
	../../rtl/pkg/red_pkg.sv \
	../../submodules/imports/sync_ram_block.sv \
	../../rtl/regfile/regfile.sv \
	../../rtl/hazard_unit/hazard_unit.sv \
	../../rtl/control/control.sv \
	../../rtl/csr_file/csr_file.sv \
	../../rtl/alu/alu.sv \
	../../rtl/if_stage/if_stage.sv \
	../../rtl/id_stage/id_stage.sv \
	../../rtl/ex_stage/ex_stage.sv \
	../../rtl/mem_stage/mem_stage.sv \
	../../rtl/wb_stage/wb_stage.sv \
	../../rtl/top/top.sv \
	top_synth.sv

.PHONY: all synth yosys pnr timing clean
all: synth

synth: timing

yosys: $(BUILD_DIR)/$(TOP).json

$(SYNTH_MEM):
	awk 'BEGIN { for (i = 0; i < 256; i++) print "00000000" }' > $@

$(BUILD_DIR)/$(TOP).json: $(RTL_SOURCES) $(SYNTH_MEM)
	mkdir -p $(BUILD_DIR)
	yosys -p "read_verilog -sv $(RTL_SOURCES); synth_ice40 -top $(TOP) -json $@"

pnr: $(BUILD_DIR)/$(TOP).asc

$(BUILD_DIR)/$(TOP).asc: $(BUILD_DIR)/$(TOP).json
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --freq $(FREQ) --json $< --asc $@ --pcf-allow-unconstrained > $(BUILD_DIR)/nextpnr.log 2>&1
	cat $(BUILD_DIR)/nextpnr.log

timing: $(BUILD_DIR)/$(TOP).asc
	icetime -d $(DEVICE) -P $(PACKAGE) -mtr $(BUILD_DIR)/timing.rpt $<

clean:
	rm -rf $(BUILD_DIR) $(SYNTH_MEM)
