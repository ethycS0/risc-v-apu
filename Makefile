GHDL = ghdl
GTKWAVE = gtkwave

ROOT_DIR := $(shell pwd)

PKG_FILES = $(ROOT_DIR)/src/common/common.vhd

SRC_FILES = \
	$(ROOT_DIR)/src/core.vhd \
	$(ROOT_DIR)/src/hazard_detection_unit.vhd \
	$(ROOT_DIR)/src/IF_stage/instruction_fetch_stage.vhd \
	$(ROOT_DIR)/src/ID_stage/id_control_unit.vhd \
	$(ROOT_DIR)/src/ID_stage/immediate_reconstruct_unit.vhd \
	$(ROOT_DIR)/src/ID_stage/instruction_decode_stage.vhd \
	$(ROOT_DIR)/src/ID_stage/register_file.vhd \
	$(ROOT_DIR)/src/EX_stage/alu.vhd \
	$(ROOT_DIR)/src/EX_stage/branch_adder.vhd \
	$(ROOT_DIR)/src/EX_stage/branch_control_unit.vhd \
	$(ROOT_DIR)/src/EX_stage/csr_unit.vhd \
	$(ROOT_DIR)/src/EX_stage/ex_control_unit.vhd \
	$(ROOT_DIR)/src/EX_stage/execution_stage.vhd \
	$(ROOT_DIR)/src/EX_stage/forwarding_unit.vhd \
	$(ROOT_DIR)/src/MEM_stage/memory_stage.vhd \
	$(ROOT_DIR)/src/WB_stage/writeback_stage.vhd

TB ?= tb_core_hex
VHDL_TESTBENCH = $(ROOT_DIR)/tb/$(TB).vhd
TOP_LEVEL = $(TB)
WAVEFORM_FILE = sim/$(TOP_LEVEL).ghw
GHDL_FLAGS = --std=08 -frelaxed

all: run

compile:
	$(GHDL) -a $(GHDL_FLAGS) $(PKG_FILES) $(SRC_FILES) $(VHDL_TESTBENCH)

elaborate: compile
	$(GHDL) -e $(GHDL_FLAGS) $(TOP_LEVEL)

run: elaborate
	mkdir -p sim
	$(GHDL) -r $(GHDL_FLAGS) $(TOP_LEVEL) --wave=$(WAVEFORM_FILE)

view:
	$(GTKWAVE) --dark $(WAVEFORM_FILE)

clean:
	$(GHDL) --clean
	rm -rf sim work-obj08.cf imem.hex
	$(MAKE) -C software/asm clean
	
