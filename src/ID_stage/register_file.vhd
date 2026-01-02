LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY register_file IS
	PORT (
		i_clk      : IN  STD_LOGIC;
		i_rst      : IN  STD_LOGIC;
		i_wr_en    : IN  STD_LOGIC;
		i_wr_addr  : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_wr_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rd1_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		o_rd1_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rd2_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		o_rd2_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY register_file;

ARCHITECTURE behavioral OF register_file IS
	SUBTYPE t_reg_word IS STD_LOGIC_VECTOR(31 DOWNTO 0);
	TYPE t_reg_array IS ARRAY(0 TO 31) OF t_reg_word;
	SIGNAL s_registers : t_reg_array := (OTHERS => (OTHERS => '0'));
BEGIN
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

	read_proc : PROCESS (s_registers, i_rd1_addr, i_rd2_addr, i_wr_addr, i_wr_data, i_wr_en)
	BEGIN
		IF (i_wr_en = '1') AND (i_wr_addr = i_rd1_addr) AND (to_integer(unsigned(i_wr_addr)) /= 0) THEN
			o_rd1_data <= i_wr_data;
			ELSE
			o_rd1_data <= s_registers(to_integer(unsigned(i_rd1_addr)));
		END IF;

		IF (i_wr_en = '1') AND (i_wr_addr = i_rd2_addr) AND (to_integer(unsigned(i_wr_addr)) /= 0) THEN
			o_rd2_data <= i_wr_data;
			ELSE
			o_rd2_data <= s_registers(to_integer(unsigned(i_rd2_addr)));
		END IF;
	END PROCESS read_proc;

END ARCHITECTURE behavioral;

