LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY branch_control_unit IS
	PORT (
		i_flags         : IN  t_AluFlags;
		i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_branch_active : IN  STD_LOGIC;
		o_branch_taken  : OUT STD_LOGIC
	);
END ENTITY branch_control_unit;

ARCHITECTURE behavioral OF branch_control_unit IS
BEGIN
	PROCESS (i_flags, i_funct3, i_branch_active)
	BEGIN
		o_branch_taken <= '0';
		IF i_branch_active = '1' THEN
			CASE i_funct3 IS
				WHEN "000" =>
					IF i_flags.zero = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "001" =>
					IF i_flags.zero = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "100" =>
					IF (i_flags.negative XOR i_flags.overflow) = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "101" =>
					IF (i_flags.negative XOR i_flags.overflow) = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "110" =>
					IF i_flags.carry = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "111" =>
					IF i_flags.carry = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN OTHERS =>
					o_branch_taken <= '0';
			END CASE;
		END IF;
	END PROCESS;
END ARCHITECTURE behavioral;

