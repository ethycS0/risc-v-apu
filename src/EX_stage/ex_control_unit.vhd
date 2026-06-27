--! @file ex_control_unit.vhd
--! @brief Execution Stage Control Unit
--! @author ethycS
--! @details This module performs second-level instruction decoding in the Execute stage.
--! It translates high-level operation types and instruction sub-fields (funct3, funct7, funct12)
--! into precise control codes for the ALU, CSR, and trap logic.
--!
--! Key features:
--! - Decodes specific ALU opcodes for R-type and I-type arithmetic operations.
--! - Maps ECALL, EBREAK, and MRET instructions to pipeline fault tags.
--! - Decodes custom shadow stack instructions within the CSR system opcode space:
--!   - `sspush` maps to `CSR_SSW` (Shadow Stack Write)
--!   - `sspop` maps to `CSR_SSR` (Shadow Stack Read)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY ex_control_unit IS
	PORT (
		i_opr_type     : IN  t_OprType;                     --! High-level operation category from ID stage
		i_reg_write_en : IN  STD_LOGIC;                     --! Register write enable flag from ID stage
		i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);  --! 3-bit instruction sub-opcode field
		i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0); --! 12-bit instruction sub-opcode field (CSR address or system flags)
		i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Resolved Operand A data (used to detect zero values for CSR updates)

		o_csr_write_en : OUT STD_LOGIC;                     --! Write enable strobe for target CSR
		o_trap_type    : OUT t_fault_tag;                   --! Exception type decoded from current instruction
		o_alu_command  : OUT t_AluOpcodes;                  --! Specific operation command for the ALU
		o_csr_command  : OUT t_CsrOpcodes                   --! Specific operation command for the CSR unit
	);
END ENTITY ex_control_unit;

ARCHITECTURE behavioral OF ex_control_unit IS

	SIGNAL funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0); --! Extracted funct7 field from funct12 bits [11:5]

BEGIN

	funct7 <= i_funct12(11 DOWNTO 5);

	--! @brief Second-Level Instruction Decode Process
	--! @details Combinational process that maps instruction sub-fields to ALU and CSR commands.
	--! Overrides default operations for System and security-related instructions:
	--! - **Zicfilp**: Maps the `lpad` instruction type (`OP_LPAD`) to `ALU_SUB` to compute label equality.
	--! - **Smcfiss**: Maps custom system instructions (funct3="100") to `CSR_SSW` or `CSR_SSR` shadow stack operations.
	--! - **Traps**: Identifies ECALL, EBREAK, and MRET instructions and decodes them to exception fault tags.
	P_STAGE_2_DECODE : PROCESS (ALL)
		VARIABLE v_src_is_zero : BOOLEAN;
	BEGIN
		o_alu_command  <= ALU_ADD;
		o_csr_command  <= CSR_ILLEGAL;
		o_trap_type    <= VALID;
		o_csr_write_en <= '0';

		IF unsigned(i_src_a_data) = 0 THEN
			v_src_is_zero := TRUE;
		ELSE
			v_src_is_zero := FALSE;
		END IF;

		CASE i_opr_type IS

			WHEN OP_LUI =>
				o_alu_command <= ALU_COPY_B;

			WHEN OP_LOAD_STORE | OP_JUMP | OP_AUIPC =>
				o_alu_command <= ALU_ADD;

			WHEN OP_LPAD =>
				o_alu_command <= ALU_SUB;

			WHEN OP_BRANCH =>
				o_alu_command <= ALU_SUB;

			WHEN OP_R_TYPE | OP_I_TYPE =>
				CASE i_funct3 IS
					WHEN "000" =>
						IF i_opr_type = OP_R_TYPE AND funct7(5) = '1' THEN
							o_alu_command <= ALU_SUB;
						ELSE
							o_alu_command <= ALU_ADD;
						END IF;

					WHEN "101" =>
						IF funct7(5) = '1' THEN
							o_alu_command <= ALU_SRA;
						ELSE
							o_alu_command <= ALU_SRL;
						END IF;

					WHEN "010"  => o_alu_command  <= ALU_SLT;
					WHEN "011"  => o_alu_command  <= ALU_SLTU;
					WHEN "100"  => o_alu_command  <= ALU_XOR;
					WHEN "110"  => o_alu_command  <= ALU_OR;
					WHEN "111"  => o_alu_command  <= ALU_AND;
					WHEN "001"  => o_alu_command  <= ALU_SLL;
					WHEN OTHERS => o_alu_command <= ALU_ADD;
				END CASE;

			WHEN OP_SYSTEM =>
				CASE i_funct3 IS
					WHEN "000" =>
						CASE i_funct12 IS
							WHEN x"000" => o_trap_type <= TRAP_ECALL;
							WHEN x"001" => o_trap_type <= TRAP_EBREAK;
							WHEN x"302" => o_trap_type <= TRAP_MRET;
							WHEN OTHERS => o_trap_type <= VALID;
						END CASE;

					WHEN "001" | "101" =>
						o_csr_command  <= CSR_RW;
						o_csr_write_en <= '1';

					WHEN "010" | "110" =>
						o_csr_command <= CSR_RS;
						IF NOT v_src_is_zero THEN
							o_csr_write_en <= '1';
						END IF;

					WHEN "011" | "111" =>
						o_csr_command <= CSR_RC;
						IF NOT v_src_is_zero THEN
							o_csr_write_en <= '1';
						END IF;

                                        WHEN "100" => -- Custom Shadow Stack Opcode space
                                                o_csr_write_en <= '1';
                                                IF i_funct12 = "110011011100" THEN -- sspop (shadow stack pop)
                                                        o_csr_command <= CSR_SSR;
                                                        IF i_reg_write_en = '1' THEN
                                                                o_csr_write_en <= '0';
                                                        END IF;
                                                ELSIF i_funct12(11 DOWNTO 5) = "1100111" THEN -- sspush (shadow stack push)
                                                        o_csr_command <= CSR_SSW;
                                                END IF;

					WHEN OTHERS =>
						NULL;
				END CASE;

			WHEN OP_ILLEGAL =>
                                -- o_trap_type <= TRAP_ILLEGAL;
				o_alu_command <= ALU_ADD;
				o_csr_command <= CSR_ILLEGAL;

			WHEN OTHERS =>
				o_alu_command <= ALU_ADD;
				o_csr_command <= CSR_ILLEGAL;
		END CASE;
	END PROCESS P_STAGE_2_DECODE;

END ARCHITECTURE behavioral;

