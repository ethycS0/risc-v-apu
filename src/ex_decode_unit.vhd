LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY ex_decode_unit IS
	PORT (
		i_ex_op_type : IN t_ExecControl;
		i_funct3     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct7     : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		i_src_a_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		o_trap         : OUT STD_LOGIC;
		o_csr_write_en : OUT STD_LOGIC;
		o_alu_command : OUT t_AluOpcodes;
		o_csr_command : OUT t_CsrOpcodes

	);
END ENTITY ex_decode_unit;

ARCHITECTURE behavioral OF ex_decode_unit IS
BEGIN
	PROCESS (i_ex_op_type, i_funct3, i_funct7, i_src_a_data)
		VARIABLE v_src_is_zero : BOOLEAN;
	BEGIN
		o_alu_command <= ALU_ADD;
		o_csr_command <= CSR_ILLEGAL;
		o_trap <= '0';
		o_csr_write_en <= '0';

		IF unsigned(i_src_a_data) = 0 THEN
			v_src_is_zero := TRUE;
		ELSE
			v_src_is_zero := FALSE;
		END IF;

		CASE i_ex_op_type IS
			WHEN OP_LUI =>
				o_alu_command <= ALU_COPY_B;

			WHEN OP_LOAD_STORE | OP_JUMP | OP_AUIPC =>
				o_alu_command <= ALU_ADD;

			WHEN OP_BRANCH =>
				o_alu_command <= ALU_SUB; -- Used for comparison

			WHEN OP_R_TYPE | OP_I_TYPE =>
				CASE i_funct3 IS
					WHEN "000" =>
						IF i_ex_op_type = OP_R_TYPE AND i_funct7(5) = '1' THEN
							o_alu_command <= ALU_SUB;
						ELSE
							o_alu_command <= ALU_ADD;
						END IF;
					WHEN "101" =>
						IF i_funct7(5) = '1' THEN
							o_alu_command <= ALU_SRA;
						ELSE
							o_alu_command <= ALU_SRL;
						END IF;
					WHEN "010" => o_alu_command <= ALU_SLT;
					WHEN "011" => o_alu_command <= ALU_SLTU;
					WHEN "100" => o_alu_command <= ALU_XOR;
					WHEN "110" => o_alu_command <= ALU_OR;
					WHEN "111" => o_alu_command <= ALU_AND;
					WHEN "001" => o_alu_command <= ALU_SLL;
					WHEN OTHERS => o_alu_command <= ALU_ADD;
				END CASE;
			WHEN OP_SYSTEM =>
				CASE i_funct3 IS
                                        -- SYSTEM Instructions
					WHEN "000" =>
						o_trap <= '1';

                                        -- CSR Instructions
					WHEN "001" | "101" => -- CSRRW
						o_csr_command <= CSR_RW;
						o_csr_write_en <= '1';

					WHEN "010" | "110" => -- CSRRS
						o_csr_command <= CSR_RS;
						IF NOT v_src_is_zero THEN
							o_csr_write_en <= '1';
						END IF;

					WHEN "011" | "111" => -- CSRRC
						o_csr_command <= CSR_RC;
						IF NOT v_src_is_zero THEN
							o_csr_write_en <= '1';
						END IF;

					WHEN OTHERS =>
						NULL; -- Illegal
				END CASE;

			WHEN OTHERS =>
				o_alu_command <= ALU_ADD; -- Safe default
				o_csr_command <= CSR_ILLEGAL;
		END CASE;
	END PROCESS;
END ARCHITECTURE behavioral;

