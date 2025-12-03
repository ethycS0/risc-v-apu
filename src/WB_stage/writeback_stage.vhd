LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_stage IS
	PORT (
		i_instruction_valid    : IN  STD_LOGIC;
		o_instructions_retired : OUT STD_LOGIC;

		i_mem_wb_bus : IN  t_mem_wb_data;
		o_wb_id_data  : OUT t_rd_reg_data

	);
END ENTITY writeback_stage;

ARCHITECTURE behavioral OF writeback_stage IS
BEGIN

	writeback_mux_proc : PROCESS (i_mem_wb_bus.wb_src, i_mem_wb_bus.rd_bus.rd_data, i_mem_wb_bus.pc4)
	BEGIN
		CASE i_mem_wb_bus.wb_src IS
			WHEN WB_SRC_EX_RESULT =>
				o_wb_id_data.rd_data <= i_mem_wb_bus.rd_bus.rd_data;

			WHEN WB_SRC_MEM =>
				o_wb_id_data.rd_data <= i_mem_wb_bus.rd_bus.rd_data;

			WHEN WB_SRC_PC4 =>
				o_wb_id_data.rd_data <= i_mem_wb_bus.pc4;

			WHEN OTHERS =>
				o_wb_id_data.rd_data <= (OTHERS => 'X');

		END CASE;
	END PROCESS writeback_mux_proc;

	o_wb_id_data.rd_addr <= i_mem_wb_bus.rd_bus.rd_addr;
	o_wb_id_data.reg_write_en <= i_mem_wb_bus.rd_bus.reg_write_en;
	o_instructions_retired <= i_instruction_valid;

END ARCHITECTURE behavioral;

