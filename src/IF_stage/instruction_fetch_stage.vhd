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

		i_ex_if_bus : IN  t_ex_if_data;
		o_if_id_bus : OUT t_if_id_data
	);
END ENTITY instruction_fetch_stage;

ARCHITECTURE behavioral OF instruction_fetch_stage IS
	SIGNAL s_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_plus_4 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_next_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_latency_match : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_skid_buffer_instr : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_skid_buffer_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_skid_valid : STD_LOGIC;

	SIGNAL s_flush_pending : STD_LOGIC;

	CONSTANT C_NOP : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000013";

BEGIN

	s_pc_plus_4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4);

	WITH i_ex_if_bus.pc_redirect SELECT
	s_next_pc <= i_ex_if_bus.redirect_address WHEN '1',
		s_pc_plus_4 WHEN OTHERS;

	P_PC_UPDATE : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_pc <= RESET_ADDRESS;
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN
				s_pc <= s_next_pc;
			END IF;
		END IF;
	END PROCESS;

	o_instr_addr <= s_pc;
	P_PC_ALIGNMENT : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_pc_latency_match <= RESET_ADDRESS;
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN
				s_pc_latency_match <= s_pc;
			END IF;
		END IF;
	END PROCESS;
	P_SKID_BUFFER : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_skid_valid <= '0';
			s_skid_buffer_instr <= (OTHERS => '0');
			s_skid_buffer_pc <= (OTHERS => '0');
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '1' AND s_skid_valid = '0' THEN
				s_skid_buffer_instr <= i_instr_data;
				s_skid_buffer_pc <= s_pc_latency_match;
				s_skid_valid <= '1';
			ELSIF i_stall = '0' THEN
				s_skid_valid <= '0';
			END IF;
		END IF;
	END PROCESS;
	P_FLUSH_LOGIC : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_flush_pending <= '0';
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN
				s_flush_pending <= i_ex_if_bus.pc_redirect;
			END IF;
		END IF;
	END PROCESS;

	P_OUTPUT : PROCESS (ALL)
	BEGIN
		o_if_id_bus.pc <= s_pc_latency_match;
		o_if_id_bus.pc4 <= STD_LOGIC_VECTOR(unsigned(s_pc_latency_match) + 4);

		IF s_flush_pending = '1' THEN
			o_if_id_bus.instruction <= C_NOP;

		ELSIF s_skid_valid = '1' THEN
			o_if_id_bus.instruction <= s_skid_buffer_instr;
			o_if_id_bus.pc <= s_skid_buffer_pc;
			o_if_id_bus.pc4 <= STD_LOGIC_VECTOR(unsigned(s_skid_buffer_pc) + 4);

		ELSE
			o_if_id_bus.instruction <= i_instr_data;
		END IF;
	END PROCESS;

END ARCHITECTURE behavioral;

