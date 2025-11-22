LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_unit IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		-- Data Inputs
		i_pc_id        : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_pc4_id       : IN STD_LOGIC_VECTOR(31 DOWNTO 0); 
		i_rs1_data_id  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rs2_data_id  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_immediate_id : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_funct3_id    : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct12_id   : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		i_uimm_id      : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

		-- Control Signals
		i_ex_op_type_id : IN t_ExecControl;
		i_src_a_id      : IN t_SrcA;
		i_src_b_id      : IN t_SrcB;
		i_unit_en_id    : IN t_OperationUnit;

		-- Pass-through Control Signals
		i_mem_read_id  : IN STD_LOGIC;
		i_mem_write_id : IN STD_LOGIC;
		i_reg_write_id : IN STD_LOGIC;
		i_wb_src_id    : IN t_WritebackSrc;

		i_rd_addr_id  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

		i_rd_addr_mem : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_addr_wb  : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_data_mem : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rd_data_wb  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                i_reg_write_mem : IN STD_LOGIC;
                i_reg_write_wb : IN STD_LOGIC;

		o_pc_redirect    : OUT STD_LOGIC;
		o_pc_target_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs 
		o_ex_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs2_data  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc4       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_funct3    : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		o_mem_read  : OUT STD_LOGIC;
		o_mem_write : OUT STD_LOGIC;
		o_reg_write : OUT STD_LOGIC;
		o_wb_src    : OUT t_WritebackSrc;
		o_rd_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY execution_unit;

ARCHITECTURE structural OF execution_unit IS
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	COMPONENT ex_decode_unit IS
		PORT (
			i_ex_op_type   : IN  t_ExecControl;
			i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_csr_write_en : OUT STD_LOGIC;
			o_trap_type    : OUT t_TrapType;
			o_alu_command  : OUT t_AluOpcodes;
			o_csr_command  : OUT t_CsrOpcodes
		);
	END COMPONENT ex_decode_unit;

	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	COMPONENT branch_condition_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_condition_unit;

	COMPONENT forwarding_unit IS
		PORT (
			i_rs1_addr_id  : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rs2_addr_id  : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_mem  : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
                        i_reg_write_mem : IN STD_LOGIC;
			i_rd_addr_wb   : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
                        i_reg_write_wb : IN STD_LOGIC;
			o_fwd_a_select : OUT t_Forward;
			o_fwd_b_select : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	COMPONENT csr_unit IS
		PORT (
			i_clk            : IN  STD_LOGIC;
			i_rst            : IN  STD_LOGIC;
			i_write_en       : IN  STD_LOGIC;
			i_csr_op         : IN  t_CsrOpcodes;
			i_csr_addr       : IN  STD_LOGIC_VECTOR(CSR_ADDR_WIDTH - 1 DOWNTO 0);
			i_csr_data       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_triggered : IN  STD_LOGIC;
			i_pc_at_trap     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_cause_code     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mtvec          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_read_data      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT csr_unit;

	-- Internal Signals
	SIGNAL s_input_a : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_command : t_AluOpcodes;
	SIGNAL s_alu_flags : t_AluFlags;
	SIGNAL s_alu_result_raw : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_plus_imm : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_is_branch : STD_LOGIC;
	SIGNAL s_branch_taken : STD_LOGIC;

	SIGNAL s_fwd_a_select : t_Forward;
	SIGNAL s_fwd_b_select : t_Forward;

	SIGNAL s_input_a_id : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_input_b : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_input_b_id : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_csr_write_en : STD_LOGIC;
	SIGNAL s_csr_command : t_CsrOpcodes;
	SIGNAL s_csr_output : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_trap_type : t_TrapType;
	SIGNAL s_trap_trigger : STD_LOGIC;
	SIGNAL s_cause_code : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mtvec_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
        SIGNAL s_csr_addr_mux : STD_LOGIC_VECTOR(11 DOWNTO 0);
BEGIN

	-- Forwarding MUX
	WITH i_src_a_id SELECT
		s_input_a_id <= i_rs1_data_id WHEN SRC_A_RS1,
		i_pc_id WHEN SRC_A_PC,
		((31 DOWNTO 5 => '0') & i_uimm_id) WHEN SRC_A_UIMM,
		x"00000000" WHEN OTHERS; -- SRC_A_ZERO

	FORWARD_PROC_A : PROCESS (s_fwd_a_select, s_input_a_id, i_rd_data_mem, i_rd_data_wb, i_src_a_id)
	BEGIN
		s_input_a <= s_input_a_id;
		IF i_src_a_id = SRC_A_RS1 THEN
			CASE s_fwd_a_select IS
				WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_data_mem;
				WHEN FWD_FROM_MEM_WB => s_input_a <= i_rd_data_wb;
				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END PROCESS;

	WITH i_src_b_id SELECT
		s_input_b <= s_input_b_id WHEN SRC_B_RS2,
		i_immediate_id WHEN OTHERS; -- SRC_B_IMM

	WITH s_fwd_b_select SELECT
		s_input_b_id <= i_rs2_data_id WHEN FWD_NONE,
		i_rd_data_mem WHEN FWD_FROM_EX_MEM,
		i_rd_data_wb WHEN FWD_FROM_MEM_WB;

	-- Trap Handelling
	s_trap_trigger <= '1' WHEN (s_trap_type /= TRAP_NONE) ELSE '0';
	WITH s_trap_type SELECT
		s_cause_code <= x"0000000B" WHEN TRAP_CALL,
		x"00000003" WHEN TRAP_BREAK,
		x"00000000" WHEN OTHERS;
        s_csr_addr_mux <= x"341" WHEN s_trap_type = TRAP_MRET ELSE i_funct12_id;

	-- Stage 2 Decode Unit
	U_EX_DECODE_UNIT : ex_decode_unit
	PORT MAP(
		i_ex_op_type   => i_ex_op_type_id,
		i_funct3       => i_funct3_id,
		i_funct12      => i_funct12_id,
		i_src_a_data   => s_input_a,
		o_trap_type    => s_trap_type,
		o_csr_write_en => s_csr_write_en,
		o_alu_command  => s_alu_command,
		o_csr_command  => s_csr_command
	);

	-- Forwarding Unit
	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id => i_rs1_addr_id,
		i_rs2_addr_id => i_rs2_addr_id,
		i_rd_addr_mem => i_rd_addr_mem,
                i_reg_write_mem => i_reg_write_mem,
		i_rd_addr_wb  => i_rd_addr_wb,
                i_reg_write_wb => i_reg_write_wb,
		o_fwd_a_select => s_fwd_a_select,
		o_fwd_b_select => s_fwd_b_select
	);

	-- Main ALU
	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_input_a,
		i_alu_y      => s_input_b,
		o_result     => s_alu_result_raw,
		o_flags      => s_alu_flags
	);
	-- CSR Unit
	U_CSR_UNIT : csr_unit
	PORT MAP(
		i_clk            => i_clk,
		i_rst            => i_rst,
		i_write_en       => s_csr_write_en,
		i_csr_op         => s_csr_command,
		i_csr_data       => s_input_a,
		i_csr_addr       => s_csr_addr_mux,
		i_trap_triggered => s_trap_trigger,
		i_pc_at_trap     => i_pc_id,
		i_cause_code     => s_cause_code,
		o_mtvec          => s_mtvec_val,
		o_read_data      => s_csr_output
	);

	-- Branch Adder
	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_pc_id,
		i_imm            => i_immediate_id,
		o_branch_address => s_pc_plus_imm
	);

	-- Instantiate the Branch Condition checker
        s_is_branch <= '1' WHEN i_ex_op_type_id = OP_BRANCH ELSE '0';
	U_BRANCH_CONDITION : branch_condition_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_funct3_id,
		i_branch_active => s_is_branch,
		o_branch_taken  => s_branch_taken
	);

	PROCESS (s_trap_trigger, s_mtvec_val, i_ex_op_type_id, i_src_a_id, s_alu_result_raw, s_pc_plus_imm, s_branch_taken, s_csr_output, s_trap_type)
	BEGIN
		-- Defaults
		o_pc_redirect <= '0';
		o_pc_target_addr <= s_pc_plus_imm; 

		-- 1. Traps (Highest Priority)
		IF s_trap_trigger = '1' THEN
			o_pc_redirect <= '1';
                        IF s_trap_type = TRAP_MRET THEN 
                                o_pc_target_addr <=s_csr_output;
                        ELSE 
                                o_pc_target_addr <= s_mtvec_val;
                        END IF;

                -- 2. Jumps (Unconditional)
		ELSIF i_ex_op_type_id = OP_JUMP THEN
			o_pc_redirect <= '1'; 
			IF i_src_a_id = SRC_A_RS1 THEN
				o_pc_target_addr <= s_alu_result_raw(31 DOWNTO 1) & '0';
			ELSE
				o_pc_target_addr <= s_pc_plus_imm;
			END IF;

                -- 3. Branches (Conditional)
		ELSIF i_ex_op_type_id = OP_BRANCH THEN
			IF s_branch_taken = '1' THEN
				o_pc_redirect <= '1';
				o_pc_target_addr <= s_pc_plus_imm;
			END IF;
		END IF;
	END PROCESS;

	-- Final ALU/CSR result to pass to the next stage
	WITH i_unit_en_id SELECT
		o_ex_result <= s_csr_output WHEN UNIT_CSR,
		s_alu_result_raw WHEN UNIT_ALU,
		(OTHERS => '0') WHEN OTHERS;

	-- Pass-through signals to the EX/MEM register
	o_rs2_data <= s_input_b_id;
	o_pc4 <= i_pc4_id;
	o_mem_read <= i_mem_read_id;
	o_mem_write <= i_mem_write_id;
	o_reg_write <= i_reg_write_id;
	o_wb_src <= i_wb_src_id;
	o_rd_addr <= i_rd_addr_id;
	o_funct3 <= i_funct3_id;

END ARCHITECTURE structural;

