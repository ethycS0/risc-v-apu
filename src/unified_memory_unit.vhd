--! @file unified_memory_unit.vhd
--! Unified Memory Unit
--! @author ethycS
--! @details This module implements a dual-port memory that serves as both instruction
--! memory (IMEM) and data memory (DMEM) for the RV32I processor core. It supports
--! Harvard architecture semantics with separate instruction and data interfaces while
--! using a single underlying memory array.
--!
--! Features:
--! - Dual-port access: simultaneous instruction fetch and data memory access
--! - Configurable memory size via generics
--! - Initialization from HEX format file at synthesis/simulation time
--! - Byte-granular writes with byte enable signals for data port
--! - Synchronous read with 1-cycle latency (matches BRAM behavior)
--! - Two operational modes: simulation (shared variable) and synthesis (signal/BRAM)
--!
--! Memory organization:
--! - Word-addressable (32-bit words) with byte-addressed interface
--! - Address bits [1:0] ignored (word-aligned access assumed)
--! - Address bits [29:2] used as word index into memory array
--! - Out-of-range accesses return zero (no error signaling)
--!
--! Simulation vs Synthesis modes:
--! - Simulation: Uses SHARED VARIABLE for low simulation overhead.
--! - Synthesis: Uses SIGNAL with ram_style="block" attribute for BRAM inference
--! The shared variable in simulation mode lowers simulation RAM usage.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_textio.ALL;
USE std.textio.ALL;
USE std.env.ALL;

ENTITY unified_memory_unit IS
	GENERIC (
		G_MEM_SIZE        : INTEGER := 8192;       --! Memory size in 32-bit words (default 32KB)
		G_CODE            : STRING := "code.hex";  --! Path to HEX initialization file
		G_SIMULATION_MODE : BOOLEAN := FALSE       --! Operational mode (TRUE=simulation, FALSE=synthesis)
	);

	PORT (
		i_clk : IN STD_LOGIC;  --! System clock (synchronous read for both ports)

		i_imem_addr : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Instruction memory address 
		o_imem_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Instruction memory read data 

		i_dmem_addr     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory address 
		i_dmem_wdata    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory write data
		o_dmem_rdata    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory read data
		i_dmem_write_en : IN  STD_LOGIC;                     --! Data memory write enable
		i_dmem_byte_en  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)   --! Data memory byte enable 
	);
END ENTITY unified_memory_unit;

ARCHITECTURE behavioral OF unified_memory_unit IS

	TYPE mem_array_t IS ARRAY (0 TO G_MEM_SIZE - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory array type definition

	--! @brief Memory Initialization Function
	--! @details Impure function that reads an HEX format file and initializes
	--! the memory array. The function is called at elaboration time (before simulation
	--! or synthesis).
	--!
	--! HEX file format:
	--! - Each line contains one 32-bit word in hexadecimal (8 hex digits)
	--! - Lines starting with '#' are treated as comments and ignored
	--! - Empty lines are skipped
	--! - Words are loaded sequentially starting at index 0
	--!
	--! Error handling:
	--! - If file cannot be opened, emits a warning and returns array of NOPs (0x00000000)
	--! - If file is shorter than memory size, remaining locations are initialized to zero
	--! - Loading stops at end of file or when memory is full
	--!
	--! The function reports the number of words successfully loaded for debugging purposes.
	IMPURE FUNCTION init_memory_from_hex(filename : STRING) RETURN mem_array_t IS
		FILE hex_file : text;
		VARIABLE l : line;
		VARIABLE v_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
		VARIABLE v_index : INTEGER := 0;
		VARIABLE v_mem : mem_array_t := (OTHERS => x"00000000");
		VARIABLE v_status : file_open_status;
	BEGIN
		file_open(v_status, hex_file, filename, read_mode);
		IF v_status = open_ok THEN
			WHILE NOT endfile(hex_file) AND v_index < G_MEM_SIZE LOOP
				readline(hex_file, l);
				IF l'LENGTH > 0 AND l(1) /= '#' THEN 
					hread(l, v_data);
					v_mem(v_index) := v_data;
					v_index := v_index + 1;
				END IF;
			END LOOP;
			file_close(hex_file);
			REPORT "Memory initialized from " & filename & ": " & INTEGER'image(v_index) & " words loaded.";
		ELSE
			REPORT "WARNING: Could not open " & filename & ". Initializing with NOPs." SEVERITY WARNING;
		END IF;
		RETURN v_mem;
	END FUNCTION;

BEGIN

	G_SIM : IF G_SIMULATION_MODE GENERATE
		SHARED VARIABLE ram : mem_array_t := init_memory_from_hex(G_CODE); --! Shared memory array (simulation mode)
	BEGIN

		--! @brief Instruction Memory Read Process (Simulation Mode)
		--! @details Synchronous process that implements the instruction memory read port.
		--! On each clock cycle, it reads a 32-bit instruction from the memory array using
		--! the word-aligned address (bits [29:2]). Address bits [1:0] are ignored as
		--! instructions are always word-aligned. Out-of-range addresses return zero.
		P_IMEM : PROCESS (i_clk)
			VARIABLE v_idx : INTEGER; 
		BEGIN
			IF rising_edge(i_clk) THEN
				v_idx := to_integer(unsigned(i_imem_addr(29 DOWNTO 2)));

				IF v_idx >= 0 AND v_idx < G_MEM_SIZE THEN
					o_imem_data <= ram(v_idx);
				ELSE
					o_imem_data <= (OTHERS => '0');  -- Return zero for out-of-range
				END IF;
			END IF;
		END PROCESS P_IMEM;

		--! @brief Data Memory Read/Write Process (Simulation Mode)
		--! @details Synchronous process that implements the data memory port with
		--! byte-granular write capability. On each clock cycle:
		--! - If write_en is asserted, updates selected bytes based on byte_en mask
		--! - Reads current word value and outputs it (write-first behavior)
		--! The read happens every cycle regardless of write_en, allowing simultaneous
		--! read-modify-write or pure read operations. Byte enables allow sub-word
		--! writes (SB, SH) without read-modify-write at the application level.
		P_DMEM : PROCESS (i_clk)
			VARIABLE v_idx : INTEGER;                       
			VARIABLE v_word : STD_LOGIC_VECTOR(31 DOWNTO 0);
		BEGIN
			IF rising_edge(i_clk) THEN
				v_idx := to_integer(unsigned(i_dmem_addr(29 DOWNTO 2)));
				IF v_idx >= 0 AND v_idx < G_MEM_SIZE THEN

					IF i_dmem_write_en = '1' THEN
						v_word := ram(v_idx);  -- Read current value

						-- Update enabled bytes
						IF i_dmem_byte_en(0) = '1' THEN
							v_word(7 DOWNTO 0) := i_dmem_wdata(7 DOWNTO 0);
						END IF;
						IF i_dmem_byte_en(1) = '1' THEN
							v_word(15 DOWNTO 8) := i_dmem_wdata(15 DOWNTO 8);
						END IF;
						IF i_dmem_byte_en(2) = '1' THEN
							v_word(23 DOWNTO 16) := i_dmem_wdata(23 DOWNTO 16);
						END IF;
						IF i_dmem_byte_en(3) = '1' THEN
							v_word(31 DOWNTO 24) := i_dmem_wdata(31 DOWNTO 24);
						END IF;

						ram(v_idx) := v_word;  -- Write back modified word
					END IF;

					o_dmem_rdata <= ram(v_idx);  -- Output current/updated value
				ELSE
					o_dmem_rdata <= (OTHERS => '0');  -- Return zero for out-of-range
				END IF;
			END IF;
		END PROCESS P_DMEM;

	END GENERATE;

	G_SYNTH : IF NOT G_SIMULATION_MODE GENERATE
		SIGNAL ram : mem_array_t := init_memory_from_hex(G_CODE); --! Memory array signal (synthesis mode)
		ATTRIBUTE ram_style : STRING;
		ATTRIBUTE ram_style OF ram : SIGNAL IS "block"; --! Synthesis attribute for BRAM inference
	BEGIN

		--! @brief Instruction Memory Read Process (Synthesis Mode)
		--! @details Synchronous process for instruction memory read port. Identical
		--! functionality to simulation mode but operates on a SIGNAL instead of shared
		--! variable. The synchronous read pattern with registered output matches BRAM
		--! read behavior and ensures optimal timing closure in FPGA implementation.
		P_IMEM : PROCESS (i_clk)
			VARIABLE v_idx : INTEGER; 
		BEGIN
			IF rising_edge(i_clk) THEN
				v_idx := to_integer(unsigned(i_imem_addr(29 DOWNTO 2)));

				IF v_idx >= 0 AND v_idx < G_MEM_SIZE THEN
					o_imem_data <= ram(v_idx);
				ELSE
					o_imem_data <= (OTHERS => '0');  -- Return zero for out-of-range
				END IF;
			END IF;
		END PROCESS P_IMEM;

		--! @brief Data Memory Read/Write Process (Synthesis Mode)
		--! @details Synchronous process for data memory port with byte-enable writes.
		--! Uses individual byte-lane assignments instead of read-modify-write with
		--! variables, which better matches synthesis tool expectations for BRAM byte
		--! enables. Most FPGAs have native byte-enable support in block RAM, and this
		--! coding style ensures proper inference. Reads are always synchronous, matching
		--! BRAM read-during-write behavior (new data forwarding).
		P_DMEM : PROCESS (i_clk)
			VARIABLE v_idx : INTEGER;
		BEGIN
			IF rising_edge(i_clk) THEN
				v_idx := to_integer(unsigned(i_dmem_addr(29 DOWNTO 2)));

				IF v_idx >= 0 AND v_idx < G_MEM_SIZE THEN
					IF i_dmem_write_en = '1' THEN
						-- Write enabled bytes (synthesis-friendly pattern for BRAM byte enables)
						IF i_dmem_byte_en(0) = '1' THEN
							ram(v_idx)(7 DOWNTO 0) <= i_dmem_wdata(7 DOWNTO 0);
						END IF;
						IF i_dmem_byte_en(1) = '1' THEN
							ram(v_idx)(15 DOWNTO 8) <= i_dmem_wdata(15 DOWNTO 8);
						END IF;
						IF i_dmem_byte_en(2) = '1' THEN
							ram(v_idx)(23 DOWNTO 16) <= i_dmem_wdata(23 DOWNTO 16);
						END IF;
						IF i_dmem_byte_en(3) = '1' THEN
							ram(v_idx)(31 DOWNTO 24) <= i_dmem_wdata(31 DOWNTO 24);
						END IF;
					END IF;

					o_dmem_rdata <= ram(v_idx);  -- Synchronous read (BRAM-style)
				ELSE
					o_dmem_rdata <= (OTHERS => '0');  -- Return zero for out-of-range
				END IF;
			END IF;
		END PROCESS P_DMEM;

	END GENERATE;

END ARCHITECTURE behavioral;

