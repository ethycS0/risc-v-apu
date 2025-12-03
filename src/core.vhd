LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY core IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

		o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_data_write_en : OUT STD_LOGIC;
		o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END ENTITY core;

ARCHITECTURE structural OF core IS
	COMPONENT instruction_fetch_stage IS
		PORT (
			i_clk        : IN  STD_LOGIC;
			i_rst        : IN  STD_LOGIC;
			i_stall      : IN  STD_LOGIC;
			o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_ex_if_bus  : IN  t_ex_if_data;
			o_if_id_bus  : OUT t_if_id_data
		);
	END COMPONENT instruction_fetch_stage;

	COMPONENT instruction_decode_stage IS
		PORT (
			i_clk       : IN  STD_LOGIC;
			i_rst       : IN  STD_LOGIC;
			i_wb_id_bus : IN  t_rd_reg_data;
			i_if_id_bus : IN  t_if_id_data;
			o_id_ex_bus : OUT t_id_ex_data
		);
	END COMPONENT instruction_decode_stage;

	COMPONENT execution_stage IS
		PORT (
			i_clk                   : IN  STD_LOGIC;
			i_rst                   : IN  STD_LOGIC;
			i_minstret_increment_wb : IN  STD_LOGIC;
			i_id_ex_bus             : IN  t_id_ex_data;
			i_rd_mem_bus            : IN  t_rd_reg_data;
			i_rd_wb_bus             : IN  t_rd_reg_data;
			o_ex_if_bus             : OUT t_ex_if_data;
			o_ex_mem_bus            : OUT t_ex_mem_data

		);
	END COMPONENT execution_stage;

	COMPONENT memory_stage IS
		PORT (
			o_mem_addr       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_mem_read_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_en   : OUT STD_LOGIC;
			o_mem_byte_en    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			i_ex_mem_bus     : IN  t_ex_mem_data;
			o_mem_wb_bus     : OUT t_mem_wb_data

		);
	END COMPONENT memory_stage;

	COMPONENT writeback_stage IS
		PORT (
			i_instruction_valid    : IN  STD_LOGIC;
			o_instructions_retired : OUT STD_LOGIC;
			i_mem_wb_bus           : IN  t_mem_wb_data;
			o_wb_id_data           : OUT t_rd_reg_data

		);
	END COMPONENT writeback_stage;

	COMPONENT hazard_detection_unit IS
		PORT (
			i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

			i_rd_addr_ex  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_mem_read_ex : IN STD_LOGIC;

			o_pipeline_stall : OUT STD_LOGIC
		);
	END COMPONENT hazard_detection_unit;
	SIGNAL s_ex_if_bus : t_ex_if_data;
	SIGNAL s_wb_id_bus : t_rd_reg_data;

	SIGNAL s_if_id_bus : t_if_id_data;
	SIGNAL s_id_ex_bus : t_id_ex_data;
	SIGNAL s_ex_mem_bus : t_ex_mem_data;
	SIGNAL s_mem_wb_bus : t_mem_wb_data;

	SIGNAL r_if_id_reg : t_if_id_data;
	SIGNAL r_id_ex_reg : t_id_ex_data;
	SIGNAL r_ex_mem_reg : t_ex_mem_data;
	SIGNAL r_mem_wb_reg : t_mem_wb_data;

	SIGNAL pipeline_stall : STD_LOGIC;
	SIGNAL pipeline_flush : STD_LOGIC;

	SIGNAL minstret_increment : STD_LOGIC;
	SIGNAL instruction_valid : STD_LOGIC;
BEGIN

	U_IF_STAGE : instruction_fetch_stage
	PORT MAP(
		i_clk        => i_clk,
		i_rst        => i_rst,
		i_stall      => pipeline_stall,
		o_instr_addr => o_instr_addr,
		i_instr_data => i_instr_data,
		i_ex_if_bus  => s_ex_if_bus,
		o_if_id_bus  => s_if_id_bus
	);

	U_ID_STAGE : instruction_decode_stage
	PORT MAP(
		i_clk       => i_clk,
		i_rst       => i_rst,
		i_wb_id_bus => s_wb_id_bus,
		i_if_id_bus => r_if_id_reg,
		o_id_ex_bus => s_id_ex_bus
	);

	U_EX_STAGE : execution_stage
	PORT MAP(
		i_clk                   => i_clk,
		i_rst                   => i_rst,
		i_minstret_increment_wb => minstret_increment,
		i_id_ex_bus             => r_id_ex_reg,
		i_rd_mem_bus            => r_ex_mem_reg.rd_bus,
		i_rd_wb_bus             => r_mem_wb_reg.rd_bus,
		o_ex_if_bus             => s_ex_if_bus,
		o_ex_mem_bus            => s_ex_mem_bus
	);

	U_MEM_STAGE : memory_stage
	PORT MAP(
		o_mem_addr       => o_data_addr,
		i_mem_read_data  => i_data_read,
		o_mem_write_data => o_data_write,
		o_mem_write_en   => o_data_write_en,
		o_mem_byte_en    => o_data_byte_en,
		i_ex_mem_bus     => r_ex_mem_reg,
		o_mem_wb_bus     => s_mem_wb_bus
	);

	U_WB_STAGE : writeback_stage
	PORT MAP(
		i_instruction_valid    => instruction_valid,
		o_instructions_retired => minstret_increment,
		i_mem_wb_bus           => r_mem_wb_reg,
		o_wb_id_data           => s_wb_id_bus
	);

	U_HZD_DET : hazard_detection_unit
	PORT MAP(
		i_rs1_addr_id    => s_id_ex_bus.rs1_addr,
		i_rs2_addr_id    => s_id_ex_bus.rs2_addr,
		i_rd_addr_ex     => r_id_ex_reg.rd_addr,
		i_mem_read_ex    => r_id_ex_reg.mem_read,
		o_pipeline_stall => pipeline_stall
	);

	pipeline_flush <= '1' WHEN s_ex_if_bus.pc_redirect = '1' ELSE '0';
        instruction_valid <= '1' WHEN pipeline_stall = '0' ELSE '0';

	P_IF_ID_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_if_id_reg <= C_IF_ID_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF pipeline_flush = '1' THEN
                                r_if_id_reg <= C_IF_ID_RESET;
			ELSIF pipeline_stall = '0' THEN
				r_if_id_reg <= s_if_id_bus;
			END IF;

		END IF;
	END PROCESS;

	P_ID_EX_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_id_ex_reg <= C_ID_EX_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF pipeline_flush = '1' OR pipeline_stall = '1' THEN
				r_id_ex_reg <= C_ID_EX_RESET;
                        ELSE
				r_id_ex_reg <= s_id_ex_bus;
			END IF;
		END IF;
	END PROCESS;

	P_EX_MEM_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_ex_mem_reg <= C_EX_MEM_RESET;
		ELSIF rising_edge(i_clk) THEN
                        r_ex_mem_reg <= s_ex_mem_bus;
		END IF;
	END PROCESS;

	P_MEM_WB_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_mem_wb_reg <= C_MEM_WB_RESET;
		ELSIF rising_edge(i_clk) THEN
                        r_mem_wb_reg <= s_mem_wb_bus;
		END IF;
	END PROCESS;

END ARCHITECTURE structural;

