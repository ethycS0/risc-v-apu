--! @file immediate_reconstruct_unit.vhd
--! Immediate Reconstruction Unit
--! @author ethycS
--! @details This module extracts and reconstructs immediate values from RV32I
--! instruction encodings. RISC-V uses multiple immediate formats (I, S, B, U, J)
--! where immediate bits are scattered across different instruction fields.
--!
--! This unit handles:
--! - Sign extension for signed immediates
--! - Zero extension for unsigned immediates (CSR)
--! - Bit reordering and alignment based on instruction format
--! - Left-shifting for PC-relative offsets (Branch, Jump)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY immediate_reconstruct_unit IS
	PORT (
		i_instruction : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! 32-bit instruction from IF/ID pipeline register
		o_immediate   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)   --! Reconstructed 32-bit immediate value (sign/zero-extended)
	);
END ENTITY immediate_reconstruct_unit;

ARCHITECTURE behavioral OF immediate_reconstruct_unit IS
BEGIN

	--! @brief Immediate Reconstruction Process
	--! @details Combinational process that decodes instruction bits [6:2] (partial opcode)
	--! and reconstructs the appropriate immediate format. Each RV32I instruction type
	--! has a specific immediate encoding:
	--! - U-type (LUI, AUIPC): Upper 20 bits with lower 12 bits zeroed
	--! - J-type (JAL): 20-bit signed offset, reordered and left-shifted by 1
	--! - B-type (Branch): 12-bit signed offset, reordered and left-shifted by 1
	--! - I-type (JALR, Load, I-ALU): 12-bit signed immediate
	--! - S-type (Store): 12-bit signed immediate split between [31:25] and [11:7]
	--! - CSR immediate: 12-bit zero-extended for UIMM field
	imm_reconstruct : PROCESS (i_instruction)
	BEGIN
		CASE i_instruction(6 DOWNTO 2) IS

			WHEN b"01101" | b"00101" =>  -- U-type: LUI (0110111) and AUIPC (0010111)
				o_immediate <= i_instruction(31 DOWNTO 12) & (11 DOWNTO 0 => '0');

			WHEN b"11011" =>  -- J-type: JAL (1101111)
				o_immediate <= (31 DOWNTO 20 => i_instruction(31)) & i_instruction(19 DOWNTO 12) & i_instruction(20) & i_instruction(30 DOWNTO 21) & '0';

			WHEN b"11000" =>  -- B-type: Branch (1100011)
				o_immediate <= (31 DOWNTO 12 => i_instruction(31)) & i_instruction(7) & i_instruction(30 DOWNTO 25) & i_instruction(11 DOWNTO 8) & '0';

			WHEN b"11001" | b"00000" | b"00100" =>  -- I-type: JALR (1100111), Load (0000011), I-ALU (0010011)
				o_immediate <= (31 DOWNTO 11 => i_instruction(31)) & i_instruction(30 DOWNTO 20);

			WHEN b"01000" =>  -- S-type: Store (0100011)
				o_immediate <= (31 DOWNTO 11 => i_instruction(31)) & i_instruction(30 DOWNTO 25) & i_instruction(11 DOWNTO 7);

			WHEN b"11100" =>  -- CSR: System (1110011) - Zero-extended for UIMM field
				o_immediate <= (31 DOWNTO 12 => '0') & i_instruction(31 DOWNTO 20);

			WHEN OTHERS =>  -- Illegal or unsupported instruction format
				o_immediate <= (OTHERS => '0');

		END CASE;
	END PROCESS imm_reconstruct;

END ARCHITECTURE behavioral;

