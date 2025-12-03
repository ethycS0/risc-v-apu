LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY hazard_detection_unit IS
	PORT (
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

		i_rd_addr_ex  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_mem_read_ex : IN STD_LOGIC;

		o_pipeline_stall : OUT STD_LOGIC
	);
END ENTITY hazard_detection_unit;

ARCHITECTURE behavioral OF hazard_detection_unit IS

	SIGNAL s_stall_condition : STD_LOGIC;
BEGIN

	s_stall_condition <= '1' WHEN (i_mem_read_ex = '1') AND
		(to_integer(unsigned(i_rd_addr_ex)) /= 0) AND
		((i_rd_addr_ex = i_rs1_addr_id) OR
		(i_rd_addr_ex = i_rs2_addr_id))
		ELSE '0';

	o_pipeline_stall <= s_stall_condition;

END ARCHITECTURE behavioral;

