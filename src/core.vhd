LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY core IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		-- Instruction Memory Interface
		o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Data Memory Interface
		o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_data_write_en : OUT STD_LOGIC;
		o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END ENTITY core;

ARCHITECTURE structural OF core IS

	COMPONENT hazard_detection_unit IS
		PORT (
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_ex     : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_mem_read_ex    : IN  STD_LOGIC;
			o_pipeline_stall : OUT STD_LOGIC
		);
	END COMPONENT hazard_detection_unit;

	COMPONENT instruction_fetch_unit IS
		PORT (
			i_clk         : IN  STD_LOGIC;
			i_rst         : IN  STD_LOGIC;
			i_stall       : IN  STD_LOGIC;
			i_pc_redirect : IN  STD_LOGIC;
                        i_target_addr : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_instr_addr  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_instr_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_instruction : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc_plus_4   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT instruction_fetch_unit;

	COMPONENT instruction_decode_unit IS
		PORT (
			i_clk          : IN  STD_LOGIC;
			i_rst          : IN  STD_LOGIC;
			i_pc           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_instruction  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_wr_addr_wb   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_wr_data_wb   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_wr_en_wb     : IN  STD_LOGIC;
			o_reg_write_ex : OUT STD_LOGIC;
			o_mem_read_ex  : OUT STD_LOGIC;
			o_mem_write_ex : OUT STD_LOGIC;
			o_wb_src_ex    : OUT t_WritebackSrc;
			o_src_a_ex     : OUT t_SrcA;
			o_src_b_ex     : OUT t_SrcB;
			o_op_type_ex   : OUT t_ExecControl;
			o_ex_unit_type : OUT t_OperationUnit;
			o_immediate    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_rs1_data     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_rs2_data     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc           : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc4          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_rd_addr      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_uimm         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_rs1_addr     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_rs2_addr     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_funct3       : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
			o_funct12      : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
		);
	END COMPONENT instruction_decode_unit;

	COMPONENT execution_unit IS
		PORT (
			i_clk            : IN  STD_LOGIC;
			i_rst            : IN  STD_LOGIC;
			i_pc_id          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4_id         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs1_data_id    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs2_data_id    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_immediate_id   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_funct3_id      : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12_id     : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_uimm_id        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_ex_op_type_id  : IN  t_ExecControl;
			i_src_a_id       : IN  t_SrcA;
			i_src_b_id       : IN  t_SrcB;
			i_unit_en_id     : IN  t_OperationUnit;
			i_mem_read_id    : IN  STD_LOGIC;
			i_mem_write_id   : IN  STD_LOGIC;
			i_reg_write_id   : IN  STD_LOGIC;
			i_wb_src_id      : IN  t_WritebackSrc;
			i_rd_addr_id     : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_mem    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_wb     : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
                        i_reg_write_mem : IN STD_LOGIC;
                        i_reg_write_wb : IN STD_LOGIC;
			i_rd_data_mem    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rd_data_wb     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc_redirect    : OUT STD_LOGIC;
			o_pc_target_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_ex_result      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_rs2_data       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc4            : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_funct3         : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
			o_mem_read       : OUT STD_LOGIC;
			o_mem_write      : OUT STD_LOGIC;
			o_reg_write      : OUT STD_LOGIC;
			o_wb_src         : OUT t_WritebackSrc;
			o_rd_addr        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT execution_unit;

	COMPONENT memory_unit IS
		PORT (
			i_result_rd_ex    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs2_data_ex     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4_ex          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_funct3_ex       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_mem_read_ex     : IN  STD_LOGIC;
			i_mem_write_ex    : IN  STD_LOGIC;
			i_reg_write_ex    : IN  STD_LOGIC;
			i_wb_src_ex       : IN  t_WritebackSrc;
			i_rd_addr_ex      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_mem_read_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_addr        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_data  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_en    : OUT STD_LOGIC;
			o_mem_byte_en     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			o_result_rd_mem   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc4_mem         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_wb_src_mem      : OUT t_WritebackSrc;
			o_final_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_reg_write_mem   : OUT STD_LOGIC;
			o_rd_addr_mem     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT memory_unit;

	COMPONENT writeback_unit IS
		PORT (
			i_read_data    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rd_result    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4          : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_reg_write    : IN  STD_LOGIC;
			i_wb_src       : IN  t_WritebackSrc;
			i_rd_addr      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_reg_write_en : OUT STD_LOGIC;
			o_rd_addr      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_rd_data      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT writeback_unit;

	-- Hazards
	SIGNAL s_hz_pipeline_stall_out : STD_LOGIC;
	SIGNAL s_pipeline_flush : STD_LOGIC;

	-- || Pipeline Registers || 
	-- IF Stage Outputs -> to IF/ID Register
	SIGNAL s_if_pc_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_if_pc4_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_if_instruction_out : STD_LOGIC_VECTOR(31 DOWNTO 0);

	-- ID Stage Inputs <- from IF/ID Register
	SIGNAL s_id_pc_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_id_pc4_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_id_instruction_in : STD_LOGIC_VECTOR(31 DOWNTO 0);

	-- ID Stage Outputs -> to ID/EX Register
	SIGNAL s_id_reg_write_out, s_id_mem_read_out, s_id_mem_write_out : STD_LOGIC;
	SIGNAL s_id_wb_src_out : t_WritebackSrc;
	SIGNAL s_id_src_a_out : t_SrcA;
	SIGNAL s_id_src_b_out : t_SrcB;
	SIGNAL s_id_op_type_out : t_ExecControl;
	SIGNAL s_id_immediate_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_id_rs1_data_out, s_id_rs2_data_out, s_id_pc_out, s_id_pc4_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_id_rd_addr_out, s_id_rs1_addr_out, s_id_rs2_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_id_funct3_out : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL s_id_funct12_out : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL s_id_unit_type_out : t_OperationUnit;
	SIGNAL s_id_uimm_out : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- EX Stage Inputs <- from ID/EX Register
	SIGNAL s_ex_reg_write_in, s_ex_mem_read_in, s_ex_mem_write_in : STD_LOGIC;
	SIGNAL s_ex_wb_src_in : t_WritebackSrc;
	SIGNAL s_ex_src_a_in : t_SrcA;
	SIGNAL s_ex_src_b_in : t_SrcB;
	SIGNAL s_ex_op_type_in : t_ExecControl;
	SIGNAL s_ex_immediate_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_ex_rs1_data_in, s_ex_rs2_data_in, s_ex_pc_in, s_ex_pc4_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_ex_rd_addr_in, s_ex_rs1_addr_in, s_ex_rs2_addr_in : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_ex_funct3_in : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL s_ex_funct12_in : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL s_ex_unit_type_in : t_OperationUnit;
	SIGNAL s_ex_uimm_in : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- EX Stage Outputs -> to EX/MEM Register
	SIGNAL s_ex_pc_target_addr_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_ex_result_out, s_ex_rs2_data_out, s_ex_pc4_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_ex_mem_read_out, s_ex_mem_write_out, s_ex_reg_write_out : STD_LOGIC;
	SIGNAL s_ex_wb_src_out : t_WritebackSrc;
	SIGNAL s_ex_funct3_out : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL s_ex_rd_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- MEM Stage Inputs <- from EX/MEM Register
	SIGNAL s_mem_result_in, s_mem_rs2_data_in, s_mem_pc4_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mem_mem_read_in, s_mem_mem_write_in, s_mem_reg_write_in : STD_LOGIC;
	SIGNAL s_mem_wb_src_in : t_WritebackSrc;
	SIGNAL s_mem_funct3_in : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL s_mem_rd_addr_in : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- MEM Stage Outputs -> to MEM/WB Register
	SIGNAL s_mem_result_rd_out, s_mem_pc4_out, s_mem_final_read_data_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mem_wb_src_out : t_WritebackSrc;
	SIGNAL s_mem_reg_write_out : STD_LOGIC;
	SIGNAL s_mem_rd_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- WB Stage Inputs <- from MEM/WB Register
	SIGNAL s_wb_result_rd_in, s_wb_pc4_in, s_wb_final_read_data_in : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_wb_wb_src_in : t_WritebackSrc;
	SIGNAL s_wb_reg_write_in : STD_LOGIC;
	SIGNAL s_wb_rd_addr_in : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- WB Stage Outputs
	SIGNAL s_wb_reg_write_en_out : STD_LOGIC;
	SIGNAL s_wb_rd_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_wb_rd_data_out : STD_LOGIC_VECTOR(31 DOWNTO 0);

        SIGNAL s_ex_pc_redirect_out : STD_LOGIC;

BEGIN

        s_pipeline_flush <= '1' WHEN (s_ex_pc_redirect_out = '1') ELSE '0';

	U_HZ_UNIT : hazard_detection_unit
	PORT MAP(
		i_rs1_addr_id    => s_id_rs1_addr_out,
		i_rs2_addr_id    => s_id_rs2_addr_out,
		i_rd_addr_ex     => s_ex_rd_addr_in,
		i_mem_read_ex    => s_ex_mem_read_in,
		o_pipeline_stall => s_hz_pipeline_stall_out
	);

	-- Stage 1: Instruction Fetch (IF)
	U_IF_STAGE : instruction_fetch_unit
	PORT MAP(
		i_clk         => i_clk,
		i_rst         => i_rst,
		i_stall       => s_hz_pipeline_stall_out,
		i_pc_redirect => s_ex_pc_redirect_out,
                i_target_addr => s_ex_pc_target_addr_out,
		o_instr_addr  => o_instr_addr,
		i_instr_data  => i_instr_data,
		o_instruction => s_if_instruction_out,
		o_pc          => s_if_pc_out,
		o_pc_plus_4   => s_if_pc4_out
	);

	IF_ID_Register_Proc : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_id_pc_in <= (OTHERS => '0');
			s_id_pc4_in <= (OTHERS => '0');
			s_id_instruction_in <= X"00000013";
		ELSIF rising_edge(i_clk) THEN
			IF (s_pipeline_flush = '1') THEN
				s_id_pc_in <= (OTHERS => '0');
				s_id_pc4_in <= (OTHERS => '0');
				s_id_instruction_in <= X"00000013";
			ELSIF (s_hz_pipeline_stall_out = '0') THEN
				s_id_pc_in <= s_if_pc_out;
				s_id_pc4_in <= s_if_pc4_out;
				s_id_instruction_in <= s_if_instruction_out;

			END IF;
		END IF;
	END PROCESS IF_ID_Register_Proc;

	-- Stage 2: Instruction Decode (ID)
	U_ID_STAGE : instruction_decode_unit
	PORT MAP(
		i_clk          => i_clk,
		i_rst          => i_rst,
		i_pc           => s_id_pc_in,
		i_pc4          => s_id_pc4_in,
		i_instruction  => s_id_instruction_in,
		i_wr_addr_wb   => s_wb_rd_addr_out,
		i_wr_data_wb   => s_wb_rd_data_out,
		i_wr_en_wb     => s_wb_reg_write_en_out,
		o_reg_write_ex => s_id_reg_write_out,
		o_mem_read_ex  => s_id_mem_read_out,
		o_mem_write_ex => s_id_mem_write_out,
		o_wb_src_ex    => s_id_wb_src_out,
		o_src_a_ex     => s_id_src_a_out,
		o_src_b_ex     => s_id_src_b_out,
		o_op_type_ex   => s_id_op_type_out,
		o_ex_unit_type => s_id_unit_type_out,
		o_immediate    => s_id_immediate_out,
		o_rs1_data     => s_id_rs1_data_out,
		o_rs2_data     => s_id_rs2_data_out,
		o_pc           => s_id_pc_out,
		o_pc4          => s_id_pc4_out,
		o_rd_addr      => s_id_rd_addr_out,
		o_uimm         => s_id_uimm_out,
		o_rs1_addr     => s_id_rs1_addr_out,
		o_rs2_addr     => s_id_rs2_addr_out,
		o_funct3       => s_id_funct3_out,
		o_funct12      => s_id_funct12_out
	);

	-- ID/EX Pipeline Register
	ID_EX_Register_Proc : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_ex_reg_write_in <= '0';
			s_ex_mem_read_in <= '0';
			s_ex_mem_write_in <= '0';
			s_ex_wb_src_in <= WB_SRC_EX_RESULT;
			s_ex_src_a_in <= SRC_A_RS1;
			s_ex_src_b_in <= SRC_B_RS2;
			s_ex_op_type_in <= OP_R_TYPE;
			s_ex_unit_type_in <= UNIT_ALU;
			s_ex_immediate_in <= (OTHERS => '0');
			s_ex_rs1_data_in <= (OTHERS => '0');
			s_ex_rs2_data_in <= (OTHERS => '0');
			s_ex_uimm_in <= (OTHERS => '0');
			s_ex_pc_in <= (OTHERS => '0');
			s_ex_pc4_in <= (OTHERS => '0');
			s_ex_rd_addr_in <= (OTHERS => '0');
			s_ex_rs1_addr_in <= (OTHERS => '0');
			s_ex_rs2_addr_in <= (OTHERS => '0');
			s_ex_funct3_in <= (OTHERS => '0');
			s_ex_funct12_in <= (OTHERS => '0');
		ELSIF rising_edge(i_clk) THEN
			IF (s_hz_pipeline_stall_out = '1') OR (s_pipeline_flush = '1') THEN
				s_ex_reg_write_in <= '0';
				s_ex_mem_read_in <= '0';
				s_ex_mem_write_in <= '0';
				s_ex_wb_src_in <= WB_SRC_EX_RESULT;
				s_ex_src_a_in <= SRC_A_RS1;
				s_ex_src_b_in <= SRC_B_RS2;
				s_ex_op_type_in <= OP_R_TYPE;
				s_ex_unit_type_in <= UNIT_ALU;
				s_ex_immediate_in <= (OTHERS => '0');
				s_ex_rs1_data_in <= (OTHERS => '0');
				s_ex_rs2_data_in <= (OTHERS => '0');
				s_ex_uimm_in <= (OTHERS => '0');
				s_ex_pc_in <= (OTHERS => '0');
				s_ex_pc4_in <= (OTHERS => '0');
				s_ex_rd_addr_in <= (OTHERS => '0');
				s_ex_rs1_addr_in <= (OTHERS => '0');
				s_ex_rs2_addr_in <= (OTHERS => '0');
				s_ex_funct3_in <= (OTHERS => '0');
				s_ex_funct12_in <= (OTHERS => '0');
			ELSE
				s_ex_reg_write_in <= s_id_reg_write_out;
				s_ex_mem_read_in <= s_id_mem_read_out;
				s_ex_mem_write_in <= s_id_mem_write_out;
				s_ex_wb_src_in <= s_id_wb_src_out;
				s_ex_src_a_in <= s_id_src_a_out;
				s_ex_src_b_in <= s_id_src_b_out;
				s_ex_uimm_in <= s_id_uimm_out;
				s_ex_op_type_in <= s_id_op_type_out;
				s_ex_unit_type_in <= s_id_unit_type_out;
				s_ex_immediate_in <= s_id_immediate_out;
				s_ex_rs1_data_in <= s_id_rs1_data_out;
				s_ex_rs2_data_in <= s_id_rs2_data_out;
				s_ex_pc_in <= s_id_pc_out;
				s_ex_pc4_in <= s_id_pc4_out;
				s_ex_rd_addr_in <= s_id_rd_addr_out;
				s_ex_rs1_addr_in <= s_id_rs1_addr_out;
				s_ex_rs2_addr_in <= s_id_rs2_addr_out;
				s_ex_funct3_in <= s_id_funct3_out;
				s_ex_funct12_in <= s_id_funct12_out;
			END IF;
		END IF;
	END PROCESS ID_EX_Register_Proc;

	-- Stage 3: Execute (EX)
	U_EX_STAGE : execution_unit
	PORT MAP(
		i_clk            => i_clk,
		i_rst            => i_rst,
		i_pc_id          => s_ex_pc_in,
		i_pc4_id         => s_ex_pc4_in,
		i_rs1_data_id    => s_ex_rs1_data_in,
		i_rs2_data_id    => s_ex_rs2_data_in,
		i_immediate_id   => s_ex_immediate_in,
		i_funct3_id      => s_ex_funct3_in,
		i_funct12_id     => s_ex_funct12_in,
		i_uimm_id        => s_ex_uimm_in,
		i_ex_op_type_id  => s_ex_op_type_in,
		i_src_a_id       => s_ex_src_a_in,
		i_src_b_id       => s_ex_src_b_in,
		i_unit_en_id     => s_ex_unit_type_in,
		i_mem_read_id    => s_ex_mem_read_in,
		i_mem_write_id   => s_ex_mem_write_in,
		i_reg_write_id   => s_ex_reg_write_in,
		i_wb_src_id      => s_ex_wb_src_in,
		i_rd_addr_id     => s_ex_rd_addr_in,
		i_rs1_addr_id    => s_ex_rs1_addr_in,
		i_rs2_addr_id    => s_ex_rs2_addr_in,
		i_rd_addr_mem    => s_mem_rd_addr_in,
		i_rd_data_mem    => s_mem_result_in,
		i_rd_addr_wb     => s_wb_rd_addr_in,
		i_rd_data_wb     => s_wb_rd_data_out,
                i_reg_write_mem => s_mem_reg_write_in,
                i_reg_write_wb => s_wb_reg_write_in,
		o_pc_redirect => s_ex_pc_redirect_out,
		o_pc_target_addr => s_ex_pc_target_addr_out,
		o_ex_result      => s_ex_result_out,
		o_rs2_data       => s_ex_rs2_data_out,
		o_pc4            => s_ex_pc4_out,
		o_funct3         => s_ex_funct3_out,
		o_mem_read       => s_ex_mem_read_out,
		o_mem_write      => s_ex_mem_write_out,
		o_reg_write      => s_ex_reg_write_out,
		o_wb_src         => s_ex_wb_src_out,
		o_rd_addr        => s_ex_rd_addr_out
	);

	-- EX/MEM Pipeline Register
	EX_MEM_Register_Proc : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_mem_result_in <= (OTHERS => '0');
			s_mem_rs2_data_in <= (OTHERS => '0');
			s_mem_pc4_in <= (OTHERS => '0');
			s_mem_funct3_in <= (OTHERS => '0');
			s_mem_mem_read_in <= '0';
			s_mem_mem_write_in <= '0';
			s_mem_reg_write_in <= '0';
			s_mem_wb_src_in <= WB_SRC_EX_RESULT;
			s_mem_rd_addr_in <= (OTHERS => '0');
		ELSIF rising_edge(i_clk) THEN
			s_mem_result_in <= s_ex_result_out;
			s_mem_rs2_data_in <= s_ex_rs2_data_out;
			s_mem_pc4_in <= s_ex_pc4_out;
			s_mem_funct3_in <= s_ex_funct3_out;
			s_mem_mem_read_in <= s_ex_mem_read_out;
			s_mem_mem_write_in <= s_ex_mem_write_out;
			s_mem_reg_write_in <= s_ex_reg_write_out;
			s_mem_wb_src_in <= s_ex_wb_src_out;
			s_mem_rd_addr_in <= s_ex_rd_addr_out;
		END IF;
	END PROCESS EX_MEM_Register_Proc;

	-- Stage 4: Memory (MEM)
	U_MEM_STAGE : memory_unit
	PORT MAP(
		i_result_rd_ex    => s_mem_result_in,
		i_rs2_data_ex     => s_mem_rs2_data_in,
		i_pc4_ex          => s_mem_pc4_in,
		i_funct3_ex       => s_mem_funct3_in,
		i_mem_read_ex     => s_mem_mem_read_in,
		i_mem_write_ex    => s_mem_mem_write_in,
		i_reg_write_ex    => s_mem_reg_write_in,
		i_wb_src_ex       => s_mem_wb_src_in,
		i_rd_addr_ex      => s_mem_rd_addr_in,
		i_mem_read_data   => i_data_read,
		o_mem_addr        => o_data_addr,
		o_mem_write_data  => o_data_write,
		o_mem_write_en    => o_data_write_en,
		o_mem_byte_en     => o_data_byte_en,
		o_result_rd_mem   => s_mem_result_rd_out,
		o_pc4_mem         => s_mem_pc4_out,
		o_wb_src_mem      => s_mem_wb_src_out,
		o_final_read_data => s_mem_final_read_data_out,
		o_reg_write_mem   => s_mem_reg_write_out,
		o_rd_addr_mem     => s_mem_rd_addr_out
	);

	-- MEM/WB Pipeline Register
	MEM_WB_Register_Proc : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_wb_final_read_data_in <= (OTHERS => '0');
			s_wb_result_rd_in <= (OTHERS => '0');
			s_wb_pc4_in <= (OTHERS => '0');
			s_wb_reg_write_in <= '0';
			s_wb_wb_src_in <= WB_SRC_EX_RESULT;
			s_wb_rd_addr_in <= (OTHERS => '0');
		ELSIF rising_edge(i_clk) THEN
			s_wb_final_read_data_in <= s_mem_final_read_data_out;
			s_wb_result_rd_in <= s_mem_result_rd_out;
			s_wb_pc4_in <= s_mem_pc4_out;
			s_wb_reg_write_in <= s_mem_reg_write_out;
			s_wb_wb_src_in <= s_mem_wb_src_out;
			s_wb_rd_addr_in <= s_mem_rd_addr_out;
		END IF;
	END PROCESS MEM_WB_Register_Proc;

	-- Stage 5: Write-Back (WB)
	U_WB_STAGE : writeback_unit
	PORT MAP(
		i_read_data    => s_wb_final_read_data_in,
		i_rd_result    => s_wb_result_rd_in,
		i_pc4          => s_wb_pc4_in,
		i_reg_write    => s_wb_reg_write_in,
		i_wb_src       => s_wb_wb_src_in,
		i_rd_addr      => s_wb_rd_addr_in,
		o_reg_write_en => s_wb_reg_write_en_out,
		o_rd_addr      => s_wb_rd_addr_out,
		o_rd_data      => s_wb_rd_data_out
	);

END ARCHITECTURE structural;

