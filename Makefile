GHDL = ghdl
GTKWAVE = gtkwave
YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack
OPENFPGALOADER = openFPGALoader

ROOT_DIR := $(shell pwd)

PKG_FILES = $(ROOT_DIR)/src/common.vhd

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
	$(ROOT_DIR)/src/WB_stage/writeback_stage.vhd \
	$(ROOT_DIR)/src/uart.vhd \
	$(ROOT_DIR)/src/unified_memory_unit.vhd \
	$(ROOT_DIR)/src/soc.vhd

TB ?= tb_soc
VHDL_TESTBENCH = $(ROOT_DIR)/tb/$(TB).vhd
TOP_LEVEL = $(TB)
WAVEFORM_FILE = sim/$(TOP_LEVEL).ghw
GHDL_FLAGS = --std=08 -frelaxed

SOC_TOP = soc
DEVICE = GW2A-LV18PG256C8/I7
FAMILY = GW2A-18C
BOARD = tangprimer20k
CONSTRAINT_FILE = $(ROOT_DIR)/constraints/fpga.cst
BUILD_DIR = build

.PHONY: all run compile elaborate view clean code synth pnr bitstream program fpga

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
	$(MAKE) -C software/tests clean

code: 
	$(MAKE) -C software/drivers 

synth: code
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -m ghdl -p " \
		ghdl $(GHDL_FLAGS) $(PKG_FILES) $(SRC_FILES) -e $(SOC_TOP); \
		synth_gowin -top $(SOC_TOP) -json $(BUILD_DIR)/$(SOC_TOP).json"

pnr: synth
	$(NEXTPNR) --json $(BUILD_DIR)/$(SOC_TOP).json \
		--write $(BUILD_DIR)/$(SOC_TOP)_pnr.json \
		--device $(DEVICE) \
		--freq 27 \
		--vopt family=$(FAMILY) \
		--vopt cst=$(CONSTRAINT_FILE)	
bitstream: pnr
	$(GOWIN_PACK) -d $(FAMILY) -o $(BUILD_DIR)/$(SOC_TOP).fs $(BUILD_DIR)/$(SOC_TOP)_pnr.json
	@echo "Bitstream generated: $(BUILD_DIR)/$(SOC_TOP).fs"

program: bitstream
	$(OPENFPGALOADER) -c ft2232 -b $(BOARD) $(BUILD_DIR)/$(SOC_TOP).fs
	@echo "Programmed to SRAM (volatile)"

fpga: bitstream
	@echo "FPGA build complete!"
	@echo "Run 'make program' to load to SRAM (temporary)"
	@echo "Run 'make program-flash' to load to Flash (persistent)"

clean:
	$(GHDL) --clean
	rm -rf sim work-obj08.cf imem.hex $(BUILD_DIR)
	$(MAKE) -C software/tests clean
	$(MAKE) -C software/drivers clean

help:
	@echo "Simulation targets:"
	@echo "  make run              - Run testbench simulation"
	@echo "  make view             - View waveform with GTKWave"
	@echo "  make TB=<name> run    - Run specific testbench"
	@echo ""
	@echo "FPGA targets:"
	@echo "  make synth            - Synthesize with Yosys"
	@echo "  make pnr              - Place and route with nextpnr"
	@echo "  make bitstream        - Generate bitstream"
	@echo "  make program          - Program to FPGA SRAM (temporary)"
	@echo "  make fpga             - Complete FPGA build"
	@echo "  make code             - Make software/drivers
	@echo ""
	@echo "  make clean            - Clean all build files"
