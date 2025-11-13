LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY forwarding_unit IS
	PORT (
		-- Source Register Addresses from ID Stage
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

		-- Destination Register and Control from EX Stage
		i_rd_addr_ex : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_reg_write_ex : IN STD_LOGIC;

		-- Destination Register and Control from MEM Stage
		i_rd_addr_mem : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_reg_write_mem : IN STD_LOGIC;

		-- Forwarding MUX select signals
		o_fwd_a_select : OUT t_Forward;
		o_fwd_b_select : OUT t_Forward
	);
END ENTITY forwarding_unit;

ARCHITECTURE behavioral OF forwarding_unit IS
BEGIN

	forwarding_logic_proc : PROCESS (ALL)
	BEGIN
		-- By default, do not forward. Use the data from the Register File.
		o_fwd_a_select <= FWD_NONE;
		o_fwd_b_select <= FWD_NONE;

		-- Forward from Execute Stage
		IF (i_reg_write_ex = '1') AND (to_integer(unsigned(i_rd_addr_ex)) /= 0) AND (i_rd_addr_ex = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_EX;

                -- Forward from Memory Stage
		ELSIF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_MEM;
		END IF;
		-- === Logic for Forwarding to ALU Input B (rs2) ===

		-- Forward from Execute Stage
		IF (i_reg_write_ex = '1') AND (to_integer(unsigned(i_rd_addr_ex)) /= 0) AND (i_rd_addr_ex = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_EX;

                -- Forward from Memory Stage
		ELSIF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_MEM;
		END IF;

	END PROCESS forwarding_logic_proc;

END ARCHITECTURE behavioral;

