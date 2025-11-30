LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_unit IS
	PORT (
		-- Inputs 
		i_read_data : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
		i_rd_result : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
		i_pc4 : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
		i_reg_write : IN STD_LOGIC;
                i_instruction_valid : IN STD_LOGIC; 
		i_wb_src : IN t_WritebackSrc;
		i_rd_addr : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

		-- Outputs 
		o_reg_write_en : OUT STD_LOGIC;
		o_rd_addr : OUT STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		o_rd_data : OUT STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
                o_instructions_retired : OUT STD_LOGIC
	);
END ENTITY writeback_unit;

ARCHITECTURE behavioral OF writeback_unit IS
BEGIN

	writeback_mux_proc : PROCESS (i_wb_src, i_rd_result, i_read_data, i_pc4)
	BEGIN
		CASE i_wb_src IS
                        -- Result from ALU for R-type, I-type, AUIPC
			WHEN WB_SRC_EX_RESULT =>
				o_rd_data <= i_rd_result;

                        -- Result from Memory for Loads
			WHEN WB_SRC_MEM =>
				o_rd_data <= i_read_data;

                        -- PC+4 for JAL and JALR
			WHEN WB_SRC_PC4 =>
				o_rd_data <= i_pc4;

                        -- Safe default for undefined behavior
			WHEN OTHERS =>
				o_rd_data <= (OTHERS => 'X');

		END CASE;
	END PROCESS writeback_mux_proc;

	o_rd_addr <= i_rd_addr;
	o_reg_write_en <= i_reg_write;
        o_instructions_retired <= i_instruction_valid;

END ARCHITECTURE behavioral;

