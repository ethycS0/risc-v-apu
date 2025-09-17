# Makefile for simulating RISC-V modules

# Tool configuration
GHDL = ghdl
GTKWAVE = gtkwave

# --- Smart Configuration ---
# All VHDL source files in the src directory
VHDL_SOURCES = $(wildcard src/*.vhd)

# The testbench to run, can be overridden from the command line
# e.g., make run TB=tb_alu
TB ?= tb_register_file

# --- File Definitions (based on TB variable) ---
VHDL_TESTBENCH = tb/$(TB).vhd
TOP_LEVEL = $(TB)
WAVEFORM_FILE = sim/$(TOP_LEVEL).ghw

# --- Targets ---
# Default target
all: run

# Compile all VHDL source and the specified testbench
compile:
	@echo "Compiling VHDL sources..."
	$(GHDL) -a $(VHDL_SOURCES) $(VHDL_TESTBENCH)

# Elaborate the specified testbench
elaborate: compile
	@echo "Elaborating design for $(TOP_LEVEL)..."
	$(GHDL) -e $(TOP_LEVEL)

# Run the simulation
run: elaborate
	@echo "Running simulation for $(TOP_LEVEL)..."
	@mkdir -p sim
	$(GHDL) -r $(TOP_LEVEL) --wave=$(WAVEFORM_FILE)

# View the corresponding waveform
view:
	@echo "Opening waveform $(WAVEFORM_FILE)..."
	$(GTKWAVE) $(WAVEFORM_FILE)

# Clean up all generated files
clean:
	@echo "Cleaning up..."
	$(GHDL) --clean
	rm -rf sim work-obj93.cf

