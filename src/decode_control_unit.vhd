LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY decode_control_unit IS
	PORT (
		i_instruction : IN  std_logic_vector(31 DOWNTO 0);

		-- Primary control signals
		o_reg_write   : OUT std_logic;
		o_mem_read    : OUT std_logic;
		o_mem_write   : OUT std_logic;
		o_branch      : OUT std_logic;
		o_jump        : OUT std_logic;

		-- Mux select signals 
		o_alu_src_a   : OUT t_AluSrc_A;
		o_alu_src_b   : OUT t_AluSrc_B;
		o_wb_src      : OUT t_WritebackSrc;

		-- Intermediate ALUOp type
		o_alu_op_type : OUT t_ExecControl
	);
END ENTITY decode_control_unit;

ARCHITECTURE behavioral OF decode_control_unit IS
BEGIN
	decode_process : PROCESS (i_instruction)
	BEGIN
		-- Default assignments (safer design)
		o_reg_write   <= '0';
		o_mem_read    <= '0';
		o_mem_write   <= '0';
		o_branch      <= '0';
		o_jump        <= '0';
		o_alu_src_a   <= ALU_A_RS1;  -- Default to rs1
		o_alu_src_b   <= ALU_B_RS2;  -- Default to rs2
		o_wb_src      <= WB_SRC_ALU;
		o_alu_op_type <= OP_R_TYPE; -- Default to a safe type

		-- Decode based on the full 7-bit opcode
		CASE i_instruction(6 DOWNTO 0) IS

			-- U-Type: LUI
			WHEN "0110111" =>
				o_reg_write   <= '1';
				o_alu_src_a   <= ALU_A_ZERO; -- Input A is 0 for LUI (0 + imm) or ignored for COPY_B
				o_alu_src_b   <= ALU_B_IMM;
				o_alu_op_type <= OP_LUI;

			-- U-Type: AUIPC
			WHEN "0010111" =>
				o_reg_write   <= '1';
				o_alu_src_a   <= ALU_A_PC; -- PC + imm
				o_alu_src_b   <= ALU_B_IMM;
				o_alu_op_type <= OP_AUIPC;

			-- J-Type: JAL
			WHEN "1101111" =>
				o_reg_write   <= '1';
				o_jump        <= '1';
				o_alu_src_a   <= ALU_A_PC; -- ALU calculates target addr: PC + imm
				o_alu_src_b   <= ALU_B_IMM;
				o_wb_src      <= WB_SRC_PC4;
				o_alu_op_type <= OP_JUMP;

			-- I-Type: JALR
			WHEN "1100111" =>
				o_reg_write   <= '1';
				o_jump        <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- ALU calculates target addr: rs1 + imm
				o_alu_src_b   <= ALU_B_IMM;
				o_wb_src      <= WB_SRC_PC4;
				o_alu_op_type <= OP_JUMP;

			-- B-Type: Branches
			WHEN "1100011" =>
				o_branch      <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- ALU does comparison: rs1 - rs2
				o_alu_src_b   <= ALU_B_RS2;
				o_alu_op_type <= OP_BRANCH;

			-- I-Type: Loads
			WHEN "0000011" =>
				o_reg_write   <= '1';
				o_mem_read    <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- ALU calculates address: rs1 + imm
				o_alu_src_b   <= ALU_B_IMM;
				o_wb_src      <= WB_SRC_MEM;
				o_alu_op_type <= OP_LOAD_STORE;

			-- S-Type: Stores
			WHEN "0100011" =>
				o_mem_write   <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- ALU calculates address: rs1 + imm
				o_alu_src_b   <= ALU_B_IMM;
				o_alu_op_type <= OP_LOAD_STORE;

			-- I-Type: Immediate arithmetic/logic
			WHEN "0010011" =>
				o_reg_write   <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- rs1 op imm
				o_alu_src_b   <= ALU_B_IMM;
				o_alu_op_type <= OP_I_TYPE;

			-- R-Type: Register arithmetic/logic
			WHEN "0110011" =>
				o_reg_write   <= '1';
				o_alu_src_a   <= ALU_A_RS1; -- rs1 op rs2
				o_alu_src_b   <= ALU_B_RS2;
				o_alu_op_type <= OP_R_TYPE;

			-- FENCE
			WHEN "0001111" =>
				NULL; -- NOP in a simple pipeline

			-- SYSTEM (ECALL/EBREAK)
			WHEN "1110011" =>
				NULL; -- Handle exceptions/interrupts

			-- OTHERS (Invalid opcode)
			WHEN OTHERS =>
				-- All signals remain at their default '0' state
				NULL;

		END CASE;
	END PROCESS decode_process;

END ARCHITECTURE behavioral;

