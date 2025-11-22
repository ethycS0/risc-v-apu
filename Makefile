# Makefile for simulating RISC-V modules

# Tool configuration
GHDL = ghdl
GTKWAVE = gtkwave

# --- Smart Configuration ---
# All VHDL source files in the src directory
PKG_FILES = src/common.vhd
SRC_FILES = src/alu.vhd \
	src/ex_decode_unit.vhd \
	src/branch_adder.vhd \
	src/branch_control.vhd \
	src/core.vhd \
	src/csr_unit.vhd \
	src/decode_control_unit.vhd \
	src/execution_unit.vhd \
	src/forwarding_unit.vhd \
	src/hazard_detection_unit.vhd \
        src/immediate_constructor.vhd \
	src/instruction_decode.vhd \
	src/instruction_fetch.vhd \
	src/memory_unit.vhd \
        src/register_file.vhd \
	src/writeback_unit.vhd

# The testbench to run, can be overridden from the command line
# e.g., make run TB=tb_alu
TB ?= tb_core

# --- File Definitions (based on TB variable) ---
VHDL_TESTBENCH = tb/$(TB).vhd
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
