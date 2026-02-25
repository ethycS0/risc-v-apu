--! @file ex_control_unit.vhd
--! Execute Stage Control Unit
--! @author ethycS
--! @details This module generates execution control signals for the Execute (EX) stage
--! based on the operation type and function fields from the decoded instruction.
--! It produces ALU operation commands, CSR operation commands, trap signals, and
--! CSR write enables.
--!
--! The control unit handles:
--! - ALU operation selection for R-type, I-type, Load/Store, Branch, Jump, LUI, AUIPC
--! - CSR operation decoding (CSRRW, CSRRS, CSRRC and immediate variants)
--! - System instruction detection (ECALL, EBREAK, MRET)
--! - CSR write enable optimization (suppresses writes when rs1/uimm is zero for set/clear)
--!
--! For CSR set/clear operations (CSRRS/CSRRC), writes are only enabled when the source
--! operand is non-zero, as per RISC-V specification optimization.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY ex_control_unit IS
	PORT (
		i_opr_type   : IN t_OprType;                      --! Operation type from ID stage (R-type, I-type, Branch, etc.)
		i_funct3     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);   --! Function field 3 bits (operation selector)
		i_funct12    : IN STD_LOGIC_VECTOR(11 DOWNTO 0);  --! Function field 12 bits (for system instructions and funct7)
		i_src_a_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Source A data (used for CSR write optimization)

		o_csr_write_en : OUT STD_LOGIC;     --! CSR write enable signal
		o_trap_type    : OUT t_TrapType;    --! Trap type (ECALL, EBREAK, MRET, or NONE)
		o_alu_command  : OUT t_AluOpcodes;  --! ALU operation command
		o_csr_command  : OUT t_CsrOpcodes   --! CSR operation command (RW, RS, RC)

	);
END ENTITY ex_control_unit;

ARCHITECTURE behavioral OF ex_control_unit IS

	SIGNAL funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0); --! Function field 7 bits extracted from funct12[11:5]

BEGIN

	-- Extract funct7 field from upper bits of funct12
	funct7 <= i_funct12(11 DOWNTO 5);

	--! @brief Execute Control Signal Generation Process
	--! @details Combinational process that decodes operation type and function fields
	--! to generate execution control signals. Default values are assigned first, then
	--! overridden based on the operation type and function fields.
	--!
	--! R-type and I-type decoding uses funct3 and funct7 to distinguish between:
	--! - ADD/SUB (funct7[5] selects subtraction for R-type)
	--! - Shift operations (funct7[5] selects arithmetic vs logical right shift)
	--! - Logical operations (AND, OR, XOR)
	--! - Comparison operations (SLT, SLTU)
	--!
	--! System instruction decoding identifies ECALL (0x000), EBREAK (0x001), and
	--! MRET (0x302) based on funct12. CSR instructions use funct3 to determine
	--! operation type and conditionally enable writes based on source operand value.
	PROCESS (i_opr_type, i_funct3, funct7, i_funct12, i_src_a_data)
		VARIABLE v_src_is_zero : BOOLEAN; --! Flag indicating source operand is zero
	BEGIN
		-- Default control signal values
		o_alu_command <= ALU_ADD;
		o_csr_command <= CSR_ILLEGAL;
		o_trap_type <= TRAP_NONE;
		o_csr_write_en <= '0';

		-- Check if source operand is zero (for CSR write optimization)
		IF unsigned(i_src_a_data) = 0 THEN
			v_src_is_zero := TRUE;
		ELSE
			v_src_is_zero := FALSE;
		END IF;

		CASE i_opr_type IS

			WHEN OP_LUI =>  -- LUI: Load Upper Immediate
				o_alu_command <= ALU_COPY_B;

			WHEN OP_LOAD_STORE | OP_JUMP | OP_AUIPC =>  -- Address calculation
				o_alu_command <= ALU_ADD;

                        WHEN OP_LPAD => -- Check Landing Pad Label/Validity
                                o_alu_command <=ALU_SUB;

			WHEN OP_BRANCH =>  -- Branch comparison
				o_alu_command <= ALU_SUB;

			WHEN OP_R_TYPE | OP_I_TYPE =>  -- ALU operations
				CASE i_funct3 IS
					WHEN "000" =>  -- ADD/SUB
						IF i_opr_type = OP_R_TYPE AND funct7(5) = '1' THEN
							o_alu_command <= ALU_SUB;
						ELSE
							o_alu_command <= ALU_ADD;
						END IF;

					WHEN "101" =>  -- SRL/SRA (logical/arithmetic right shift)
						IF funct7(5) = '1' THEN
							o_alu_command <= ALU_SRA;
						ELSE
							o_alu_command <= ALU_SRL;
						END IF;

					WHEN "010" => o_alu_command <= ALU_SLT;   -- SLT: Set Less Than (signed)
					WHEN "011" => o_alu_command <= ALU_SLTU;  -- SLTU: Set Less Than (unsigned)
					WHEN "100" => o_alu_command <= ALU_XOR;   -- XOR
					WHEN "110" => o_alu_command <= ALU_OR;    -- OR
					WHEN "111" => o_alu_command <= ALU_AND;   -- AND
					WHEN "001" => o_alu_command <= ALU_SLL;   -- SLL: Shift Left Logical
					WHEN OTHERS => o_alu_command <= ALU_ADD;
				END CASE;

			WHEN OP_SYSTEM =>  -- System and CSR instructions
				CASE i_funct3 IS
					WHEN "000" =>  -- System instructions (ECALL, EBREAK, MRET)
						CASE i_funct12 IS
							WHEN x"000" => o_trap_type <= TRAP_CALL;   -- ECALL
							WHEN x"001" => o_trap_type <= TRAP_BREAK;  -- EBREAK
							WHEN x"302" => o_trap_type <= TRAP_MRET;   -- MRET
							WHEN OTHERS => o_trap_type <= TRAP_NONE;
						END CASE;

					WHEN "001" | "101" =>  -- CSRRW/CSRRWI: Read/Write
						o_csr_command <= CSR_RW;
						o_csr_write_en <= '1';

					WHEN "010" | "110" =>  -- CSRRS/CSRRSI: Read/Set
						o_csr_command <= CSR_RS;
						IF NOT v_src_is_zero THEN  -- Only write if setting at least one bit
							o_csr_write_en <= '1';
						END IF;

					WHEN "011" | "111" =>  -- CSRRC/CSRRCI: Read/Clear
						o_csr_command <= CSR_RC;
						IF NOT v_src_is_zero THEN  -- Only write if clearing at least one bit
							o_csr_write_en <= '1';
						END IF;

					WHEN OTHERS =>
						NULL;
				END CASE;

                        WHEN OP_ILLEGAL => 
-- 🚾                                o_trap_type <= TRAP_ILLEGAL;
				o_alu_command <= ALU_ADD;
				o_csr_command <= CSR_ILLEGAL;

			WHEN OTHERS =>  -- Illegal or unsupported operation
				o_alu_command <= ALU_ADD;
				o_csr_command <= CSR_ILLEGAL;
		END CASE;
	END PROCESS;

END ARCHITECTURE behavioral;

