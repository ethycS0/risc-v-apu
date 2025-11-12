LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY register_file IS
	PORT (
		-- Clock and Reset
		i_clk           : IN  std_logic;
		i_rst           : IN  std_logic;

		-- Write Port 
		i_wr_en         : IN  std_logic;
		i_wr_addr       : IN  std_logic_vector(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_wr_data       : IN  std_logic_vector(REGFILE_DATA_WIDTH - 1 DOWNTO 0);

		-- Read Port 1 
		i_rd1_addr      : IN  std_logic_vector(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		o_rd1_data      : OUT std_logic_vector(REGFILE_DATA_WIDTH - 1 DOWNTO 0);

		-- Read Port 2
		i_rd2_addr      : IN  std_logic_vector(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		o_rd2_data      : OUT std_logic_vector(REGFILE_DATA_WIDTH - 1 DOWNTO 0)
	);
END ENTITY register_file;


ARCHITECTURE behavioral OF register_file IS
	-- Internal type definitions
	SUBTYPE t_reg_word IS std_logic_vector(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
	TYPE t_reg_array IS ARRAY(0 TO 2**REGFILE_ADDR_WIDTH - 1) OF t_reg_word;

	-- Internal signal for the register bank
	SIGNAL s_registers : t_reg_array := (OTHERS => (OTHERS => '0'));

BEGIN
	-- Synchronous Write Process
	write_process : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_registers <= (OTHERS => (OTHERS => '0'));
		ELSIF rising_edge(i_clk) THEN
			IF i_wr_en = '1' AND to_integer(unsigned(i_wr_addr)) /= 0 THEN
				s_registers(to_integer(unsigned(i_wr_addr))) <= i_wr_data;
			END IF;
		END IF;
	END PROCESS write_process;

	o_rd1_data <= s_registers(to_integer(unsigned(i_rd1_addr)));
	o_rd2_data <= s_registers(to_integer(unsigned(i_rd2_addr)));

END ARCHITECTURE behavioral;

