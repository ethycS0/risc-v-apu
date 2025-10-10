LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.rv32i_pkg.ALL;

ENTITY alu IS

	PORT (
		operation : IN exec_opcodes_t; 
		operand_1 : IN std_logic_vector(31 DOWNTO 0);
		operand_2 : IN std_logic_vector(31 DOWNTO 0);
		result : OUT std_logic_vector(31 DOWNTO 0)
	);

END ENTITY alu;

ARCHITECTURE behavioral OF alu IS
BEGIN
	alu_operation : PROCESS (operation, operand_1, operand_2)
	BEGIN
		CASE operation IS
			WHEN OP_ADD => 
				result <= std_logic_vector(signed(operand_1) + signed(operand_2));
			WHEN OP_SLT => 
				IF signed(operand_1) < signed(operand_2) THEN
					result <= (31 DOWNTO 1 => '0') & '1';
				ELSE
					result <= (OTHERS => '0');
				END IF;
			WHEN OP_SLTU => 
				IF unsigned(operand_1) < unsigned(operand_2) THEN
					result <= (31 DOWNTO 1 => '0') & '1';
				ELSE
					result <= (OTHERS => '0');
				END IF;
			WHEN OP_XOR => 
				result <= operand_1 XOR operand_2;
			WHEN OP_OR => 
				result <= operand_1 OR operand_2;
			WHEN OP_AND => 
				result <= operand_1 AND operand_2;
			WHEN OP_SLL => 
				result <= std_logic_vector(shift_left(unsigned(operand_1), to_integer(unsigned(operand_2(4 DOWNTO 0)))));
			WHEN OP_SRL => 
				result <= std_logic_vector(shift_right(unsigned(operand_1), to_integer(unsigned(operand_2(4 DOWNTO 0)))));
			WHEN OP_SRA => 
				result <= std_logic_vector(shift_right(signed(operand_1), to_integer(unsigned(operand_2(4 DOWNTO 0)))));
			WHEN OP_SUB => 
				result <= std_logic_vector(signed(operand_1) - signed(operand_2));
			WHEN OTHERS => 
				result <= (OTHERS => '0');
		END CASE;
	END PROCESS alu_operation;

END ARCHITECTURE behavioral;
