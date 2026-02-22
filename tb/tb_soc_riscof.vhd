--! @file tb_soc_riscof.vhd
--! RISCOF Compliance Testbench
--! @author ethycS
--! @details This testbench implements the verification infrastructure for RISC-V
--! Compliance Framework (RISCOF) testing of the RV32I processor core. It loads test
--! programs, monitors execution, captures memory write signatures, and generates
--! output files for compliance verification.
--!
--! RISCOF test flow:
--! 1. Load test program from HEX file into SoC memory at initialization
--! 2. Monitor all data memory writes via debug signals
--! 3. Maintain shadow memory copy to track architectural state
--! 4. Detect test completion via write to magic termination address
--! 5. Dump signature region to file for golden reference comparison
--! 6. Handle timeout scenarios with partial signature dumps
--!
--! Test configuration (via generics):
--! - G_IMEM_FILENAME: Input test program in Intel HEX format
--! - G_SIG_FILENAME: Output signature file for verification
--! - G_TERMINATION_OFFSET: Byte offset for test termination magic address
--! - G_SIG_START_OFFSET: Signature region start (byte offset from memory base)
--! - G_SIG_END_OFFSET: Signature region end (byte offset from memory base)
--! - G_MAX_CYCLES: Timeout threshold in clock cycles
--!
--! Termination conditions:
--! - Normal: Write to termination address triggers signature dump and stop
--! - Timeout: Exceeding G_MAX_CYCLES triggers partial signature dump and warning
--!
--! The shadow memory tracks all architectural writes byte-by-byte using byte enable
--! signals, ensuring accurate capture of SB, SH, and SW instructions. The signature
--! is a contiguous memory region that test programs write results to, which is then
--! compared against golden reference files by the RISCOF framework.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
USE std.env.ALL;

ENTITY tb_soc_riscof IS
	GENERIC (
		G_IMEM_FILENAME      : STRING := "code.hex";         --! Input test program HEX file path
		G_SIG_FILENAME       : STRING := "signature.output"; --! Output signature file path
		G_MAX_CYCLES         : INTEGER := 200000;            --! Maximum simulation cycles before timeout
		G_RAM                : INTEGER := 1048575;           --! RAM size in 32-bit words (default 4MB)
		G_TERMINATION_OFFSET : INTEGER := 0;                 --! Byte offset for termination magic address
		G_SIG_START_OFFSET   : INTEGER := 0;                 --! Signature region start byte offset
		G_SIG_END_OFFSET     : INTEGER := 0                  --! Signature region end byte offset
	);
END ENTITY tb_soc_riscof;

ARCHITECTURE behavioral OF tb_soc_riscof IS

	CONSTANT MEM_BASE   : UNSIGNED(31 DOWNTO 0) := x"80000000"; --! Memory base address
	CONSTANT CLK_PERIOD : TIME := 10 ns;                         --! Clock period (100 MHz)

        --! Termination magic address (calculated from offset)
	CONSTANT C_TERM_ADDR_SLV : STD_LOGIC_VECTOR(31 DOWNTO 0) := STD_LOGIC_VECTOR(MEM_BASE + to_unsigned(G_TERMINATION_OFFSET, 32)); 

	SIGNAL s_clk : STD_LOGIC := '0';  --! System clock signal
	SIGNAL s_rx  : STD_LOGIC := '1';  --! UART RX input (idle high)
	SIGNAL s_tx  : STD_LOGIC;         --! UART TX output

	SIGNAL s_debug_addr     : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Debug: Data memory address
	SIGNAL s_debug_wdata    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Debug: Data memory write data
	SIGNAL s_debug_write_en : STD_LOGIC;                      --! Debug: Data memory write enable
	SIGNAL s_debug_byte_en  : STD_LOGIC_VECTOR(3 DOWNTO 0);   --! Debug: Data memory byte enable

	SIGNAL s_sim_finished    : BOOLEAN := FALSE; --! Simulation completion flag (normal termination)
	SIGNAL s_timeout_reached : BOOLEAN := FALSE; --! Timeout flag (abnormal termination)

	TYPE t_sig_memory IS ARRAY (0 TO G_RAM) OF STD_LOGIC_VECTOR(31 DOWNTO 0); --! Shadow memory array type
	SHARED VARIABLE sig_memory : t_sig_memory := (OTHERS => (OTHERS => '0')); --! Shadow memory tracking all writes

	SHARED VARIABLE sig_dumped : BOOLEAN := FALSE; --! Flag to prevent duplicate signature dumps

	--! @brief Signature File Dump Procedure
	--! @details Writes the signature region (specified by start_idx to end_idx) to a
	--! file in Intel HEX format (8 hex digits per line). This procedure is called once
	--! per test run, either on normal termination (magic address write) or timeout.
	--! The sig_dumped flag prevents duplicate dumps if called multiple times.
	--!
	--! Parameters:
	--! - start_idx: Starting word index of signature region
	--! - end_idx: Ending word index of signature region (inclusive)
	--! - filename: Output file path
	--! - reason: Textual reason for dump (for debug messages)
	--!
	--! The procedure reports the dump reason and number of words written for debugging.
	--! Out-of-range indices are clamped and written as zeros.
	PROCEDURE dump_signature_file (
		start_idx : INTEGER;
		end_idx   : INTEGER;
		filename  : STRING;
		reason    : STRING
	) IS
		FILE sig_file : TEXT;
		VARIABLE l : LINE;
		VARIABLE v_dump_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		IF sig_dumped THEN
			RETURN;  -- Prevent duplicate dumps
		END IF;

		sig_dumped := TRUE;

		REPORT "SIGNATURE DUMP (" & reason & "): Writing " &
			INTEGER'IMAGE(end_idx - start_idx + 1) & " words to " & filename;

		file_open(sig_file, filename, write_mode);

		FOR i IN start_idx TO end_idx LOOP
			IF i >= 0 AND i <= (G_RAM - 1) THEN
				v_dump_val := sig_memory(i);
			ELSE
				v_dump_val := (OTHERS => '0');  -- Out-of-range returns zero
			END IF;
			hwrite(l, v_dump_val);
			writeline(sig_file, l);
		END LOOP;

		file_close(sig_file);
	END PROCEDURE;

	--! @brief Memory Initialization Procedure
	--! @details Loads test program from Intel HEX file into shadow memory at
	--! initialization time (before simulation starts). Each line of the HEX file
	--! contains one 32-bit word (8 hex digits). Words are loaded sequentially starting
	--! at index 0. This initializes the shadow memory to match the actual SoC memory
	--! contents, allowing accurate signature capture.
	--!
	--! Parameters:
	--! - mem: Shadow memory array to initialize (INOUT)
	--! - filename: Input HEX file path
	--!
	--! The procedure reads the entire file, loading each word into the shadow memory
	--! until end-of-file or memory is full. This mirrors the initialization performed
	--! by the unified_memory_unit in the SoC.
	PROCEDURE load_hex_to_memory (
		mem      : INOUT t_sig_memory;
		filename : STRING
	) IS
		FILE hex_file : TEXT;
		VARIABLE l : LINE;
		VARIABLE hex_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
		VARIABLE idx : INTEGER := 0;
	BEGIN
		file_open(hex_file, filename, read_mode);
		WHILE NOT endfile(hex_file) LOOP
			readline(hex_file, l);
			hread(l, hex_val);
			IF idx <= (G_RAM - 1) THEN
				mem(idx) := hex_val;
			END IF;
			idx := idx + 1;
		END LOOP;
		file_close(hex_file);
	END PROCEDURE;

BEGIN

	--! @brief Shadow Memory Initialization Process
	--! @details One-time initialization process that loads the test program into shadow
	--! memory before simulation begins. This ensures the shadow memory starts in the same
	--! state as the actual SoC memory. The process waits indefinitely after initialization,
	--! as it only needs to run once at time zero.
	p_init_shadow : PROCESS
	BEGIN
		load_hex_to_memory(sig_memory, G_IMEM_FILENAME);
		WAIT;  -- Wait indefinitely after initialization
	END PROCESS;

	--! @brief System-on-Chip Instance
	--! @details Instantiates the SoC with simulation mode enabled (G_SIM=TRUE) and
	--! configured with the test program file and RAM size. Debug signals are exposed
	--! to allow monitoring of all data memory transactions for signature capture.
	U_SOC : ENTITY work.soc
		GENERIC MAP(
			G_CODE_FILE => G_IMEM_FILENAME,
			G_RAM_SIZE  => G_RAM,
			G_SIM       => TRUE
		)
		PORT MAP(
			clk                   => s_clk,
			uart_rx               => s_rx,
			uart_tx               => s_tx,
			o_debug_data_addr     => s_debug_addr,
			o_debug_data_wdata    => s_debug_wdata,
			o_debug_data_write_en => s_debug_write_en,
			o_debug_data_byte_en  => s_debug_byte_en
		);

	--! @brief Clock Generation and Timeout Process
	--! @details Generates the system clock and monitors cycle count for timeout detection.
	--! The clock runs at 100 MHz (10 ns period) and increments a cycle counter on each
	--! rising edge. If the counter exceeds G_MAX_CYCLES without normal termination, the
	--! process dumps a partial signature and stops simulation with a warning.
	--!
	--! Timeout handling:
	--! - Calculates signature word indices from byte offsets
	--! - Opens signature file and writes partial results
	--! - Reports warning message with cycle count
	--! - Stops simulation using VHDL-2008 STOP procedure
	--!
	--! The timeout protects against infinite loops or hung tests, ensuring test suites
	--! complete in bounded time even with buggy implementations.
	p_clk : PROCESS
		VARIABLE v_cycles : INTEGER := 0;
		VARIABLE v_sig_start_idx : INTEGER;
		VARIABLE v_sig_end_idx : INTEGER;
		FILE sig_file : TEXT;
		VARIABLE l : LINE;
		VARIABLE v_dump_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		v_sig_start_idx := G_SIG_START_OFFSET / 4;  -- Convert byte offset to word index
		v_sig_end_idx := G_SIG_END_OFFSET / 4;

		WHILE NOT s_sim_finished LOOP
			s_clk <= '0';
			WAIT FOR CLK_PERIOD / 2;
			s_clk <= '1';
			WAIT FOR CLK_PERIOD / 2;

			v_cycles := v_cycles + 1;
			IF v_cycles > G_MAX_CYCLES THEN
				REPORT "TIMEOUT after " & INTEGER'IMAGE(v_cycles) & " cycles - dumping partial signature"
					SEVERITY WARNING;

				-- Dump partial signature on timeout
				file_open(sig_file, G_SIG_FILENAME, write_mode);
				FOR i IN v_sig_start_idx TO v_sig_end_idx LOOP
					IF i >= 0 AND i <= (G_RAM - 1) THEN
						v_dump_val := sig_memory(i);
					ELSE
						v_dump_val := (OTHERS => '0');
					END IF;
					hwrite(l, v_dump_val);
					writeline(sig_file, l);
				END LOOP;
				file_close(sig_file);

				REPORT "Partial signature written to " & G_SIG_FILENAME;
				STOP;  -- Terminate simulation
			END IF;
		END LOOP;
		WAIT;
	END PROCESS;

	--! @brief Memory Write Monitor and Signature Capture Process
	--! @details Monitors all data memory writes via debug signals and maintains shadow
	--! memory to track architectural state. On each write, the process:
	--! 1. Checks if write is to termination address (triggers test completion)
	--! 2. Updates shadow memory with byte-granular writes using byte enables
	--! 3. Dumps signature on normal termination
	--!
	--! Termination detection:
	--! Any write to the magic termination address (C_TERM_ADDR_SLV) triggers immediate
	--! signature dump and simulation stop. The termination address is typically at the
	--! end of the test program and written to signal test completion.
	--!
	--! Shadow memory update:
	--! For writes to memory space, the process performs read-modify-write using byte
	--! enables. Only enabled bytes are updated, allowing accurate tracking of SB (Store
	--! Byte) and SH (Store Halfword) instructions. The write index is calculated from
	--! the byte address divided by 4 (word-aligned access).
	--!
	--! Signature dump:
	--! On termination, the signature region (specified by start/end offsets) is written
	--! to the output file for comparison against golden reference by RISCOF framework.
	p_monitor_signature : PROCESS (s_clk, s_timeout_reached)
		VARIABLE v_sig_start_idx : INTEGER;
		VARIABLE v_sig_end_idx : INTEGER;
		VARIABLE v_write_idx : INTEGER;
		VARIABLE v_dump_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		IF s_timeout_reached AND NOT sig_dumped THEN
			REPORT "Dumping partial signature due to timeout..." SEVERITY WARNING;
			v_sig_start_idx := G_SIG_START_OFFSET / 4;
			v_sig_end_idx := G_SIG_END_OFFSET / 4;
			dump_signature_file(v_sig_start_idx, v_sig_end_idx, G_SIG_FILENAME, "TIMEOUT");
		END IF;

		IF rising_edge(s_clk) THEN
			IF s_debug_write_en = '1' THEN

				-- Check for termination address write
				IF s_debug_addr = C_TERM_ADDR_SLV THEN
					REPORT "TERMINATION: Magic address write detected";

					v_sig_start_idx := G_SIG_START_OFFSET / 4;
					v_sig_end_idx := G_SIG_END_OFFSET / 4;

					dump_signature_file(v_sig_start_idx, v_sig_end_idx,
						G_SIG_FILENAME, "NORMAL_EXIT");

					s_sim_finished <= TRUE;
					REPORT "Signature Dumped. Simulation Finished.";
					STOP;  -- Normal termination
				END IF;

				-- Update shadow memory for regular writes
				IF unsigned(s_debug_addr) >= MEM_BASE THEN
					v_write_idx := to_integer((unsigned(s_debug_addr) - MEM_BASE)) / 4;

					IF v_write_idx >= 0 AND v_write_idx <= (G_RAM - 1) THEN
						v_dump_val := sig_memory(v_write_idx);  -- Read current value

						-- Update enabled bytes only (byte-granular write)
						IF s_debug_byte_en(0) = '1' THEN
							v_dump_val(7 DOWNTO 0) := s_debug_wdata(7 DOWNTO 0);
						END IF;
						IF s_debug_byte_en(1) = '1' THEN
							v_dump_val(15 DOWNTO 8) := s_debug_wdata(15 DOWNTO 8);
						END IF;
						IF s_debug_byte_en(2) = '1' THEN
							v_dump_val(23 DOWNTO 16) := s_debug_wdata(23 DOWNTO 16);
						END IF;
						IF s_debug_byte_en(3) = '1' THEN
							v_dump_val(31 DOWNTO 24) := s_debug_wdata(31 DOWNTO 24);
						END IF;

						sig_memory(v_write_idx) := v_dump_val;  -- Write back modified word
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE behavioral;

