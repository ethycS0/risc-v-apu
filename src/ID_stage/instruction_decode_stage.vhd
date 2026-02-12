--! @file instruction_decode_stage.vhd
--! Instruction Decode Stage
--! @author ethycS
--! @details This module implements the Instruction Decode (ID) stage of the RV32I
--! pipeline. It receives fetched instructions from the IF stage, decodes them,
--! reads operands from the register file, and generates all control signals needed
--! for subsequent pipeline stages.
--!
--! The ID stage consists of three main components:
--! - Control Unit: Decodes opcode and generates control signals
--! - Immediate Reconstruction Unit: Extracts and formats immediate values
--! - Register File: Provides dual-port read access to architectural registers
--!
--! This stage also extracts instruction fields (rs1, rs2, rd, funct3, funct12)
--! and forwards them along with control signals to the Execute stage via the
--! ID/EX pipeline register bus.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_decode_stage IS
	PORT (
		i_clk : IN STD_LOGIC;  --! Global clock
		i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

		i_wb_id_bus : IN  t_rd_reg_data;  --! Writeback feedback bus (register write data from WB stage)
		i_if_id_bus : IN  t_if_id_data;   --! Input bus from Instruction Fetch stage (instruction and PC)
		o_id_ex_bus : OUT t_id_ex_data    --! Output bus to Execute stage (decoded instruction and control signals)
	);
END ENTITY instruction_decode_stage;

ARCHITECTURE structural OF instruction_decode_stage IS

	--! Control unit component declaration
	COMPONENT id_control_unit IS
		PORT (
                        i_elp         : IN STD_LOGIC;
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

	--! Immediate reconstruction unit component declaration
	COMPONENT immediate_reconstruct_unit IS
		PORT (
			i_instruction : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_immediate   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT immediate_reconstruct_unit;

	--! Register file component declaration
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

	SIGNAL s_rs1_addr  : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source register 1 address (instruction[19:15])
	SIGNAL s_rs2_addr  : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source register 2 address (instruction[24:20])
	SIGNAL s_uimm      : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Unsigned immediate/Zimm for CSR instructions (instruction[19:15])
	SIGNAL s_rd_addr   : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination register address (instruction[11:7])
	SIGNAL s_funct3    : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Function field 3 bits (instruction[14:12])
	SIGNAL s_funct12   : STD_LOGIC_VECTOR(11 DOWNTO 0); --! Function field 12 bits for system instructions (instruction[31:20])

BEGIN
	-- Extract instruction fields from the incoming instruction
        s_rs1_addr <= "00111" WHEN i_if_id_bus.elp = '1' ELSE i_if_id_bus.instruction(19 DOWNTO 15);  -- Source register 1
	s_rs2_addr <= i_if_id_bus.instruction(24 DOWNTO 20);  -- Source register 2
	s_rd_addr  <= i_if_id_bus.instruction(11 DOWNTO 7);   -- Destination register
	s_funct3   <= i_if_id_bus.instruction(14 DOWNTO 12);  -- Funct3 for ALU/Memory/Branch operation selection
	s_funct12  <= i_if_id_bus.instruction(31 DOWNTO 20);  -- CSR address or system instruction encoding
	s_uimm     <= i_if_id_bus.instruction(19 DOWNTO 15);  -- Unsigned immediate for CSR immediate instructions

	--! @brief Control Unit Instance
	--! @details Decodes the instruction opcode and generates all pipeline control signals
	U_DECODE_CONTROL : id_control_unit
	PORT MAP(
                i_elp         => i_if_id_bus.elp,
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

	--! @brief Immediate Reconstruction Unit Instance
	--! @details Extracts and reconstructs immediate values from scattered instruction bits
	U_IMMEDIATE_CONSTRUCTOR : immediate_reconstruct_unit
	PORT MAP(
		i_instruction => i_if_id_bus.instruction,
		o_immediate   => o_id_ex_bus.immediate
	);

	--! @brief Register File Instance
	--! @details Dual-port read, single-port write register file with internal forwarding
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

	--@brief  Forward PC and PC+4 from IF stage to EX stage
	o_id_ex_bus.pc  <= i_if_id_bus.pc;
	o_id_ex_bus.pc4 <= i_if_id_bus.pc4;

	-- Forward instruction fields to EX stage
	o_id_ex_bus.rd_addr  <= s_rd_addr;
	o_id_ex_bus.rs1_addr <= s_rs1_addr;
	o_id_ex_bus.rs2_addr <= s_rs2_addr;
	o_id_ex_bus.uimm     <= s_uimm;

	-- Forward function fields to EX stage for operation decoding
	o_id_ex_bus.funct3  <= s_funct3;
	o_id_ex_bus.funct12 <= s_funct12;
        o_id_ex_bus.elp     <= i_if_id_bus.elp;

END ARCHITECTURE structural;

