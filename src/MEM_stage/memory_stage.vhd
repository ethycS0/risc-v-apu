LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY memory_stage IS
	PORT (
		o_mem_addr       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_mem_write_en   : OUT STD_LOGIC;
		o_mem_byte_en    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

		i_ex_mem_bus : IN  t_ex_mem_data;
		o_mem_wb_bus : OUT t_mem_wb_data

	);
END ENTITY memory_stage;

ARCHITECTURE structural OF memory_stage IS
BEGIN

	o_mem_addr <= i_ex_mem_bus.rd_bus.rd_data;
	o_mem_write_en <= i_ex_mem_bus.mem_write;

	store_logic : PROCESS (i_ex_mem_bus.mem_write, i_ex_mem_bus.funct3, i_ex_mem_bus.rd_bus.rd_data, i_ex_mem_bus.rs2_data)
	BEGIN
		o_mem_byte_en <= "0000";
		o_mem_write_data <= i_ex_mem_bus.rs2_data;

		IF i_ex_mem_bus.mem_write = '1' THEN
			CASE i_ex_mem_bus.funct3 IS
				WHEN "010" =>
					o_mem_byte_en <= "1111";
					o_mem_write_data <= i_ex_mem_bus.rs2_data;

				WHEN "001" =>
					o_mem_write_data <= i_ex_mem_bus.rs2_data(15 DOWNTO 0) & i_ex_mem_bus.rs2_data(15 DOWNTO 0);

					IF i_ex_mem_bus.rd_bus.rd_data(1) = '0' THEN
						o_mem_byte_en <= "0011";
					ELSE
						o_mem_byte_en <= "1100";
					END IF;

				WHEN "000" =>
					o_mem_write_data <= i_ex_mem_bus.rs2_data(7 DOWNTO 0) & i_ex_mem_bus.rs2_data(7 DOWNTO 0) &
						i_ex_mem_bus.rs2_data(7 DOWNTO 0) & i_ex_mem_bus.rs2_data(7 DOWNTO 0);

					CASE i_ex_mem_bus.rd_bus.rd_data(1 DOWNTO 0) IS
						WHEN "00" => o_mem_byte_en <= "0001";
						WHEN "01" => o_mem_byte_en <= "0010";
						WHEN "10" => o_mem_byte_en <= "0100";
						WHEN "11" => o_mem_byte_en <= "1000";
						WHEN OTHERS => o_mem_byte_en <= "0000";
					END CASE;

				WHEN OTHERS =>
					o_mem_byte_en <= "0000";
			END CASE;
		END IF;
	END PROCESS store_logic;

	o_mem_wb_bus.pc4 <= i_ex_mem_bus.pc4;
	o_mem_wb_bus.raw_mem_data <= (OTHERS => '0');
	o_mem_wb_bus.rd_bus <= i_ex_mem_bus.rd_bus;
	o_mem_wb_bus.wb_src <= i_ex_mem_bus.wb_src;
	o_mem_wb_bus.funct3 <= i_ex_mem_bus.funct3;

END ARCHITECTURE structural;

