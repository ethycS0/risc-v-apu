LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_textio.ALL;
USE std.textio.ALL;
USE std.env.ALL;

ENTITY unified_memory_unit IS
	GENERIC (
		G_MEM_SIZE : INTEGER := 2048;
		G_CODE : STRING := "imem.hex"
	);

	PORT (
		i_clk : IN STD_LOGIC;

		i_imem_addr : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_imem_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_dmem_addr     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_dmem_wdata    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_dmem_rdata    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_dmem_write_en : IN  STD_LOGIC;
		i_dmem_byte_en  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END ENTITY unified_memory_unit;

ARCHITECTURE behavioral OF unified_memory_unit IS
	TYPE mem_array_t IS ARRAY (0 TO G_MEM_SIZE - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

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

			REPORT "Memory initialized from " & filename &
				": " & INTEGER'image(v_index) & " words loaded.";
		ELSE
			REPORT "WARNING: Could not open " & filename &
				". Initializing with NOPs." SEVERITY WARNING;
		END IF;

		RETURN v_mem;
	END FUNCTION;

	SIGNAL ram : mem_array_t := init_memory_from_hex(G_CODE);

	ATTRIBUTE ram_style : STRING;
	ATTRIBUTE ram_style OF ram : SIGNAL IS "block";
BEGIN

	P_IMEM : PROCESS (i_clk)
		VARIABLE v_idx : INTEGER;
	BEGIN
		IF rising_edge(i_clk) THEN
			v_idx := to_integer(unsigned(i_imem_addr(12 DOWNTO 2)));
			o_imem_data <= ram(v_idx);
		END IF;
	END PROCESS P_IMEM;

	P_DMEM : PROCESS (i_clk)
		VARIABLE v_idx : INTEGER;
		VARIABLE v_word : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		IF rising_edge(i_clk) THEN
			v_idx := to_integer(unsigned(i_dmem_addr(12 DOWNTO 2)));

			IF i_dmem_write_en = '1' THEN
				v_word := ram(v_idx);

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

				ram(v_idx) <= v_word;
			END IF;

			o_dmem_rdata <= ram(v_idx);
		END IF;
	END PROCESS P_DMEM;

END ARCHITECTURE behavioral;

