LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_fetch_stage IS
	PORT (
		i_clk   : IN STD_LOGIC;
		i_rst   : IN STD_LOGIC;
		i_stall : IN STD_LOGIC;

		o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

                i_ex_if_bus : IN t_ex_if_data;
		o_if_id_bus : OUT t_if_id_data
	);
END ENTITY instruction_fetch_stage;

ARCHITECTURE behavioral OF instruction_fetch_stage IS
	SIGNAL s_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc4 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_next_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN
	o_instr_addr <= s_pc;

	o_if_id_bus.instruction <= i_instr_data;
	o_if_id_bus.pc <= s_pc;
	o_if_id_bus.pc4 <= s_pc4;

	s_pc4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4);

	WITH i_ex_if_bus.pc_redirect SELECT
		s_next_pc <= i_ex_if_bus.redirect_address WHEN '1',
		s_pc4 WHEN OTHERS;

	P_PC_LOGIC : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_pc <= RESET_ADDRESS;
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN
				s_pc <= s_next_pc;
			END IF;
		END IF;
	END PROCESS P_PC_LOGIC;

END ARCHITECTURE behavioral;

