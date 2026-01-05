--! @file branch_adder.vhd
--! Branch Target Address Adder
--! @author ethycS
--! @details This module calculates branch and jump target addresses by performing
--! signed addition of the Program Counter (PC) and a sign-extended immediate offset.
--! It is used in the Execute stage for:
--! - Branch instructions: PC + branch_offset
--! - Jump instructions: PC + jump_offset (JAL) or RS1 + offset (JALR)
--! - AUIPC instruction: PC + upper_immediate
--!
--! The adder performs signed 32-bit addition to handle both positive and negative
--! offsets correctly.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY branch_adder IS
	PORT (
		i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Base address (PC or RS1 value)
		i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Sign-extended immediate offset
		o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)  --! Calculated target address (PC + IMM)
	);
END ENTITY branch_adder;

ARCHITECTURE behavioral OF branch_adder IS
BEGIN

	-- Signed addition for target address calculation
	o_branch_address <= STD_LOGIC_VECTOR(signed(i_pc) + signed(i_imm));

END ARCHITECTURE behavioral;

