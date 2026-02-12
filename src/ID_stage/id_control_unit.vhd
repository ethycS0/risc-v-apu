--! @file id_control_unit.vhd
--! Instruction Decode Control Unit
--! @author ethycS
--! @details This module implements the main control logic for the RV32I instruction
--! decode stage. It decodes the 7-bit opcode field (instruction[6:0]) and generates
--! all necessary control signals for the subsequent pipeline stages.
--!
--! The control unit determines:
--! - Register file write enable
--! - Memory access type (read/write)
--! - Operand source multiplexer selections
--! - Writeback data source
--! - Operation unit routing (ALU, CSR)
--! - Operation type classification for execution stage

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY id_control_unit IS
	PORT (
                i_elp : IN STD_LOGIC;                              --| ELP status for LPAD decoding
		i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);  --! 32-bit instruction from IF/ID pipeline register

		o_reg_write : OUT STD_LOGIC;  --! Register file write enable signal
		o_mem_read  : OUT STD_LOGIC;  --! Data memory read enable (for Load instructions)
		o_mem_write : OUT STD_LOGIC;  --! Data memory write enable (for Store instructions)

		o_src_a  : OUT t_SrcA;         --! Source A multiplexer control (selects RS1, PC, zero, or UIMM)
		o_src_b  : OUT t_SrcB;         --! Source B multiplexer control (selects RS2 or immediate)
		o_wb_src : OUT t_WritebackSrc; --! Writeback multiplexer control (selects ALU result, memory, or PC+4)

		o_opr_unit : OUT t_OprUnit;    --! Target execution unit (ALU or CSR)
		o_opr_type : OUT t_OprType     --! Operation classification for execution stage decoding
	);
END ENTITY id_control_unit;

ARCHITECTURE behavioral OF id_control_unit IS
BEGIN

	--! @brief Control Signal Generation Process
	--! @details Combinational process that decodes the instruction opcode and generates
	--! all control signals. Default values are assigned first, then overridden based on
	--! the opcode field. This implements the main instruction decoder for RV32I base
	--! instruction set including:
	--! - LUI (0110111): Load Upper Immediate
	--! - AUIPC (0010111): Add Upper Immediate to PC
	--! - JAL (1101111): Jump and Link
	--! - JALR (1100111): Jump and Link Register
	--! - Branch instructions (1100011): BEQ, BNE, BLT, BGE, BLTU, BGEU
	--! - Load instructions (0000011): LB, LH, LW, LBU, LHU
	--! - Store instructions (0100011): SB, SH, SW
	--! - I-type ALU (0010011): ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
	--! - R-type ALU (0110011): ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
	--! - System/CSR (1110011): CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
	U_CONTROL_SIGNAL_GEN : PROCESS (i_instruction)
	BEGIN
		-- Default control signal values (safe defaults for illegal/unknown instructions)
		o_reg_write <= '0';
		o_mem_read <= '0';
		o_mem_write <= '0';
		o_src_a <= SRC_A_RS1;
		o_src_b <= SRC_B_RS2;
		o_wb_src <= WB_SRC_EX_RESULT;
		o_opr_type <= OP_ILLEGAL;
		o_opr_unit <= UNIT_ALU;

		CASE i_instruction(6 DOWNTO 0) IS

			WHEN "0110111" =>  -- LUI
				o_reg_write <= '1';
				o_src_a <= SRC_A_ZERO;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_LUI;

			WHEN "0010111" =>  -- AUIPC | LPAD
                                IF i_instruction(11 DOWNTO 7) = "00000" AND i_elp = '1' THEN
                                        o_src_a <= SRC_A_RS1;
                                        o_src_b <= SRC_B_IMM;
                                        o_opr_type <= OP_LPAD;
                                ELSE
                                        o_reg_write <= '1';
                                        o_src_a <= SRC_A_PC;
                                        o_src_b <= SRC_B_IMM;
                                        o_opr_type <= OP_AUIPC;
                                END IF;

			WHEN "1101111" =>  -- JAL
				o_reg_write <= '1';
				o_src_a <= SRC_A_PC;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_opr_type <= OP_JUMP;

			WHEN "1100111" =>  -- JALR
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_opr_type <= OP_JUMP;

			WHEN "1100011" =>  -- Branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_RS2;
				o_opr_type <= OP_BRANCH;

			WHEN "0000011" =>  -- Load instructions (LB, LH, LW, LBU, LHU)
				o_reg_write <= '1';
				o_mem_read <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_MEM;
				o_opr_type <= OP_LOAD_STORE;

			WHEN "0100011" =>  -- Store instructions (SB, SH, SW)
				o_mem_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_LOAD_STORE;

			WHEN "0010011" =>  -- I-type ALU operations
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_I_TYPE;

			WHEN "0110011" =>  -- R-type ALU operations
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_RS2;
				o_opr_type <= OP_R_TYPE;

			WHEN "1110011" =>  -- System/CSR instructions
				o_opr_unit <= UNIT_CSR;
				o_opr_type <= OP_SYSTEM;
				o_reg_write <= '1';
				IF i_instruction(14) = '1' THEN  -- Immediate variant (CSRRWI, CSRRSI, CSRRCI)
					o_src_a <= SRC_A_UIMM;
				ELSE  -- Register variant (CSRRW, CSRRS, CSRRC)
					o_src_a <= SRC_A_RS1;
				END IF;
				o_src_b <= SRC_B_IMM;

			WHEN OTHERS =>  -- Illegal or unsupported opcode
				NULL;

		END CASE;
	END PROCESS U_CONTROL_SIGNAL_GEN;

END ARCHITECTURE behavioral;

