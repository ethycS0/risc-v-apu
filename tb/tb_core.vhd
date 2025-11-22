LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
USE std.env.ALL;

ENTITY tb_core IS
	GENERIC (
		G_IMEM_FILENAME : STRING := "imem.hex";
		G_MAX_CYCLES : INTEGER := 50000;
		G_TERMINATION_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"80010000"
	);
END ENTITY tb_core;

ARCHITECTURE behavioral OF tb_core IS
	CONSTANT MEM_DEPTH : INTEGER := 131072;
	CONSTANT MEM_BASE : UNSIGNED(31 DOWNTO 0) := x"80000000";
	CONSTANT CLK_PERIOD : TIME := 10 ns;

	-- CHANGE 1: Use SHARED VARIABLE for Memory
	TYPE t_memory IS ARRAY (0 TO MEM_DEPTH - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	SHARED VARIABLE main_memory : t_memory := (OTHERS => (OTHERS => '0'));

	-- Signals remain the same
	SIGNAL s_clk : STD_LOGIC := '0';
	SIGNAL s_rst : STD_LOGIC := '1';
	SIGNAL s_instr_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_instr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_read : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_write : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_write_en : STD_LOGIC;
	SIGNAL s_data_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL s_sim_finished : BOOLEAN := FALSE;

BEGIN
	U_CORE : ENTITY work.core
		PORT MAP(
			i_clk           => s_clk,
			i_rst           => s_rst,
			o_instr_addr    => s_instr_addr,
			i_instr_data    => s_instr_data,
			o_data_addr     => s_data_addr,
			i_data_read     => s_data_read,
			o_data_write    => s_data_write,
			o_data_write_en => s_data_write_en,
			o_data_byte_en  => s_data_byte_en
		);

	-- Clock Generation with Watchdog
	p_clk : PROCESS
		VARIABLE v_cycles : INTEGER := 0;
	BEGIN
		WHILE NOT s_sim_finished LOOP
			s_clk <= '0';
			WAIT FOR CLK_PERIOD / 2;
			s_clk <= '1';
			WAIT FOR CLK_PERIOD / 2;

			v_cycles := v_cycles + 1;
			IF v_cycles > G_MAX_CYCLES THEN
				REPORT "TIMEOUT: Simulation ran too long." SEVERITY FAILURE;
			END IF;
		END LOOP;
		WAIT;
	END PROCESS;

	-- CHANGE 2: Loader uses Variable Assignment (:=)
	p_load_memory : PROCESS
		FILE hex_file : text;
		VARIABLE l : line;
		VARIABLE v_data_read : STD_LOGIC_VECTOR(31 DOWNTO 0);
		VARIABLE v_addr_index : INTEGER := 0;
		VARIABLE v_file_status : file_open_status;
	BEGIN
		s_rst <= '1';

		-- Load file
		file_open(v_file_status, hex_file, G_IMEM_FILENAME, read_mode);
		IF v_file_status /= open_ok THEN
			REPORT "ERROR: Cannot open file: " & G_IMEM_FILENAME SEVERITY FAILURE;
		END IF;

		WHILE NOT endfile(hex_file) LOOP
			readline(hex_file, l);
			IF l'length > 0 THEN
				hread(l, v_data_read);
				IF v_addr_index < MEM_DEPTH THEN
					main_memory(v_addr_index) := v_data_read; -- Note the :=
					v_addr_index := v_addr_index + 1;
				END IF;
			END IF;
		END LOOP;
		file_close(hex_file);

		REPORT "Memory Loaded: " & INTEGER'image(v_addr_index) & " words.";

		WAIT FOR CLK_PERIOD * 5;
		s_rst <= '0';
		REPORT "Reset released..." SEVERITY NOTE;
		WAIT;
	END PROCESS;

	-- CHANGE 3: Read process reads from Shared Variable
	p_memory_read : PROCESS (s_instr_addr, s_data_addr, s_clk)
		VARIABLE v_instr_idx : INTEGER;
		VARIABLE v_data_idx : INTEGER;
	BEGIN
		-- Instruction Fetch
		IF unsigned(s_instr_addr) >= MEM_BASE THEN
			v_instr_idx := to_integer((unsigned(s_instr_addr) - MEM_BASE)) / 4;
		ELSE
			v_instr_idx := - 1;
		END IF;

		IF v_instr_idx >= 0 AND v_instr_idx < MEM_DEPTH THEN
			s_instr_data <= main_memory(v_instr_idx);
		ELSE
			s_instr_data <= (OTHERS => '0');
		END IF;

		-- Data Read
		IF unsigned(s_data_addr) >= MEM_BASE THEN
			v_data_idx := to_integer((unsigned(s_data_addr) - MEM_BASE)) / 4;
		ELSE
			v_data_idx := - 1;
		END IF;

		IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
			s_data_read <= main_memory(v_data_idx);
		ELSE
			s_data_read <= (OTHERS => '0');
		END IF;
	END PROCESS;

	-- CHANGE 4: Write process uses Variable Assignment (:=)
	p_memory_write : PROCESS (s_clk)
		VARIABLE v_data_idx : INTEGER;
	BEGIN
		IF rising_edge(s_clk) THEN
			IF s_data_write_en = '1' THEN
				-- Check for Termination
				IF s_data_addr = G_TERMINATION_ADDR THEN
					REPORT "TERMINATION: Magic address write detected!";
					IF to_integer(unsigned(s_data_write)) = 1 THEN
						REPORT "Test PASSED!" SEVERITY NOTE;
						stop;
					ELSE
						REPORT "Test FAILED! Error code: " & to_hstring(s_data_write) SEVERITY FAILURE;
					END IF;
					s_sim_finished <= TRUE;
				END IF;

				-- Normal Memory Write
				IF unsigned(s_data_addr) >= MEM_BASE THEN
					v_data_idx := to_integer((unsigned(s_data_addr) - MEM_BASE)) / 4;
					IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
						IF s_data_byte_en(0) = '1' THEN
							main_memory(v_data_idx)(7 DOWNTO 0) := s_data_write(7 DOWNTO 0);
						END IF;
						IF s_data_byte_en(1) = '1' THEN
							main_memory(v_data_idx)(15 DOWNTO 8) := s_data_write(15 DOWNTO 8);
						END IF;
						IF s_data_byte_en(2) = '1' THEN
							main_memory(v_data_idx)(23 DOWNTO 16) := s_data_write(23 DOWNTO 16);
						END IF;
						IF s_data_byte_en(3) = '1' THEN
							main_memory(v_data_idx)(31 DOWNTO 24) := s_data_write(31 DOWNTO 24);
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE behavioral;

