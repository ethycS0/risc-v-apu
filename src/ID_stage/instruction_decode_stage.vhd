LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_decode_stage IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		i_wb_id_bus : IN  t_rd_reg_data;
		i_if_id_bus : IN  t_if_id_data;
		o_id_ex_bus : OUT t_id_ex_data
	);
END ENTITY instruction_decode_stage;

ARCHITECTURE structural OF instruction_decode_stage IS

	COMPONENT id_control_unit IS
		PORT (
			i_instruction : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_reg_write   : OUT STD_LOGIC;
			o_mem_read    : OUT STD_LOGIC;
			o_mem_write   : OUT STD_LOGIC;
			o_src_a       : OUT t_SrcA;
			o_src_b       : OUT t_SrcB;
			o_wb_src      : OUT t_WritebackSrc;
			o_opr_unit    : OUT t_OprUnit;
			o_opr_type    : OUT t_OprType
		);
	END COMPONENT id_control_unit;

	COMPONENT immediate_reconstruct_unit IS
		PORT (
			i_instruction : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_immediate   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT immediate_reconstruct_unit;

	COMPONENT register_file IS
		PORT (
			i_clk      : IN  STD_LOGIC;
			i_rst      : IN  STD_LOGIC;
			i_wr_en    : IN  STD_LOGIC;
			i_wr_addr  : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_wr_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rd1_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_rd1_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rd2_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_rd2_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT register_file;

	SIGNAL s_rs1_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_rs2_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_uimm : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL s_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL s_funct12 : STD_LOGIC_VECTOR(11 DOWNTO 0);
BEGIN
	s_rs1_addr <= i_if_id_bus.instruction(19 DOWNTO 15);
	s_rs2_addr <= i_if_id_bus.instruction(24 DOWNTO 20);
	s_rd_addr <= i_if_id_bus.instruction(11 DOWNTO 7);
	s_funct3 <= i_if_id_bus.instruction(14 DOWNTO 12);
	s_funct12 <= i_if_id_bus.instruction(31 DOWNTO 20);
	s_uimm <= i_if_id_bus.instruction(19 DOWNTO 15);

	U_DECODE_CONTROL : id_control_unit
	PORT MAP(
		i_instruction => i_if_id_bus.instruction,
		o_reg_write   => o_id_ex_bus.reg_write,
		o_mem_read    => o_id_ex_bus.mem_read,
		o_mem_write   => o_id_ex_bus.mem_write,
		o_src_a       => o_id_ex_bus.src_a,
		o_src_b       => o_id_ex_bus.src_b,
		o_wb_src      => o_id_ex_bus.wb_src,
		o_opr_unit    => o_id_ex_bus.opr_unit,
		o_opr_type    => o_id_ex_bus.opr_type
	);

	U_IMMEDIATE_CONSTRUCTOR : immediate_reconstruct_unit
	PORT MAP(
		i_instruction => i_if_id_bus.instruction,
		o_immediate   => o_id_ex_bus.immediate
	);

	U_REGISTER_FILE : register_file
	PORT MAP(
		i_clk      => i_clk,
		i_rst      => i_rst,
		i_wr_en    => i_wb_id_bus.reg_write_en,
		i_wr_addr  => i_wb_id_bus.rd_addr,
		i_wr_data  => i_wb_id_bus.rd_data,
		i_rd1_addr => s_rs1_addr,
		i_rd2_addr => s_rs2_addr,
		o_rd1_data => o_id_ex_bus.rs1_data,
		o_rd2_data => o_id_ex_bus.rs2_data
	);

	o_id_ex_bus.pc <= i_if_id_bus.pc;
	o_id_ex_bus.pc4 <= i_if_id_bus.pc4;

	o_id_ex_bus.rd_addr <= s_rd_addr;
	o_id_ex_bus.rs1_addr <= s_rs1_addr;
	o_id_ex_bus.rs2_addr <= s_rs2_addr;
	o_id_ex_bus.uimm <= s_uimm;

	o_id_ex_bus.funct3 <= s_funct3;
	o_id_ex_bus.funct12 <= s_funct12;

END ARCHITECTURE structural;

