LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_decode_unit IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		i_pc : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_pc4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_wr_addr_wb : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_wr_data_wb : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);

		-- Control Signals Input
		i_wr_en_wb : IN STD_LOGIC;

		-- Control Signals Outputs
		o_reg_write_ex : OUT STD_LOGIC;
		o_mem_read_ex : OUT STD_LOGIC;
		o_mem_write_ex : OUT STD_LOGIC;
		o_wb_src_ex : OUT t_WritebackSrc;

		o_src_a_ex : OUT t_SrcA;
		o_src_b_ex : OUT t_SrcB;
		o_op_type_ex : OUT t_ExecControl;

		-- Outputs
                o_ex_unit_type : OUT t_OperationUnit;
		o_immediate : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs1_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs2_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc4 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
                o_rd_addr : OUT STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
                o_uimm : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
                o_rs1_addr : OUT STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
                o_rs2_addr : OUT STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		o_funct3 : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		o_funct12 : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
	);
END ENTITY instruction_decode_unit;

ARCHITECTURE structural OF instruction_decode_unit IS

	SIGNAL s_rs1_addr : STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL s_rs2_addr : STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL s_uimm : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_rd_addr : STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
        SIGNAL s_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
        SIGNAL s_funct12 : STD_LOGIC_VECTOR(11 DOWNTO 0);

	COMPONENT decode_control_unit IS
		PORT (
			i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

			o_reg_write : OUT STD_LOGIC;
			o_mem_read : OUT STD_LOGIC;
			o_mem_write : OUT STD_LOGIC;

			o_src_a : OUT t_SrcA;
			o_src_b : OUT t_SrcB;
			o_wb_src : OUT t_WritebackSrc;

                        o_unit_en_type : OUT t_OperationUnit;
			o_ex_op_type : OUT t_ExecControl
		);
	END COMPONENT decode_control_unit;

	COMPONENT immediate_constructor_unit IS
		PORT (
			i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_immediate : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT immediate_constructor_unit;

	COMPONENT register_file IS
		PORT (
			i_clk : IN STD_LOGIC;
			i_rst : IN STD_LOGIC;
			i_wr_en : IN STD_LOGIC;
			i_wr_addr : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_wr_data : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
			i_rd1_addr : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			o_rd1_data : OUT STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
			i_rd2_addr : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			o_rd2_data : OUT STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0)
		);
	END COMPONENT register_file;
BEGIN
	s_rs1_addr <= i_instruction(19 DOWNTO 15);
	s_rs2_addr <= i_instruction(24 DOWNTO 20);
        s_rd_addr  <= i_instruction(11 DOWNTO 7);
        s_funct3 <= i_instruction(14 DOWNTO 12);
        s_funct12 <= i_instruction(31 DOWNTO 20);
        s_uimm <= i_instruction(19 DOWNTO 15);

	U_DECODE_CONTROL : decode_control_unit
	PORT MAP(
		i_instruction => i_instruction,
		o_reg_write => o_reg_write_ex,
		o_mem_read => o_mem_read_ex,
		o_mem_write => o_mem_write_ex,
		o_src_a => o_src_a_ex,
		o_src_b => o_src_b_ex,
		o_wb_src => o_wb_src_ex,
                o_unit_en_type => o_ex_unit_type,
		o_ex_op_type => o_op_type_ex
	);

	U_IMMEDIATE_CONSTRUCTOR : immediate_constructor_unit
	PORT MAP(
		i_instruction => i_instruction,
		o_immediate => o_immediate
	);

	U_REGISTER_FILE : register_file
	PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,
		i_wr_en => i_wr_en_wb,
		i_wr_addr => i_wr_addr_wb,
		i_wr_data => i_wr_data_wb,
		i_rd1_addr => s_rs1_addr,
		o_rd1_data => o_rs1_data,
		i_rd2_addr => s_rs2_addr,
		o_rd2_data => o_rs2_data
	);

	o_pc <= i_pc;
	o_pc4 <= i_pc4;

        o_rd_addr <= s_rd_addr;
        o_rs1_addr <= s_rs1_addr;
        o_rs2_addr <= s_rs2_addr;
        o_uimm <= s_uimm;

        o_funct3 <= s_funct3;
        o_funct12 <= s_funct12;

END ARCHITECTURE structural;

