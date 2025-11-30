# Makefile for simulating RISC-V modules

# Tool configuration
GHDL = ghdl
GTKWAVE = gtkwave

# --- Smart Configuration ---
# All VHDL source files in the src directory
ROOT_DIR := $(shell pwd)

# All VHDL source files (Prepend ROOT_DIR to make paths absolute)
PKG_FILES = $(ROOT_DIR)/src/common.vhd

SRC_FILES = $(ROOT_DIR)/src/alu.vhd \
    $(ROOT_DIR)/src/ex_decode_unit.vhd \
    $(ROOT_DIR)/src/branch_adder.vhd \
    $(ROOT_DIR)/src/branch_control.vhd \
    $(ROOT_DIR)/src/core.vhd \
    $(ROOT_DIR)/src/csr_unit.vhd \
    $(ROOT_DIR)/src/decode_control_unit.vhd \
    $(ROOT_DIR)/src/execution_unit.vhd \
    $(ROOT_DIR)/src/forwarding_unit.vhd \
    $(ROOT_DIR)/src/hazard_detection_unit.vhd \
    $(ROOT_DIR)/src/immediate_constructor.vhd \
    $(ROOT_DIR)/src/instruction_decode.vhd \
    $(ROOT_DIR)/src/instruction_fetch.vhd \
    $(ROOT_DIR)/src/memory_unit.vhd \
    $(ROOT_DIR)/src/register_file.vhd \
    $(ROOT_DIR)/src/writeback_unit.vhd

# The testbench
TB ?= tb_core
VHDL_TESTBENCH = $(ROOT_DIR)/tb/$(TB).vhd
TOP_LEVEL = $(TB)
WAVEFORM_FILE = sim/$(TOP_LEVEL).ghw
GHDL_FLAGS = --std=08 -frelaxed

# --- Targets ---
# Default target
all: run

# Compile all VHDL source and the specified testbench
compile:
	@echo "Compiling VHDL sources..."
	$(GHDL) -a $(GHDL_FLAGS) $(PKG_FILES) $(SRC_FILES) $(VHDL_TESTBENCH)

# Elaborate the specified testbench
elaborate: compile
	@echo "Elaborating design for $(TOP_LEVEL)..."
	$(GHDL) -e $(GHDL_FLAGS) $(TOP_LEVEL)

# Run the simulation
run: elaborate
	@echo "Running simulation for $(TOP_LEVEL)..."
	@mkdir -p sim
	$(GHDL) -r $(GHDL_FLAGS) $(TOP_LEVEL) --wave=$(WAVEFORM_FILE)

# View the corresponding waveform
view:
	@echo "Opening waveform $(WAVEFORM_FILE)..."
	$(GTKWAVE) --dark $(WAVEFORM_FILE)

# Clean up all generated files
clean:
	@echo "Cleaning up Root..."
	$(GHDL) --clean
	rm -rf sim work-obj08.cf imem.hex
	@echo "Cleaning up Software..."
	$(MAKE) -C software/asm clean
