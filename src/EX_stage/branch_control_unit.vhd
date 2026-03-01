--! @file branch_control_unit.vhd
--! Branch Control Unit
--! @author ethycS
--! @details This module evaluates branch conditions for RV32I conditional branch
--! instructions. It uses ALU flags (zero, carry, negative, overflow) and the funct3
--! field to determine whether a branch should be taken.
--!
--! Supported branch instructions (decoded via funct3):
--! - BEQ (000): Branch if Equal (zero flag set)
--! - BNE (001): Branch if Not Equal (zero flag clear)
--! - BLT (100): Branch if Less Than - signed (N XOR V)
--! - BGE (101): Branch if Greater or Equal - signed (NOT(N XOR V))
--! - BLTU (110): Branch if Less Than - unsigned (carry clear)
--! - BGEU (111): Branch if Greater or Equal - unsigned (carry set)
--!
--! The unit only activates when i_branch_active is asserted, indicating a branch
--! instruction is in the Execute stage.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY branch_control_unit IS
	PORT (
		i_flags         : IN  t_AluFlags;                   --! ALU flags (carry, overflow, negative, zero)
		i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0); --! Function field from instruction (branch type selector)
		i_branch_active : IN  STD_LOGIC;                    --! Branch instruction active flag (1 for branch ops)
		o_branch_taken  : OUT STD_LOGIC                     --! Branch taken signal (1 = take branch, 0 = fall through)
	);
END ENTITY branch_control_unit;

ARCHITECTURE behavioral OF branch_control_unit IS
BEGIN

	--! @brief Branch Condition Evaluation Process
	--! @details Combinational process that evaluates branch conditions based on funct3
	--! and ALU flags. Each branch type has a specific condition:
	--! - BEQ/BNE use the zero flag from equality comparison
	--! - BLT/BGE use signed comparison (negative XOR overflow detects sign difference)
	--! - BLTU/BGEU use unsigned comparison (carry flag from subtraction)
	--! The process only evaluates conditions when i_branch_active is high; otherwise
	--! it defaults to not taken.
        P_BRANCH_CONTROL : PROCESS (ALL)
	BEGIN
		o_branch_taken <= '0';
		IF i_branch_active = '1' THEN
			CASE i_funct3 IS
				WHEN "000" =>  -- BEQ: Branch if Equal
					IF i_flags.zero = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "001" =>  -- BNE: Branch if Not Equal
					IF i_flags.zero = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "100" =>  -- BLT: Branch if Less Than (signed)
					IF (i_flags.negative XOR i_flags.overflow) = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "101" =>  -- BGE: Branch if Greater or Equal (signed)
					IF (i_flags.negative XOR i_flags.overflow) = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "110" =>  -- BLTU: Branch if Less Than (unsigned)
					IF i_flags.carry = '0' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN "111" =>  -- BGEU: Branch if Greater or Equal (unsigned)
					IF i_flags.carry = '1' THEN
						o_branch_taken <= '1';
					END IF;

				WHEN OTHERS =>  -- Invalid branch type
					o_branch_taken <= '0';
			END CASE;
		END IF;
	END PROCESS;

END ARCHITECTURE behavioral;

