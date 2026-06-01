TOP := top
DEVICE := up5k
PACKAGE := sg48
FREQ ?= 25
BUILD_DIR := build
PCF := icebreaker.pcf

RTL_SOURCES := \
	../../rtl/pkg.sv \
	../../rtl/branch_target_buffer/branch_target_buffer.sv \
	../../submodules/imports/sync_ram_block.sv \
	../../submodules/imports/fifo_sync.sv \
	../../rtl/if_stage/if_stage.sv \
	../../rtl/decode/decode.sv \
	../../rtl/regfile/regfile.sv \
	../../rtl/hazard_unit/hazard_unit.sv \
	../../rtl/id_stage/id_stage.sv \
	../../rtl/alu/alu.sv \
	../../rtl/ex_stage/ex_stage.sv \
	../../rtl/mem_stage/mem_stage.sv \
	../../rtl/dm_cache/dm_cache.sv \
	../../rtl/axil_master/axil_master.sv \
	../../submodules/imports/axil_dp_ram.v \
	../../rtl/top/top.sv

.PHONY: all synth yosys pnr timing clean

all: synth

synth: timing

yosys: $(BUILD_DIR)/$(TOP).json

$(BUILD_DIR)/$(TOP).json: $(RTL_SOURCES)
	mkdir -p $(BUILD_DIR)
	yosys -p "read_verilog -sv $(RTL_SOURCES); synth_ice40 -top $(TOP) -json $@"

pnr: $(BUILD_DIR)/$(TOP).asc

$(BUILD_DIR)/$(TOP).asc: $(BUILD_DIR)/$(TOP).json $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --freq $(FREQ) --json $< --asc $@ --pcf $(PCF) --pcf-allow-unconstrained > $(BUILD_DIR)/nextpnr.log 2>&1
	cat $(BUILD_DIR)/nextpnr.log

timing: $(BUILD_DIR)/$(TOP).asc
	icetime -d $(DEVICE) -P $(PACKAGE) -mtr $(BUILD_DIR)/timing.rpt $<

clean:
	rm -rf $(BUILD_DIR)
