LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_fetch_stage IS
	PORT (
		i_clk            : IN    STD_LOGIC;
		i_rst            : IN    STD_LOGIC;
		i_stall          : IN    STD_LOGIC;

		o_instr_addr    : OUT   STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_instr_data    : IN    STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_pmp_fault      : IN    STD_LOGIC;
		i_ex_if_bus      : IN    t_ex_if_data;
		o_if_id_bus      : OUT   t_if_id_data
	);
END ENTITY instruction_fetch_stage;

ARCHITECTURE behavioral OF instruction_fetch_stage IS

	SIGNAL s_pc                     : STD_LOGIC_VECTOR(31 DOWNTO 0) := RESET_ADDRESS;
	SIGNAL s_pc_plus_4              : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_elp_current            : STD_LOGIC := '0';
	SIGNAL s_skid_valid             : STD_LOGIC := '0';
	SIGNAL s_flush_pending          : STD_LOGIC := '0';

	SIGNAL s_pc_aligned             : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_elp_aligned            : STD_LOGIC := '0';
	SIGNAL s_pmp_fault_aligned      : STD_LOGIC := '0';

	SIGNAL s_skid_buffer_pc         : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_skid_buffer_instr      : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_skid_buffer_elp        : STD_LOGIC := '0';
	SIGNAL s_skid_buffer_pmp_fault  : STD_LOGIC := '0';

BEGIN

	s_pc_plus_4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4);
	o_instr_addr <= s_pc;

	P_PC_UPDATE : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_pc <= RESET_ADDRESS;
			s_elp_current <= '0';
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN

				IF i_ex_if_bus.pc_redirect = '1' THEN
					s_pc <= i_ex_if_bus.redirect_address;
					s_elp_current <= i_ex_if_bus.next_elp;
				ELSE
					s_pc <= s_pc_plus_4;
					s_elp_current <= '0';

				END IF;
			END IF;
		END IF;
	END PROCESS;

	P_PC_ALIGNMENT : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_pc_aligned <= RESET_ADDRESS;
			s_elp_aligned <= '0';
			s_pmp_fault_aligned <= '0';
		ELSIF rising_edge(i_clk) THEN
			IF i_stall = '0' THEN
				IF i_ex_if_bus.pc_redirect = '1' THEN
					s_pmp_fault_aligned <= '0';
				ELSE
					s_pmp_fault_aligned <= i_pmp_fault;
				END IF;

				s_pc_aligned <= s_pc;
				s_elp_aligned <= s_elp_current;
			END IF;
		END IF;
	END PROCESS;

	P_SKID_BUFFER : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_skid_valid        <= '0';
			s_skid_buffer_instr <= (OTHERS => '0');
			s_skid_buffer_pc    <= (OTHERS => '0');
			s_skid_buffer_elp    <= '0';
			s_skid_buffer_pmp_fault <= '0';
		ELSIF rising_edge(i_clk) THEN
                        IF i_ex_if_bus.pc_redirect = '1' THEN
                                s_skid_valid <= '0';
			ELSIF i_stall = '1' AND s_skid_valid = '0' THEN
				s_skid_buffer_instr <= i_instr_data;
				s_skid_buffer_pc    <= s_pc_aligned;
				s_skid_buffer_elp    <= s_elp_aligned;
				s_skid_buffer_pmp_fault <= s_pmp_fault_aligned;

				s_skid_valid        <= '1';
			ELSIF i_stall = '0' THEN
				s_skid_valid        <= '0';
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
		VARIABLE v_pmp_fault : STD_LOGIC;
		VARIABLE v_elp_status : STD_LOGIC;
	BEGIN
		o_if_id_bus.pc <= s_pc_aligned;
		o_if_id_bus.pc4 <= STD_LOGIC_VECTOR(unsigned(s_pc_aligned) + 4);
		o_if_id_bus.instruction <= i_instr_data;
		o_if_id_bus.fault_tag <= VALID;

		IF s_skid_valid = '1' THEN
			o_if_id_bus.instruction <= s_skid_buffer_instr;
			o_if_id_bus.pc <= s_skid_buffer_pc;
			o_if_id_bus.pc4 <= STD_LOGIC_VECTOR(unsigned(s_skid_buffer_pc) + 4);
			v_pmp_fault := s_skid_buffer_pmp_fault;
			v_elp_status := s_skid_buffer_elp;
		ELSE
			o_if_id_bus.instruction <= i_instr_data;
			v_pmp_fault := s_pmp_fault_aligned;
			v_elp_status := s_elp_aligned;
		END IF;

                o_if_id_bus.elp_active <= v_elp_status;

		IF s_flush_pending = '1' THEN
			o_if_id_bus.instruction <= C_NOP;
			o_if_id_bus.fault_tag <= VALID;
                        o_if_id_bus.elp_active <= '0';

		ELSIF v_pmp_fault = '1' THEN
			o_if_id_bus.instruction <= C_NOP;
                        o_if_id_bus.fault_tag <= IF_ACCESS_FAULT;
		ELSE
			o_if_id_bus.fault_tag <= VALID;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;

