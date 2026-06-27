--! @file instruction_fetch_stage.vhd
--! @brief Instruction Fetch (IF) pipeline stage for the RISC-V processor.
--! @author ethycS
--! @details This module manages the Program Counter (PC), generates instruction memory
--! read addresses, and fetches instruction data. It incorporates alignment logic
--! to handle the 1-cycle read latency of BRAM memory, a skid buffer to prevent
--! instruction loss during pipeline stalls, branch/jump redirection, and security
--! integrations (PMP fetch fault detection and Zicfilp Landing Pad propagation).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_fetch_stage IS
	PORT (
		i_clk            : IN    STD_LOGIC; --! System clock signal (rising-edge active)
		i_rst            : IN    STD_LOGIC; --! Asynchronous active-high reset signal
		i_stall          : IN    STD_LOGIC; --! Pipeline stall signal (freezes PC and alignment registers)

		o_instr_addr    : OUT   STD_LOGIC_VECTOR(31 DOWNTO 0); --! Address sent to instruction memory/BRAM
		i_instr_data    : IN    STD_LOGIC_VECTOR(31 DOWNTO 0); --! 32-bit instruction data returned from memory

		i_pmp_fault      : IN    STD_LOGIC; --! Physical Memory Protection fault signal (fetch violation)
		i_ex_if_bus      : IN    t_ex_if_data; --! Control feedback bus from Execution stage for redirections
		o_if_id_bus      : OUT   t_if_id_data --! Output pipeline register bus to Instruction Decode stage
	);
END ENTITY instruction_fetch_stage;

ARCHITECTURE behavioral OF instruction_fetch_stage IS

	SIGNAL s_pc                     : STD_LOGIC_VECTOR(31 DOWNTO 0) := RESET_ADDRESS; --! Active Program Counter register
	SIGNAL s_pc_plus_4              : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Next sequential PC (s_pc + 4)

	SIGNAL s_elp_current            : STD_LOGIC := '0'; --! Current cycle expected landing pad status flag
	SIGNAL s_skid_valid             : STD_LOGIC := '0'; --! Skid buffer occupancy flag (1 = data in skid buffer is valid)
	SIGNAL s_flush_pending          : STD_LOGIC := '0'; --! Redirection flush request pending (marks next instruction as NOP)

	SIGNAL s_pc_aligned             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Program Counter aligned to match memory read latency
	SIGNAL s_elp_aligned            : STD_LOGIC := '0'; --! Expected Landing Pad flag aligned to match memory read latency
	SIGNAL s_pmp_fault_aligned      : STD_LOGIC := '0'; --! PMP fetch fault status aligned to match memory read latency

	SIGNAL s_skid_buffer_pc         : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Skid buffer register to store the aligned PC
	SIGNAL s_skid_buffer_instr      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Skid buffer register to store the instruction data
	SIGNAL s_skid_buffer_elp        : STD_LOGIC := '0'; --! Skid buffer register to store the aligned expected landing pad flag
	SIGNAL s_skid_buffer_pmp_fault  : STD_LOGIC := '0'; --! Skid buffer register to store the aligned PMP fault status

BEGIN

	s_pc_plus_4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4);
	o_instr_addr <= s_pc;

	--! @brief Process to manage PC updates, increments, and redirections.
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

	--! @brief Process to align PC and status signals to instruction memory read latency (1 cycle).
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
                                        s_pc_aligned <= (OTHERS => '0');
				ELSE
                                        s_pc_aligned <= s_pc;
					s_pmp_fault_aligned <= i_pmp_fault;
				END IF;

				s_elp_aligned <= s_elp_current;
			END IF;
		END IF;
	END PROCESS;

	--! @brief Skid buffer process to capture fetched instructions and metadata during stalls.
	--! @details When a stall occurs, the memory still delivers the instruction requested
	--! in the previous cycle. This process captures it in a buffer so that it is not lost
	--! when the decode stage cannot accept it yet.
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

	--! @brief Process to track redirection flush requests.
	--! @details Asserted when a PC redirection is active. This signal is used to flush
	--! the instruction fetched right after the branch/jump (delay slot).
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

	--! @brief Process to determine and assemble the final outputs on the IF/ID pipeline bus.
	--! @details Decides whether to use the current instruction stream or the skid buffer,
	--! handles redirection flushes by inserting NOPs, and logs PMP access faults.
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
                        o_if_id_bus.pc <= (OTHERS => '0');

		ELSIF v_pmp_fault = '1' THEN
			o_if_id_bus.instruction <= C_NOP;
                        o_if_id_bus.fault_tag <= IF_ACCESS_FAULT;
		ELSE
			o_if_id_bus.fault_tag <= VALID;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;

