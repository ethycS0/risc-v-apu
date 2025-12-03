LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_stage IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		i_minstret_increment_wb : IN STD_LOGIC;

		i_id_ex_bus  : IN t_id_ex_data;
		i_rd_mem_bus : IN t_rd_reg_data;
		i_rd_wb_bus  : IN t_rd_reg_data;

		o_ex_if_bus  : OUT t_ex_if_data;
		o_ex_mem_bus : OUT t_ex_mem_data

	);
END ENTITY execution_stage;

ARCHITECTURE structural OF execution_stage IS
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	COMPONENT ex_control_unit IS
		PORT (
			i_opr_type     : IN  t_OprType;
			i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_csr_write_en : OUT STD_LOGIC;
			o_trap_type    : OUT t_TrapType;
			o_alu_command  : OUT t_AluOpcodes;
			o_csr_command  : OUT t_CsrOpcodes
		);
	END COMPONENT ex_control_unit;

	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	COMPONENT branch_control_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_control_unit;

	COMPONENT forwarding_unit IS
		PORT (
			i_rs1_addr_id   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rd_addr_mem   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_mem : IN  STD_LOGIC;
			i_rd_addr_wb    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_wb  : IN  STD_LOGIC;
			o_fwd_a_select  : OUT t_Forward;
			o_fwd_b_select  : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	COMPONENT csr_unit IS
		PORT (
			i_clk                : IN  STD_LOGIC;
			i_rst                : IN  STD_LOGIC;
			i_write_en           : IN  STD_LOGIC;
			i_minstret_increment : IN  STD_LOGIC;
			i_is_mret            : IN  STD_LOGIC;
			i_csr_op             : IN  t_CsrOpcodes;
			i_csr_addr           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_csr_data           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_triggered     : IN  STD_LOGIC;
			i_pc_at_trap         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_cause_code         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_mtval         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mtvec              : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mepc               : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_read_data          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT csr_unit;

	SIGNAL s_alu_command : t_AluOpcodes;
	SIGNAL s_alu_flags : t_AluFlags;
	SIGNAL s_alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_plus_imm : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_is_branch : STD_LOGIC;
	SIGNAL s_branch_taken : STD_LOGIC;

	SIGNAL s_fwd_a_select : t_Forward;
	SIGNAL s_fwd_b_select : t_Forward;

	SIGNAL s_input_a : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_input_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_rs2_data_fwd : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_csr_write_en : STD_LOGIC;
	SIGNAL s_csr_command : t_CsrOpcodes;
	SIGNAL s_csr_output : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_trap_type : t_TrapType;
	SIGNAL s_trap_trigger : STD_LOGIC;
	SIGNAL s_is_mret : STD_LOGIC;

	SIGNAL s_cause_code : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_trap_mtval : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mtvec_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_csr_addr_mux : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL s_mepc_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN
	P_INPUT_SEL_FWD : PROCESS (ALL)
	BEGIN
		s_input_a <= x"00000000";
		s_input_b <= x"00000000";
		s_rs2_data_fwd <= x"00000000";

		IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
			CASE s_fwd_a_select IS
				WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_mem_bus.rd_data;
				WHEN FWD_FROM_MEM_WB => s_input_a <= i_rd_wb_bus.rd_data;
				WHEN OTHERS => s_input_a <= i_id_ex_bus.rs1_data;
			END CASE;
		ELSIF i_id_ex_bus.src_a = SRC_A_PC THEN
			s_input_a <= i_id_ex_bus.pc;
		ELSIF i_id_ex_bus.src_a = SRC_A_UIMM THEN
			s_input_a <= ((31 DOWNTO 5 => '0') & i_id_ex_bus.uimm);
		END IF;

		CASE s_fwd_b_select IS
			WHEN FWD_FROM_EX_MEM => s_rs2_data_fwd <= i_rd_mem_bus.rd_data;
			WHEN FWD_FROM_MEM_WB => s_rs2_data_fwd <= i_rd_wb_bus.rd_data;
			WHEN OTHERS => s_rs2_data_fwd <= i_id_ex_bus.rs2_data;
		END CASE;

		IF i_id_ex_bus.src_b = SRC_B_RS2 THEN
			s_input_b <= s_rs2_data_fwd;
		ELSIF i_id_ex_bus.src_b = SRC_B_IMM THEN
			s_input_b <= i_id_ex_bus.immediate;
		END IF;
	END PROCESS;

	WITH i_id_ex_bus.opr_unit SELECT
	o_ex_mem_bus.rd_bus.rd_data <= s_csr_output WHEN UNIT_CSR,
	s_alu_result WHEN UNIT_ALU,
	(OTHERS => '0') WHEN OTHERS;

	s_is_mret <= '1' WHEN s_trap_type = TRAP_MRET ELSE '0';
	s_trap_trigger <= '1' WHEN (s_trap_type = TRAP_CALL OR s_trap_type = TRAP_BREAK) ELSE '0';
	s_csr_addr_mux <= x"341" WHEN s_trap_type = TRAP_MRET ELSE i_id_ex_bus.funct12;

	WITH s_trap_type SELECT
		s_cause_code <= x"0000000B" WHEN TRAP_CALL,
		x"00000003" WHEN TRAP_BREAK,
		x"00000000" WHEN OTHERS;

	WITH s_trap_type SELECT
		s_trap_mtval <= x"00000000" WHEN TRAP_CALL,
		i_id_ex_bus.pc WHEN TRAP_BREAK,
		x"00000000" WHEN OTHERS;

	U_EX_DECODE_UNIT : ex_control_unit
	PORT MAP(
		i_opr_type     => i_id_ex_bus.opr_type,
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
		i_rd_addr_mem   => i_rd_mem_bus.rd_addr,
		i_reg_write_mem => i_rd_mem_bus.reg_write_en,
		i_rd_addr_wb    => i_rd_wb_bus.rd_addr,
		i_reg_write_wb  => i_rd_wb_bus.reg_write_en,
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
		i_clk                => i_clk,
		i_rst                => i_rst,
		i_write_en           => s_csr_write_en,
		i_minstret_increment => i_minstret_increment_wb,
		i_is_mret            => s_is_mret,
		i_csr_op             => s_csr_command,
		i_csr_data           => s_input_a,
		i_csr_addr           => s_csr_addr_mux,
		i_trap_triggered     => s_trap_trigger,
		i_pc_at_trap         => i_id_ex_bus.pc,
		i_cause_code         => s_cause_code,
		i_trap_mtval         => s_trap_mtval,
		o_mtvec              => s_mtvec_val,
		o_mepc               => s_mepc_val,
		o_read_data          => s_csr_output
	);

	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_id_ex_bus.pc,
		i_imm            => i_id_ex_bus.immediate,
		o_branch_address => s_pc_plus_imm
	);

	U_BRANCH_CONTROL : branch_control_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_id_ex_bus.funct3,
		i_branch_active => s_is_branch,
		o_branch_taken  => s_branch_taken
	);

	s_is_branch <= '1' WHEN i_id_ex_bus.opr_type = OP_BRANCH ELSE '0';
	PROCESS (s_trap_trigger, s_is_mret, s_mtvec_val, s_mepc_val, i_id_ex_bus.opr_type, s_pc_plus_imm, s_branch_taken, s_alu_result, i_id_ex_bus.src_a)
	BEGIN
		o_ex_if_bus.pc_redirect <= '0';
		o_ex_if_bus.redirect_address <= s_pc_plus_imm;

		IF s_trap_trigger = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mtvec_val;

		ELSIF s_is_mret = '1' THEN
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mepc_val;

		ELSIF i_id_ex_bus.opr_type = OP_JUMP THEN
			o_ex_if_bus.pc_redirect <= '1';
			IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
				o_ex_if_bus.redirect_address <= s_alu_result(31 DOWNTO 1) & '0';
			ELSE
				o_ex_if_bus.redirect_address <= s_pc_plus_imm;
			END IF;

		ELSIF i_id_ex_bus.opr_type = OP_BRANCH THEN
			IF s_branch_taken = '1' THEN
				o_ex_if_bus.pc_redirect <= '1';
				o_ex_if_bus.redirect_address <= s_pc_plus_imm;
			END IF;
		END IF;
	END PROCESS;

	o_ex_mem_bus.rs2_data <= s_rs2_data_fwd;
	o_ex_mem_bus.pc4 <= i_id_ex_bus.pc4;
	o_ex_mem_bus.mem_read <= i_id_ex_bus.mem_read;
	o_ex_mem_bus.mem_write <= i_id_ex_bus.mem_write;
	o_ex_mem_bus.rd_bus.reg_write_en <= i_id_ex_bus.reg_write;
	o_ex_mem_bus.wb_src <= i_id_ex_bus.wb_src;
	o_ex_mem_bus.rd_bus.rd_addr <= i_id_ex_bus.rd_addr;
	o_ex_mem_bus.funct3 <= i_id_ex_bus.funct3;

END ARCHITECTURE structural;

