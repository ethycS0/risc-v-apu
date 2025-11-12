LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY memory_stage IS
	PORT (
		-- Inputs from EX/MEM Pipeline Register 
		i_alu_result_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Would be Either Address or Passthrough
		i_rs2_data_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- For SB, SH and SW
		i_pc4_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Passthrough
		i_funct3_ex : IN STD_LOGIC_VECTOR(2 DOWNTO 0); -- Validate Instruction Type

		-- Control Signales to Choose Function
		i_mem_read_ex : IN STD_LOGIC;
		i_mem_write_ex : IN STD_LOGIC;
		i_reg_write_ex : IN STD_LOGIC;
		i_wb_src_ex : IN t_WritebackSrc;
		i_rd_addr_ex : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

		-- Memory Interface Ports (Input) 
		i_mem_read_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0); -- Data coming IN from Data Memory

		-- Memory Interface Ports (Output) 
		o_mem_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); -- Address going OUT to Data Memory
		o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_mem_write_en : OUT STD_LOGIC;
		o_mem_byte_en : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

		-- Outputs to MEM/WB Pipeline Register 
		o_final_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_alu_result_mem : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc4_mem : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_reg_write_mem : OUT STD_LOGIC;
		o_wb_src_mem : OUT t_WritebackSrc;
		o_rd_addr_mem : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)

	);
END ENTITY memory_stage;

ARCHITECTURE structural OF memory_stage IS
BEGIN

	load_extension_logic : PROCESS (i_mem_read_ex, i_funct3_ex, i_mem_read_data, i_alu_result_ex)
		VARIABLE byte_val : STD_LOGIC_VECTOR(7 DOWNTO 0);
		VARIABLE half_val : STD_LOGIC_VECTOR(15 DOWNTO 0);

	BEGIN
		o_final_read_data <= (OTHERS => 'X');
		IF i_mem_read_ex = '1' THEN

			-- Byte extraction based on the lower 2 bits of the address
			CASE i_alu_result_ex(1 DOWNTO 0) IS
				WHEN "00" => byte_val := i_mem_read_data(7 DOWNTO 0);
				WHEN "01" => byte_val := i_mem_read_data(15 DOWNTO 8);
				WHEN "10" => byte_val := i_mem_read_data(23 DOWNTO 16);
				WHEN "11" => byte_val := i_mem_read_data(31 DOWNTO 24);
				WHEN OTHERS => byte_val := (OTHERS => 'X');
			END CASE;

			-- Half-word extraction based on bit 1 of the address
			IF i_alu_result_ex(1) = '0' THEN
				half_val := i_mem_read_data(15 DOWNTO 0); -- Lower half-word
			ELSE
				half_val := i_mem_read_data(31 DOWNTO 16); -- Upper half-word
			END IF;

			CASE i_funct3_ex IS
					-- LW (Load Word): No extension needed, pass the full 32-bit word.
				WHEN "010" =>
					o_final_read_data <= i_mem_read_data;

					-- LH (Load Half-word, signed): Sign-extend the 16-bit value to 32 bits.
				WHEN "001" =>
					o_final_read_data <= STD_LOGIC_VECTOR(resize(signed(half_val), 32));

					-- LB (Load Byte, signed): Sign-extend the 8-bit value to 32 bits.
				WHEN "000" =>
					o_final_read_data <= STD_LOGIC_VECTOR(resize(signed(byte_val), 32));

					-- LHU (Load Half-word, unsigned): Zero-extend the 16-bit value to 32 bits.
				WHEN "101" =>
					o_final_read_data <= STD_LOGIC_VECTOR(resize(unsigned(half_val), 32));

					-- LBU (Load Byte, unsigned): Zero-extend the 8-bit value to 32 bits.
				WHEN "100" =>
					o_final_read_data <= STD_LOGIC_VECTOR(resize(unsigned(byte_val), 32));

				WHEN OTHERS =>
					NULL;

			END CASE;
		END IF;

	END PROCESS load_extension_logic;

	o_mem_addr <= i_alu_result_ex;
	o_mem_write_en <= i_mem_write_ex;
	o_mem_write_data <= i_rs2_data_ex;

	store_byte_enable_logic : PROCESS (i_mem_write_ex, i_funct3_ex, i_alu_result_ex)
	BEGIN
		o_mem_byte_en <= "0000";

		IF i_mem_write_ex = '1' THEN
			CASE i_funct3_ex IS
				WHEN "010" =>
					o_mem_byte_en <= "1111";

				WHEN "001" =>
					IF i_alu_result_ex(1) = '0' THEN
						o_mem_byte_en <= "0011"; -- Bytes 1 and 0
					ELSE
						o_mem_byte_en <= "1100"; -- Bytes 3 and 2
					END IF;

				WHEN "000" =>
					CASE i_alu_result_ex(1 DOWNTO 0) IS
						WHEN "00" => o_mem_byte_en <= "0001"; -- Byte 0
						WHEN "01" => o_mem_byte_en <= "0010"; -- Byte 1
						WHEN "10" => o_mem_byte_en <= "0100"; -- Byte 2
						WHEN "11" => o_mem_byte_en <= "1000"; -- Byte 3
						WHEN OTHERS => o_mem_byte_en <= "0000";
					END CASE;

				WHEN OTHERS =>
					o_mem_byte_en <= "0000";

			END CASE;
		END IF;
	END PROCESS store_byte_enable_logic;

        o_alu_result_mem <= i_alu_result_ex;
        o_pc4_mem        <= i_pc4_ex;
        o_reg_write_mem  <= i_reg_write_ex;
        o_wb_src_mem     <= i_wb_src_ex;
        o_rd_addr_mem    <= i_rd_addr_ex;

END ARCHITECTURE structural;

