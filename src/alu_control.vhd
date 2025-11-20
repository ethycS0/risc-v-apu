LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY alu_control IS
	PORT (
		i_alu_op_type : IN t_ExecControl;
		i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);

		o_alu_command : OUT t_AluOpcodes
	);
END ENTITY alu_control;

ARCHITECTURE behavioral OF alu_control IS
BEGIN
	PROCESS (i_alu_op_type, i_funct3, i_funct7)
	BEGIN
                o_alu_command <= ALU_ADD;

		CASE i_alu_op_type IS
			WHEN OP_LUI =>
				o_alu_command <= ALU_COPY_B;

			WHEN OP_LOAD_STORE | OP_JUMP | OP_AUIPC =>
				o_alu_command <= ALU_ADD;

			WHEN OP_BRANCH =>
				o_alu_command <= ALU_SUB; -- Used for comparison

			WHEN OP_R_TYPE | OP_I_TYPE =>
				CASE i_funct3 IS
					WHEN "000" =>
						IF i_alu_op_type = OP_R_TYPE AND i_funct7(5) = '1' THEN
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
			WHEN OTHERS =>
				o_alu_command <= ALU_ADD; -- Safe default
		END CASE;
	END PROCESS;
END ARCHITECTURE behavioral;

