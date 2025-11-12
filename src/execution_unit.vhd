LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_unit IS
	PORT (
		-- Data Inputs
		i_pc : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rs1_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rs2_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_immediate : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);

		-- Control Signals for EX Stage
		i_exec_control : IN t_ExecControl;
		i_alu_src_a : IN t_AluSrc_A;
		i_alu_src_b : IN t_AluSrc_B;
		i_branch : IN STD_LOGIC;

		-- Control Signals to be passed through to MEM/WB stages
		i_mem_read_ex : IN STD_LOGIC;
		i_mem_write_ex : IN STD_LOGIC;
		i_reg_write_ex : IN STD_LOGIC;
		i_wb_src_ex : IN t_WritebackSrc;
		i_rd_addr_ex : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

		-- Branching Outputs
		o_branch_taken : OUT STD_LOGIC;

		-- Data Outputs to EX/MEM Register
		o_alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs2_data_mem : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Pass through for SW instruction

		-- Control Signals for MEM/WB Stages
		o_mem_read_mem : OUT STD_LOGIC;
		o_mem_write_mem : OUT STD_LOGIC;
		o_reg_write_mem : OUT STD_LOGIC;
		o_wb_src_mem : OUT t_WritebackSrc;
		o_rd_addr_mem : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY execution_unit;

ARCHITECTURE structural OF execution_unit IS
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN t_AluOpcodes;
			i_alu_x : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags : OUT t_AluFlags
		);
	END COMPONENT alu;

	COMPONENT alu_control_unit IS
		PORT (
			i_exec_control : IN t_ExecControl;
			i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			o_alu_command : OUT t_AluOpcodes
		);
	END COMPONENT alu_control_unit;

	COMPONENT branch_adder IS
		PORT (
			i_pc : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	COMPONENT branch_condition_unit IS
		PORT (
			i_flags : IN t_AluFlags;
			i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN STD_LOGIC;
			o_branch_taken : OUT STD_LOGIC
		);
	END COMPONENT branch_condition_unit;
	SIGNAL s_alu_input_a : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_input_b : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_command : t_AluOpcodes;
	SIGNAL s_alu_flags : t_AluFlags;
	SIGNAL s_branch_address : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN

	-- Mux for the first ALU operand (A)
	WITH i_alu_src_a SELECT
		s_alu_input_a <= i_rs1_data WHEN ALU_A_RS1,
		i_pc WHEN ALU_A_PC,
		(OTHERS => '0') WHEN OTHERS;

	-- Mux for the second ALU operand (B)
	WITH i_alu_src_b SELECT
		s_alu_input_b <= i_rs2_data WHEN ALU_B_RS2,
		i_immediate WHEN ALU_B_IMM,
		(OTHERS => '0') WHEN OTHERS;

	-- ALU Control Unit
	U_ALU_CONTROL : alu_control_unit
	PORT MAP(
		i_exec_control => i_exec_control,
		i_funct3 => i_funct3,
		i_funct7 => i_funct7,
		o_alu_command => s_alu_command
	);

	-- Main ALU
	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x => s_alu_input_a,
		i_alu_y => s_alu_input_b,
		o_result => o_alu_result,
		o_flags => s_alu_flags
	);

	-- Branch Adder
	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc => i_pc,
		i_imm => i_immediate,
		o_branch_address => s_branch_address -- This would be used by PC update logic
	);

	-- Branch Condition Unit
	U_BRANCH_CONDITION : branch_condition_unit
	PORT MAP(
		i_flags => s_alu_flags,
		i_funct3 => i_funct3,
		i_branch_active => i_branch,
		o_branch_taken => o_branch_taken
	);

	-- These signals are not used in the EX stage, they just flow through to later stages.
	o_rs2_data_mem <= i_rs2_data;
	o_mem_read_mem <= i_mem_read_ex;
	o_mem_write_mem <= i_mem_write_ex;
	o_reg_write_mem <= i_reg_write_ex;
	o_wb_src_mem <= i_wb_src_ex;
	o_rd_addr_mem <= i_rd_addr_ex;

END ARCHITECTURE structural;

