LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY forwarding_unit IS
	PORT (
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

		i_rd_addr_mem   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_reg_write_mem : IN STD_LOGIC;

		i_rd_addr_wb   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_reg_write_wb : IN STD_LOGIC;

		o_fwd_a_select : OUT t_Forward;
		o_fwd_b_select : OUT t_Forward
	);
END ENTITY forwarding_unit;

ARCHITECTURE behavioral OF forwarding_unit IS
BEGIN

	forwarding_logic_proc : PROCESS (i_rs1_addr_id, i_rs2_addr_id, i_rd_addr_mem, i_rd_addr_wb, i_reg_write_mem, i_reg_write_wb)

	BEGIN
		o_fwd_a_select <= FWD_NONE;
		o_fwd_b_select <= FWD_NONE;

		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_EX_MEM;
			ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_MEM_WB;
		END IF;

		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_EX_MEM;
			ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_MEM_WB;
		END IF;

	END PROCESS forwarding_logic_proc;

END ARCHITECTURE behavioral;

