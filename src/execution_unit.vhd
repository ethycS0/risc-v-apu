LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_unit IS
	PORT (
		-- Data Inputs
		i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_pc4            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); -- Pass-through for JAL/JALR
		i_rs1_data       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rs2_data       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_immediate      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_funct3         : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct7         : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);

		-- Control Signals
		i_alu_op_type    : IN  t_ExecControl;
		i_alu_src_a      : IN  t_AluSrc_A;
		i_alu_src_b      : IN  t_AluSrc_B;
		i_pc_src         : IN  t_PcSrc;

		-- Pass-through Control Signals
		i_mem_read       : IN  STD_LOGIC;
		i_mem_write      : IN  STD_LOGIC;
		i_reg_write      : IN  STD_LOGIC;
		i_wb_src         : IN  t_WritebackSrc;

		i_rd_addr        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_rs1_addr       : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rs2_addr       : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

		i_rd_addr_ex_mem : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_addr_mem_wb : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_ex_mem      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rd_mem_wb      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs to Hazard Unit and PC Update Logic
		o_branch_taken   : OUT STD_LOGIC;
		o_pc_target_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs 
		o_alu_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs2_data       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc4            : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_funct3         : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		o_mem_read       : OUT STD_LOGIC;
		o_mem_write      : OUT STD_LOGIC;
		o_reg_write      : OUT STD_LOGIC;
		o_wb_src         : OUT t_WritebackSrc;
		o_rd_addr        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
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

	COMPONENT alu_control IS
		PORT (
			i_alu_op_type : IN  t_ExecControl;
			i_funct3      : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct7      : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			o_alu_command : OUT t_AluOpcodes
		);
	END COMPONENT alu_control;

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
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

			i_rd_addr_ex_mem : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_mem_wb : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

			o_fwd_a_select   : OUT t_Forward;
			o_fwd_b_select   : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	-- Internal Signals
	SIGNAL s_alu_input_a    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_command    : t_AluOpcodes;
	SIGNAL s_alu_flags      : t_AluFlags;
	SIGNAL s_alu_result_raw : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_plus_imm    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_is_branch      : STD_LOGIC;

	SIGNAL s_fwd_a_select   : t_Forward;
	SIGNAL s_fwd_b_select   : t_Forward;

	SIGNAL s_alu_input_a_id : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_input_b_id : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_rs2_data_fwd   : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN

	-- Input Mux for ALU Operand A
	WITH i_alu_src_a SELECT
		s_alu_input_a_id <= i_rs1_data WHEN ALU_A_RS1,
		i_pc WHEN ALU_A_PC,
		x"00000000" WHEN OTHERS; -- ALU_A_ZERO

	-- Input Mux for ALU Operand B
	WITH i_alu_src_b SELECT
		s_alu_input_b_id <= s_rs2_data_fwd WHEN ALU_B_RS2,
		i_immediate WHEN OTHERS; -- ALU_B_IMM

	-- Instantiate ALU Control Unit
	U_ALU_CONTROL : alu_control
	PORT MAP(
		i_alu_op_type => i_alu_op_type,
		i_funct3      => i_funct3,
		i_funct7      => i_funct7,
		o_alu_command => s_alu_command
	);

	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id    => i_rs1_addr,
		i_rs2_addr_id    => i_rs2_addr,

		i_rd_addr_ex_mem => i_rd_addr_ex_mem,
		i_rd_addr_mem_wb => i_rd_addr_mem_wb,

		o_fwd_a_select   => s_fwd_a_select,
		o_fwd_b_select   => s_fwd_b_select
	);

	WITH s_fwd_a_select SELECT
		s_alu_input_a <= s_alu_input_a_id WHEN FWD_NONE,
		i_rd_ex_mem WHEN FWD_FROM_EX_MEM,
		i_rd_mem_wb WHEN FWD_FROM_MEM_WB;

	WITH s_fwd_b_select SELECT
		s_rs2_data_fwd <= i_rs2_data WHEN FWD_NONE,
		i_rd_ex_mem WHEN FWD_FROM_EX_MEM,
		i_rd_mem_wb WHEN FWD_FROM_MEM_WB;

	-- Instantiate the main ALU
	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_alu_input_a,
		i_alu_y      => s_alu_input_b_id,
		o_result     => s_alu_result_raw,
		o_flags      => s_alu_flags
	);

	-- Instantiate the dedicated adder for PC + immediate
	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_pc,
		i_imm            => i_immediate,
		o_branch_address => s_pc_plus_imm
	);

	-- Control signal to activate the branch condition check
	s_is_branch <= '1' WHEN i_pc_src = PC_SRC_BRANCH ELSE '0';

	-- Instantiate the Branch Condition checker
	U_BRANCH_CONDITION : branch_condition_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_funct3,
		i_branch_active => s_is_branch,
		o_branch_taken  => o_branch_taken
	);

	-- Mux for the final PC target address
	WITH i_alu_op_type SELECT
		o_pc_target_addr <= s_alu_result_raw WHEN OP_JUMP, -- Covers JALR
		s_pc_plus_imm WHEN OTHERS; -- Covers JAL and Branches

	-- Final ALU result to pass to the next stage
	o_alu_result <= s_alu_result_raw;

	-- Pass-through signals to the EX/MEM register
	o_rs2_data   <= s_rs2_data_fwd;
	o_pc4        <= i_pc4;
	o_mem_read   <= i_mem_read;
	o_mem_write  <= i_mem_write;
	o_reg_write  <= i_reg_write;
	o_wb_src     <= i_wb_src;
	o_rd_addr    <= i_rd_addr;
	o_funct3     <= i_funct3;

END ARCHITECTURE structural;

