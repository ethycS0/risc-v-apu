LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY immediate_reconstruct_unit IS
	PORT (
		i_instruction : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_immediate   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY immediate_reconstruct_unit;
ARCHITECTURE behavioral OF immediate_reconstruct_unit IS
BEGIN
	imm_reconstruct : PROCESS (i_instruction)
	BEGIN
		CASE i_instruction(6 DOWNTO 2) IS
			WHEN b"01101" | b"00101" =>
				o_immediate <= i_instruction(31 DOWNTO 12) & (11 DOWNTO 0 => '0');
			WHEN b"11011" =>
				o_immediate <= (31 DOWNTO 20 => i_instruction(31)) & i_instruction(19 DOWNTO 12) & i_instruction(20) & i_instruction(30 DOWNTO 21) & '0';
			WHEN b"11000" =>
				o_immediate <= (31 DOWNTO 12 => i_instruction(31)) & i_instruction(7) & i_instruction(30 DOWNTO 25) & i_instruction(11 DOWNTO 8) & '0';
			WHEN b"11001" | b"00000" | b"00100" =>
				o_immediate <= (31 DOWNTO 11 => i_instruction(31)) & i_instruction(30 DOWNTO 20);
			WHEN b"01000" =>
				o_immediate <= (31 DOWNTO 11 => i_instruction(31)) & i_instruction(30 DOWNTO 25) & i_instruction(11 DOWNTO 7);
			WHEN b"11100" =>
				o_immediate <= (31 DOWNTO 12 => '0') & i_instruction(31 DOWNTO 20);
			WHEN OTHERS =>
				o_immediate <= (OTHERS => '0');
		END CASE;
	END PROCESS imm_reconstruct;
END ARCHITECTURE behavioral;

