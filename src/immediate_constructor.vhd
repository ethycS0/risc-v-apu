LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY immediate_constructor_unit IS
	PORT (
		instruction : IN std_logic_vector(31 DOWNTO 0);
		immediate : OUT std_logic_vector(31 DOWNTO 0)
	);
END ENTITY immediate_constructor_unit;


ARCHITECTURE behavioral OF immediate_constructor_unit IS
BEGIN
	imm_reconstruct : PROCESS (instruction)
	BEGIN
		CASE instruction(6 DOWNTO 2) IS
			-- U
			WHEN b"01101" | b"00101" => 
				immediate <= instruction(31 DOWNTO 12) & (11 DOWNTO 0 => '0');
			-- J
			WHEN b"11011" => 
				immediate <= (31 DOWNTO 20 => instruction(31)) & instruction(19 DOWNTO 12) & instruction(20) & instruction(30 DOWNTO 21) & '0';
			-- B
			WHEN b"11000" => 
				immediate <= (31 DOWNTO 12 => instruction(31)) & instruction(7) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 8) & '0';
			-- I
			WHEN b"11001" | b"00000" | b"00100" | b"11100" => 
				immediate <= (31 DOWNTO 11 => instruction(31)) & instruction(30 DOWNTO 20);
			-- S
			WHEN b"01000" => 
				immediate <= (31 DOWNTO 11 => instruction(31)) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 7);
			-- R
                        WHEN OTHERS => 
				immediate <= (OTHERS => '0');
		END CASE;
	END PROCESS imm_reconstruct;
END ARCHITECTURE behavioral;
