LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY register_file IS
	GENERIC (
		DATA_WIDTH : INTEGER := 32;
		ADDR_WIDTH : INTEGER := 5
	);

	PORT (
		clk : IN std_logic;
		rst : IN std_logic;
		wr_en : IN std_logic;

		wr_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
		wr_data : IN std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);

		rd1_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
		rd1_data : OUT std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);

		rd2_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
		rd2_data : OUT std_logic_vector(DATA_WIDTH - 1 DOWNTO 0)
	);

END ENTITY register_file;


ARCHITECTURE behavioral OF register_file IS
	SUBTYPE reg_word_t IS std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);
	TYPE reg_array_t IS ARRAY(0 TO 2 ** ADDR_WIDTH - 1) OF reg_word_t;

	SIGNAL registers : reg_array_t := (OTHERS => (OTHERS => '0'));
BEGIN
	write_process : PROCESS (clk, rst)
	BEGIN
		IF rst = '1' THEN
			registers <= (OTHERS => (OTHERS => '0'));
		ELSIF rising_edge(clk) THEN
			IF wr_en = '1' AND to_integer(unsigned(wr_addr)) /= 0 THEN
				registers(to_integer(unsigned(wr_addr))) <= wr_data;
			END IF;
		END IF;
	END PROCESS write_process;

        rd1_data <= registers(to_integer(unsigned(rd1_addr)));
        rd2_data <= registers(to_integer(unsigned(rd2_addr)));

END ARCHITECTURE behavioral;
