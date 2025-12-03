LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY branch_adder IS
	PORT (
		i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY branch_adder;

ARCHITECTURE behavioral OF branch_adder IS
BEGIN
	o_branch_address <= STD_LOGIC_VECTOR(signed(i_pc) + signed(i_imm));

END ARCHITECTURE behavioral;

