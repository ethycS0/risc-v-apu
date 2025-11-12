LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY branch_condition_unit IS
	PORT (
		i_flags : IN t_AluFlags; -- Flags from the main ALU's output
		i_funct3 : IN std_logic_vector(2 DOWNTO 0);
		i_branch_active : IN std_logic; -- A control signal that is '1' if the instruction is a branch
		o_branch_taken : OUT std_logic -- The final decision bit
	);
END ENTITY branch_condition_unit;

ARCHITECTURE behavioral OF branch_condition_unit IS
BEGIN
	PROCESS (i_flags, i_funct3, i_branch_active)
	BEGIN
		o_branch_taken <= '0';
		IF i_branch_active = '1' THEN
			CASE i_funct3 IS
				-- BEQ: Branch if rs1 == rs2
				WHEN "000" => 
					IF i_flags.zero = '1' THEN
						o_branch_taken <= '1';
					END IF;

                                -- BNE: Branch if rs1 != rs2
				WHEN "001" => 
					IF i_flags.zero = '0' THEN
						o_branch_taken <= '1';
					END IF;

                                -- BLT: Branch if rs1 < rs2 (signed)
				WHEN "100" => 
					IF (i_flags.negative XOR i_flags.overflow) = '1' THEN
						o_branch_taken <= '1';
					END IF;

                                -- BGE: Branch if rs1 >= rs2 (signed)
				WHEN "101" => 
					IF (i_flags.negative XOR i_flags.overflow) = '0' THEN
						o_branch_taken <= '1';
					END IF;

                                -- BLTU: Branch if rs1 < rs2 (unsigned)
				WHEN "110" => 
					IF i_flags.carry = '0' THEN -- A borrow occurred
						o_branch_taken <= '1';
					END IF;

                                -- BGEU: Branch if rs1 >= rs2 (unsigned)
				WHEN "111" => 
					IF i_flags.carry = '1' THEN -- No borrow occurred
						o_branch_taken <= '1';
					END IF;
 
                                -- Should not happen for valid instructions
				WHEN OTHERS => 
					o_branch_taken <= '0';
			END CASE;
		END IF;
	END PROCESS;
END ARCHITECTURE behavioral;
