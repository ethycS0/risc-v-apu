LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_stage IS
	PORT (
		i_instruction_valid    : IN  STD_LOGIC;
		o_instructions_retired : OUT STD_LOGIC;

		i_mem_wb_bus : IN  t_mem_wb_data;
		o_wb_id_data : OUT t_rd_reg_data;
		o_wb_ex_fwd  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)

	);
END ENTITY writeback_stage;

ARCHITECTURE behavioral OF writeback_stage IS
	SIGNAL s_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN

	P_LOAD_LOGIC : PROCESS (i_mem_wb_bus.funct3, i_mem_wb_bus.raw_mem_data, i_mem_wb_bus.rd_bus.rd_data)
		VARIABLE byte_val : STD_LOGIC_VECTOR(7 DOWNTO 0);
		VARIABLE half_val : STD_LOGIC_VECTOR(15 DOWNTO 0);

	BEGIN
		s_read_data <= (OTHERS => 'X');
		CASE i_mem_wb_bus.rd_bus.rd_data(1 DOWNTO 0) IS
			WHEN "00" => byte_val := i_mem_wb_bus.raw_mem_data(7 DOWNTO 0);
			WHEN "01" => byte_val := i_mem_wb_bus.raw_mem_data(15 DOWNTO 8);
			WHEN "10" => byte_val := i_mem_wb_bus.raw_mem_data(23 DOWNTO 16);
			WHEN "11" => byte_val := i_mem_wb_bus.raw_mem_data(31 DOWNTO 24);
			WHEN OTHERS => byte_val := (OTHERS => 'X');
		END CASE;

		IF i_mem_wb_bus.rd_bus.rd_data(1) = '0' THEN
			half_val := i_mem_wb_bus.raw_mem_data(15 DOWNTO 0);
			ELSE
			half_val := i_mem_wb_bus.raw_mem_data(31 DOWNTO 16);
		END IF;

		CASE i_mem_wb_bus.funct3 IS
			WHEN "010" =>
				s_read_data <= i_mem_wb_bus.raw_mem_data;

			WHEN "001" =>
				s_read_data <= STD_LOGIC_VECTOR(resize(signed(half_val), 32));

			WHEN "000" =>
				s_read_data <= STD_LOGIC_VECTOR(resize(signed(byte_val), 32));

			WHEN "101" =>
				s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(half_val), 32));

			WHEN "100" =>
				s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(byte_val), 32));

			WHEN OTHERS =>
				NULL;

		END CASE;
	END PROCESS P_LOAD_LOGIC;

	P_WB_MUX : PROCESS (i_mem_wb_bus.wb_src, i_mem_wb_bus.rd_bus.rd_data, i_mem_wb_bus.pc4, i_mem_wb_bus.raw_mem_data, s_read_data)
	BEGIN
		CASE i_mem_wb_bus.wb_src IS
			WHEN WB_SRC_EX_RESULT =>
				o_wb_id_data.rd_data <= i_mem_wb_bus.rd_bus.rd_data;
				o_wb_ex_fwd <= i_mem_wb_bus.rd_bus.rd_data;

			WHEN WB_SRC_MEM =>
				o_wb_id_data.rd_data <= s_read_data;
				o_wb_ex_fwd <= s_read_data;

			WHEN WB_SRC_PC4 =>
				o_wb_id_data.rd_data <= i_mem_wb_bus.pc4;
				o_wb_ex_fwd <= i_mem_wb_bus.pc4;

			WHEN OTHERS =>
				o_wb_id_data.rd_data <= (OTHERS => 'X');
				o_wb_ex_fwd <= (OTHERS => 'X');

		END CASE;
	END PROCESS p_WB_MUX;

	o_wb_id_data.rd_addr <= i_mem_wb_bus.rd_bus.rd_addr;
	o_wb_id_data.reg_write_en <= i_mem_wb_bus.rd_bus.reg_write_en;
	o_instructions_retired <= i_instruction_valid;

END ARCHITECTURE behavioral;

