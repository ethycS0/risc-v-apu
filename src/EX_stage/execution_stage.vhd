--! @file execution_stage.vhd
--! @brief Execution (EX) pipeline stage for the RISC-V processor.
--! @author ethycS
--! @details This module structurally coordinates the core execution logic. It instantiates the
--! ALU, Branch Adder, Branch Control Unit, CSR Unit, and Forwarding Unit.
--!
--! Key features and security integrations:
--! - **Operand Multiplexing and Forwarding**: Resolves register/CSR hazards by selecting between GPR register read data,
--!   PC, UIMMs, and forwarded results from EX/MEM or MEM/WB pipeline stages.
--! - **Zicfilp (Landing Pads)**:
--!   - Checks landing pad validity: if expecting a landing pad (`elp_active` is high) and landing pads are enabled (`s_lpad_en`),
--!     the current instruction must be `lpad` (`OP_LPAD`) and the label comparison subtraction must be zero. If not, it raises `EX_LPAD_FAULT`.
--!   - Generates `next_elp` on indirect jumps (`JALR` with `src_a = SRC_A_RS1`), unless the jump is through link/return registers
--!     `x1` (ra), `x5` (t0), or `x7` (t2), which are landing pad exempt (`s_lpad_exempt`).
--! - **Smcfiss (Shadow Stack)**:
--!   - Intercepts shadow stack instructions (`CSR_SSW` / `CSR_SSR`).
--!   - If shadow stack is disabled (`s_ss_en = '0'`), memory requests are blocked.
--!   - On shadow stack pop (`CSR_SSR`), the expected return address (read from register file operand A) is routed to memory stage
--!     via `rs2_data` to be validated against the memory pop result in the writeback stage.
--! - **Critical CSR Updates (PMP & Security)**: Detects updates to critical security registers (PMP configuration registers or `mseccfg`).
--!   On write, it triggers an immediate pipeline flush redirecting back to the current PC (or PC+4 from WB stage feedback) so subsequent
--!   instructions are re-evaluated under the new security rules.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_stage IS
	PORT (
		i_clk            : IN  STD_LOGIC;                     --! Global clock (rising-edge active)
		i_rst            : IN  STD_LOGIC;                     --! Asynchronous active-high reset signal

		o_pipeline_flush : OUT STD_LOGIC;                     --! Pipeline flush strobe (clears IF/ID, ID/EX registers)

		i_id_ex_bus      : IN  t_id_ex_data;                  --! Input bus from ID stage (operands and control signals)
		i_wb_ex_bus      : IN  t_wb_ex_fb;                    --! Writeback feedback bus (traps, mret, CSR writeback, forward data)
        
		i_rd_mem_bus     : IN  t_rd_reg_data;                 --! Destination register data currently in MEM stage (for forwarding)
		i_rd_wb_bus      : IN  t_rd_reg_data;                 --! Destination register data currently in WB stage (for forwarding)

		i_csr_mem_bus    : IN  t_csr_reg_data;                --! CSR writebus currently in MEM stage (for CSR forwarding)
		i_csr_wb_bus     : IN  t_csr_reg_data;                --! CSR writebus currently in WB stage (for CSR forwarding)

		o_ex_pmp_csr     : OUT t_ex_pmp_data;                 --! PMP configuration settings exported to PMP checking logic
		o_ex_if_bus      : OUT t_ex_if_data;                  --! Redirection target and ELP configuration back to Fetch stage
		o_ex_mem_bus     : OUT t_ex_mem_data                  --! Output bus to MEM stage pipeline register
	);
END ENTITY execution_stage;

ARCHITECTURE structural OF execution_stage IS

	--! ALU component declaration
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	--! Execution Stage Control Unit component declaration
	COMPONENT ex_control_unit IS
		PORT (
			i_opr_type     : IN  t_OprType;
			i_reg_write_en : IN  STD_LOGIC;
			i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_csr_write_en : OUT STD_LOGIC;
			o_trap_type    : OUT t_fault_tag;
			o_alu_command  : OUT t_AluOpcodes;
			o_csr_command  : OUT t_CsrOpcodes
		);
	END COMPONENT ex_control_unit;

	--! Branch Target Adder component declaration
	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	--! Branch Control Unit component declaration
	COMPONENT branch_control_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_control_unit;

	--! Forwarding Unit component declaration
	COMPONENT forwarding_unit IS
		PORT (
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_csr_addr_id    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_rd_addr_mem    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_mem  : IN  STD_LOGIC;
			i_csr_addr_mem   : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_csr_write_mem  : IN  STD_LOGIC;
			i_rd_addr_wb     : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_wb   : IN  STD_LOGIC;
			i_csr_addr_wb    : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_csr_write_wb   : IN  STD_LOGIC;
			o_csr_fwd_select : OUT t_Forward;
			o_fwd_a_select   : OUT t_Forward;
			o_fwd_b_select   : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	--! CSR Unit component declaration
	COMPONENT csr_unit IS
		PORT (
			i_clk         : IN  STD_LOGIC;
			i_rst         : IN  STD_LOGIC;
			i_csr_raddr   : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			o_csr_rdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_csr_wbus    : IN  t_csr_reg_data;
			i_trap        : IN  STD_LOGIC;
			i_trap_pc     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_mtval  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_mcause : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_minstret    : IN  STD_LOGIC;
			i_mret        : IN  STD_LOGIC;
			o_pmp_csr     : OUT t_ex_pmp_data;
			o_lpad_en     : OUT STD_LOGIC;
			o_ss_en       : OUT STD_LOGIC;
			o_mtvec       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mepc        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT csr_unit;

	SIGNAL s_alu_command : t_AluOpcodes;             --! Command opcode routed to ALU
	SIGNAL s_alu_flags   : t_AluFlags;               --! Status flags output by ALU
	SIGNAL s_alu_result  : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Result data output by ALU

	SIGNAL s_is_branch     : STD_LOGIC;                     --! Branch active strobe
	SIGNAL s_branch_taken  : STD_LOGIC;                     --! Asserted when branch condition evaluates as true
	SIGNAL s_branch_target : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Computed target address for branches/jumps

	SIGNAL s_fwd_a_select   : t_Forward;                    --! Operand A forward select signal
	SIGNAL s_fwd_b_select   : t_Forward;                    --! Operand B forward select signal
	SIGNAL s_csr_fwd_select : t_Forward;                    --! CSR read path forward select signal

	SIGNAL s_ss_instr     : STD_LOGIC;                      --! Asserted for shadow stack instructions (push/pop)
	SIGNAL s_lpad_exempt  : STD_LOGIC;                      --! Asserted if jump register is landing pad exempt (x1, x5, x7)

	SIGNAL s_input_a              : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input A data routed to ALU
	SIGNAL s_input_b              : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input B data routed to ALU
	SIGNAL s_rs2_data_fwd         : STD_LOGIC_VECTOR(31 DOWNTO 0); --! RS2 data after forwarding select
	SIGNAL s_actual_csr_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0); --! CSR data after forwarding select
	SIGNAL s_new_csr_value        : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Resulting data computed for CSR writes

	SIGNAL s_csr_write_en : STD_LOGIC;                     --! Decoded CSR write enable flag
	SIGNAL s_csr_command  : t_CsrOpcodes;                   --! Decoded CSR opcode command
	SIGNAL s_csr_addr_mux : STD_LOGIC_VECTOR(11 DOWNTO 0); --! Multiplexed CSR read address
	SIGNAL s_csr_output   : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read data output directly by CSR unit

	SIGNAL s_trap_type    : t_fault_tag;                   --! Trap fault tag from EX control unit
	SIGNAL s_trap_mtval   : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Mtval value for exceptions
	SIGNAL s_mtvec_val    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap vector base address from CSR unit
	SIGNAL s_mepc_val     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Return address from mepc in CSR unit
	SIGNAL s_lpad_en      : STD_LOGIC;                     --! Landing Pad globally enabled status
	SIGNAL s_ss_en        : STD_LOGIC;                     --! Shadow Stack globally enabled status
	SIGNAL s_crit_csr     : STD_LOGIC;                     --! Asserted on writes to critical CSR registers
	SIGNAL s_fault_tag    : t_fault_tag;                   --! Fault status for current execution instruction

BEGIN
	U_EX_DECODE_UNIT : ex_control_unit
	PORT MAP(
		i_opr_type     => i_id_ex_bus.opr_type,
		i_reg_write_en => i_id_ex_bus.reg_write,
		i_funct3       => i_id_ex_bus.funct3,
		i_funct12      => i_id_ex_bus.funct12,
		i_src_a_data   => s_input_a,
		o_trap_type    => s_trap_type,
		o_csr_write_en => s_csr_write_en,
		o_alu_command  => s_alu_command,
		o_csr_command  => s_csr_command
	);

	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id   => i_id_ex_bus.rs1_addr,
		i_rs2_addr_id   => i_id_ex_bus.rs2_addr,
		i_csr_addr_id   => s_csr_addr_mux,
		i_rd_addr_mem   => i_rd_mem_bus.rd_addr,
		i_reg_write_mem => i_rd_mem_bus.reg_write_en,
		i_rd_addr_wb    => i_rd_wb_bus.rd_addr,
		i_reg_write_wb  => i_rd_wb_bus.reg_write_en,
		i_csr_addr_mem  => i_csr_mem_bus.csr_addr,
		i_csr_addr_wb   => i_csr_wb_bus.csr_addr,
		i_csr_write_mem => i_csr_mem_bus.csr_write_en,
		i_csr_write_wb  => i_csr_wb_bus.csr_write_en,
		o_csr_fwd_select => s_csr_fwd_select,
		o_fwd_a_select  => s_fwd_a_select,
		o_fwd_b_select  => s_fwd_b_select
	);

	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_input_a,
		i_alu_y      => s_input_b,
		o_result     => s_alu_result,
		o_flags      => s_alu_flags
	);

	U_CSR_UNIT : csr_unit
	PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,

		i_csr_raddr => s_csr_addr_mux,
		o_csr_rdata => s_csr_output,

		i_csr_wbus    => i_wb_ex_bus.csr_bus,
		i_trap        => i_wb_ex_bus.trap,
		i_trap_pc     => i_wb_ex_bus.mepc,
		i_trap_mtval  => i_wb_ex_bus.mtval,
		i_trap_mcause => i_wb_ex_bus.mcause,
		i_minstret    => i_wb_ex_bus.minstret,
		i_mret        => i_wb_ex_bus.mret,

		o_pmp_csr     => o_ex_pmp_csr,
		o_lpad_en     => s_lpad_en,
		o_ss_en       => s_ss_en,
		o_mtvec       => s_mtvec_val,
		o_mepc        => s_mepc_val
	);

	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_id_ex_bus.pc,
		i_imm            => i_id_ex_bus.immediate,
		o_branch_address => s_branch_target
	);

	U_BRANCH_CONTROL : branch_control_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_id_ex_bus.funct3,
		i_branch_active => s_is_branch,
		o_branch_taken  => s_branch_taken
	);

	--! @brief Process to select input operands A and B with forwarding bypass.
	--! @details Selects sources for Operand A (RS1 register, PC, UIMM) and Operand B (RS2 register, immediate),
	--! applying forwarded values from MEM/WB stages if register hazards are detected.
	P_INPUT_SEL_FWD : PROCESS (ALL)
	BEGIN
		s_input_a      <= x"00000000";
		s_input_b      <= x"00000000";
		s_rs2_data_fwd <= x"00000000";

		-- Multiplexer for Operand A
		IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
			CASE s_fwd_a_select IS
				WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_mem_bus.rd_data;
				WHEN FWD_FROM_MEM_WB => s_input_a <= i_wb_ex_bus.fwd;
				WHEN OTHERS => s_input_a <= i_id_ex_bus.rs1_data;
			END CASE;
		ELSIF i_id_ex_bus.src_a = SRC_A_PC THEN
			s_input_a <= i_id_ex_bus.pc;
		ELSIF i_id_ex_bus.src_a = SRC_A_UIMM THEN
			s_input_a <= ((31 DOWNTO 5 => '0') & i_id_ex_bus.uimm);
		END IF;

		-- Forwarding multiplexer for raw RS2 data
		CASE s_fwd_b_select IS
			WHEN FWD_FROM_EX_MEM => s_rs2_data_fwd <= i_rd_mem_bus.rd_data;
			WHEN FWD_FROM_MEM_WB => s_rs2_data_fwd <= i_wb_ex_bus.fwd;
			WHEN OTHERS  => s_rs2_data_fwd <= i_id_ex_bus.rs2_data;
		END CASE;

		-- Multiplexer for Operand B
		IF i_id_ex_bus.src_b = SRC_B_RS2 THEN
			s_input_b <= s_rs2_data_fwd;
		ELSIF i_id_ex_bus.src_b = SRC_B_IMM THEN
			s_input_b <= i_id_ex_bus.immediate;
		END IF;

	END PROCESS;

	--! @brief Process to override CSR addresses for special instructions.
	--! @details Overrides the default instruction funct12 CSR address with address 0x341 (mepc)
	--! during MRET trap returns, and 0x011 (ssp CSR) during shadow stack writes and reads.
	P_CSR_ADDR_OVERRIDE : PROCESS (ALL)
	BEGIN
		IF s_trap_type = TRAP_MRET THEN
			s_csr_addr_mux <= x"341";
		ELSIF s_csr_command = CSR_SSW OR s_csr_command = CSR_SSR THEN
			s_csr_addr_mux <= x"011";
		ELSE
			s_csr_addr_mux <= i_id_ex_bus.funct12;
		END IF;

	END PROCESS P_CSR_ADDR_OVERRIDE;

	--! @brief CSR read path hazard forwarding multiplexer.
	--! @details Resolves read-after-write CSR hazards combinationally by selecting the in-flight
	--! CSR write data if it targets the same register.
	P_CSR_FWD_MUX : PROCESS (ALL)
	BEGIN
		CASE s_csr_fwd_select IS
			WHEN FWD_FROM_EX_MEM => s_actual_csr_read_data <= i_csr_mem_bus.csr_data;
			WHEN FWD_FROM_MEM_WB => s_actual_csr_read_data <= i_csr_wb_bus.csr_data;
			WHEN OTHERS => s_actual_csr_read_data <= s_csr_output;
		END CASE;
	END PROCESS;

	--! @brief Process to detect critical CSR updates.
	--! @details Writing to critical CSRs (PMP configs/addrs, indirect PMP registers) requires a flush
	--! to update the pipeline's memory safety state before executing subsequent instructions.
	P_CSR_CRITICAL : PROCESS (ALL)
	BEGIN
		s_crit_csr <= '0';
		IF s_csr_write_en = '1' THEN
			CASE s_csr_addr_mux IS
				WHEN x"3A0" | x"3B0" | x"3B1" | x"3B2" | x"3B3" | x"351" | x"352" =>
					s_crit_csr <= '1';
				WHEN OTHERS =>
					s_crit_csr <= '0';
			END CASE;
		END IF;
	END PROCESS;

	--! @brief Process to compute new CSR values for write operations.
	--! @details Simulates standard atomic CSR updates (Write, Set, Clear) and custom shadow stack increments:
	--! - `CSR_SSW` (Push) decrements the stack pointer by 4 bytes.
	--! - `CSR_SSR` (Pop) increments the stack pointer by 4 bytes.
	P_CSR_ALU : PROCESS (ALL)
	BEGIN
		s_ss_instr <= '0';
		CASE s_csr_command IS
			WHEN CSR_RW =>
				s_new_csr_value <= s_input_a;

			WHEN CSR_RS =>
				s_new_csr_value <= s_actual_csr_read_data OR s_input_a;

			WHEN CSR_RC =>
				s_new_csr_value <= s_actual_csr_read_data AND (NOT s_input_a);

			WHEN CSR_SSW =>
				s_new_csr_value <= STD_LOGIC_VECTOR(unsigned(s_actual_csr_read_data) - 4);
				s_ss_instr <= '1';

			WHEN CSR_SSR =>
				s_new_csr_value <= STD_LOGIC_VECTOR(unsigned(s_actual_csr_read_data) + 4);
				s_ss_instr <= '1';

			WHEN OTHERS =>
				s_new_csr_value <= s_actual_csr_read_data;
		END CASE;
	END PROCESS;

	--! @brief Process to select register writeback data.
	--! @details Chooses between the ALU result, PC+4 (for JAL/JALR), and CSR read values.
	--! Handles misaligned redirection targets and shadow stack pop addresses.
	P_RD_SEL : PROCESS (ALL)
	BEGIN
		IF s_fault_tag = EX_REDIR_MISALIGNED THEN
			IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
				o_ex_mem_bus.rd_bus.rd_data <= s_alu_result(31 DOWNTO 1) & '0';
			ELSE
				o_ex_mem_bus.rd_bus.rd_data <= s_branch_target; 
			END IF;

		ELSIF i_id_ex_bus.wb_src = WB_SRC_PC4 THEN
			o_ex_mem_bus.rd_bus.rd_data <= i_id_ex_bus.pc4;

		ELSIF i_id_ex_bus.opr_unit = UNIT_CSR THEN
			IF s_csr_command = CSR_SSW THEN
				o_ex_mem_bus.rd_bus.rd_data <= s_new_csr_value;
			ELSE
				o_ex_mem_bus.rd_bus.rd_data <= s_actual_csr_read_data;
			END IF;

		ELSE
			o_ex_mem_bus.rd_bus.rd_data <= s_alu_result;
		END IF;
	END PROCESS;

	--! @brief Process to evaluate pipeline exceptions and faults.
	--! @details Performs instruction safety validations:
	--! - **Landing Pad Exception**: If expects landing pad (`elp_active`), checks that the current
	--!   instruction is `lpad` and that its label matches the expected label (ALU zero flag = 1).
	--! - **Redirection Address Misalignment**: Checks that branch/jump targets are 4-byte aligned.
	--! - **System Traps**: Propagates ECALL, EBREAK, and MRET.
	P_FAULT_TAG : PROCESS (ALL)
	BEGIN
		s_fault_tag <= i_id_ex_bus.fault_tag;
		IF i_id_ex_bus.elp_active = '1' AND s_lpad_en = '1' THEN
			IF i_id_ex_bus.opr_type /= OP_LPAD THEN
				s_fault_tag <= EX_LPAD_FAULT;
			ELSIF s_alu_flags.zero = '0' THEN
				s_fault_tag <= EX_LPAD_FAULT;
			END IF;
		ELSIF i_id_ex_bus.fault_tag = VALID THEN 
			IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_PC THEN
				IF s_branch_target(1 DOWNTO 0) /= "00" THEN
					s_fault_tag <= EX_REDIR_MISALIGNED;
				END IF;

			ELSIF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
				IF s_alu_result(1) = '1' THEN
					s_fault_tag <= EX_REDIR_MISALIGNED;
				END IF;

			ELSIF i_id_ex_bus.opr_type = OP_BRANCH AND s_branch_taken = '1' THEN
				IF s_branch_target(1) = '1' THEN
					s_fault_tag <= EX_REDIR_MISALIGNED;
				END IF;
			ELSE
				IF s_trap_type = TRAP_ECALL OR s_trap_type = TRAP_EBREAK or s_trap_type = TRAP_MRET THEN
					s_fault_tag <= s_trap_type;
				END IF;
			END IF;
		END IF;
	END PROCESS P_FAULT_TAG;

	s_is_branch <= '1' WHEN i_id_ex_bus.opr_type = OP_BRANCH ELSE '0';
	
	-- Checks if registers used in JALR are link registers (x1, x5, or x7), which are Landing Pad exempt.
	s_lpad_exempt <= '1' WHEN (i_id_ex_bus.rs1_addr = "00001" OR 
	                            i_id_ex_bus.rs1_addr = "00101" OR 
	                            i_id_ex_bus.rs1_addr = "00111") ELSE '0';

	--! @brief Process to manage PC redirections and flushes.
	--! @details Calculates next PC target for trap entries, returns, branches, and jumps.
	--! Controls `next_elp` to mandate that the next target instruction must be a landing pad,
	--! skipping the check if the source link register is landing pad exempt.
	P_PC_REDR : PROCESS (ALL)
	BEGIN
		o_ex_if_bus.pc_redirect      <= '0';
		o_ex_if_bus.next_elp         <= '0';
		o_ex_if_bus.redirect_address <= s_branch_target;

		IF i_wb_ex_bus.trap = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mtvec_val;

		ELSIF i_wb_ex_bus.mret = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mepc_val;

		ELSIF i_id_ex_bus.opr_type = OP_JUMP THEN
			o_ex_if_bus.pc_redirect <= '1' WHEN s_fault_tag = VALID ELSE '0';
			IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
				o_ex_if_bus.redirect_address <= s_alu_result(31 DOWNTO 1) & '0';
				IF s_lpad_exempt = '0' AND s_lpad_en = '1' THEN
					o_ex_if_bus.next_elp <= '1';
				END IF;

			ELSE
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;

		ELSIF i_id_ex_bus.opr_type = OP_BRANCH THEN
			IF s_branch_taken = '1' THEN
				o_ex_if_bus.pc_redirect <= '1' WHEN s_fault_tag = VALID ELSE '0';
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;

		ELSIF i_wb_ex_bus.crit_csr = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= i_wb_ex_bus.pc4;

		ELSIF s_crit_csr = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= i_id_ex_bus.pc;

		END IF;
	END PROCESS;

	-- Suppress read/write execution when shadow stack operations are disabled or if a fault is active.
	o_ex_mem_bus.mem_read  <= i_id_ex_bus.mem_read  WHEN (s_fault_tag = VALID AND NOT (s_ss_instr = '1' AND s_ss_en = '0')) ELSE '0';
	o_ex_mem_bus.mem_write <= i_id_ex_bus.mem_write WHEN (s_fault_tag = VALID AND NOT (s_ss_instr = '1' AND s_ss_en = '0')) ELSE '0';
	o_ex_mem_bus.csr_bus.csr_write_en <= s_csr_write_en WHEN (s_fault_tag = VALID) ELSE '0';
	o_ex_mem_bus.rd_bus.reg_write_en  <= i_id_ex_bus.reg_write WHEN s_fault_tag = VALID ELSE '0';

	-- Overrides rs2_data with the expected return address (Operand A) on sspop memory reads so it is validated in writeback.
	o_ex_mem_bus.rs2_data <= s_input_a WHEN (s_ss_instr = '1' AND i_id_ex_bus.mem_read = '1') ELSE s_rs2_data_fwd;
	o_ex_mem_bus.pc4      <= i_id_ex_bus.pc4;
	o_ex_mem_bus.wb_src   <= i_id_ex_bus.wb_src;
	o_ex_mem_bus.rd_bus.rd_addr <= i_id_ex_bus.rd_addr;
	o_ex_mem_bus.funct3   <= i_id_ex_bus.funct3;
	o_ex_mem_bus.pc       <= i_id_ex_bus.pc;

	o_ex_mem_bus.csr_bus.csr_data <= s_new_csr_value;
	o_ex_mem_bus.csr_bus.csr_addr <= s_csr_addr_mux;
	o_ex_mem_bus.fault_tag        <= s_fault_tag;

	o_ex_mem_bus.ss_instr <= '1' WHEN (s_fault_tag = VALID AND s_ss_instr = '1' AND s_ss_en = '1') ELSE '0';

	-- Asserts pipeline flush on faults or branch/jump redirects
	o_pipeline_flush <= '1' WHEN (s_fault_tag /= VALID OR o_ex_if_bus.pc_redirect = '1') ELSE '0';

END ARCHITECTURE structural;

