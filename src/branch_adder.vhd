LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY branch_adder IS
	PORT (
		i_pc : IN std_logic_vector(31 DOWNTO 0); 
		i_imm : IN std_logic_vector(31 DOWNTO 0);
		o_branch_address : OUT std_logic_vector(31 DOWNTO 0)
	);
END ENTITY branch_adder;

ARCHITECTURE behavioral OF branch_adder IS
BEGIN
	o_branch_address <= std_logic_vector(signed(i_pc) + signed(i_imm));

END ARCHITECTURE behavioral;

