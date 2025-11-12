LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY tb_alu_control IS
END ENTITY tb_alu_control;

ARCHITECTURE behavioral OF tb_alu_control IS

	CONSTANT CLK_PERIOD : TIME := 10 ns;

	SIGNAL tb_i_opcode : t_ExecControl;
	SIGNAL tb_i_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_i_funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_o_alu_command : t_AluOpcodes;

BEGIN

	uut : ENTITY work.alu_control_unit
		PORT MAP(
			i_opcode => tb_i_opcode,
			i_funct3 => tb_i_funct3,
			i_funct7 => tb_i_funct7,
			o_alu_command => tb_o_alu_command
		);

	stim_proc : PROCESS
	BEGIN
		-- Test 1: LUI - Load Upper Immediate (should copy immediate)
		tb_i_opcode <= OP_LUI;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_COPY_B
		REPORT "Test 1 failed: LUI should output ALU_COPY_B" SEVERITY error;

		-- Test 2: AUIPC - Add Upper Immediate to PC
		tb_i_opcode <= OP_AUIPC;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_ADD
		REPORT "Test 2 failed: AUIPC should output ALU_ADD" SEVERITY error;

		-- Test 3: Load/Store operations
		tb_i_opcode <= OP_LOAD_STORE;
		tb_i_funct3 <= "010";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_ADD
		REPORT "Test 3 failed: LOAD_STORE should output ALU_ADD" SEVERITY error;

		-- Test 4: JAL/JALR - Jump instructions
		tb_i_opcode <= OP_JUMP;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_ADD
		REPORT "Test 4 failed: JUMP should output ALU_ADD" SEVERITY error;

		-- Test 5: Branch - uses SUB for comparison
		tb_i_opcode <= OP_BRANCH;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SUB
		REPORT "Test 5 failed: BRANCH should output ALU_SUB" SEVERITY error;

		-- Test 6: R-type ADD
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_ADD
		REPORT "Test 6 failed: R-type ADD" SEVERITY error;

		-- Test 7: R-type SUB
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0100000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SUB
		REPORT "Test 7 failed: R-type SUB" SEVERITY error;

		-- Test 8: R-type SLL
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "001";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLL
		REPORT "Test 8 failed: R-type SLL" SEVERITY error;

		-- Test 9: R-type SLT
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "010";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLT
		REPORT "Test 9 failed: R-type SLT" SEVERITY error;

		-- Test 10: R-type SLTU
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "011";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLTU
		REPORT "Test 10 failed: R-type SLTU" SEVERITY error;

		-- Test 11: R-type XOR
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "100";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_XOR
		REPORT "Test 11 failed: R-type XOR" SEVERITY error;

		-- Test 12: R-type SRL
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "101";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SRL
		REPORT "Test 12 failed: R-type SRL" SEVERITY error;

		-- Test 13: R-type SRA
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "101";
		tb_i_funct7 <= "0100000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SRA
		REPORT "Test 13 failed: R-type SRA" SEVERITY error;

		-- Test 14: R-type OR
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "110";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_OR
		REPORT "Test 14 failed: R-type OR" SEVERITY error;

		-- Test 15: R-type AND
		tb_i_opcode <= OP_R_TYPE;
		tb_i_funct3 <= "111";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_AND
		REPORT "Test 15 failed: R-type AND" SEVERITY error;

		-- Test 16: I-type ADDI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "000";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_ADD
		REPORT "Test 16 failed: I-type ADDI" SEVERITY error;

		-- Test 17: I-type SLTI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "010";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLT
		REPORT "Test 17 failed: I-type SLTI" SEVERITY error;

		-- Test 18: I-type SLTIU
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "011";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLTU
		REPORT "Test 18 failed: I-type SLTIU" SEVERITY error;

		-- Test 19: I-type XORI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "100";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_XOR
		REPORT "Test 19 failed: I-type XORI" SEVERITY error;

		-- Test 20: I-type ORI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "110";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_OR
		REPORT "Test 20 failed: I-type ORI" SEVERITY error;

		-- Test 21: I-type ANDI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "111";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_AND
		REPORT "Test 21 failed: I-type ANDI" SEVERITY error;

		-- Test 22: I-type SLLI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "001";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_alu_command = ALU_SLL
		REPORT "Test 22 failed: I-type SLLI" SEVERITY error;

		-- Test 23: I-type SRLI
		tb_i_opcode <= OP_I_TYPE;
		tb_i_funct3 <= "101";
		tb_i_funct7 <= "0000000";
		WAIT FOR CLK_PERIOD; -- Fixed typo: was "0AIT"
		ASSERT tb_o_alu_command = ALU_SRL
		REPORT "Test 23 failed: I-type SRLI" SEVERITY error;

		REPORT "All alu_control tests passed successfully." SEVERITY note;
		WAIT;
	END PROCESS;

END ARCHITECTURE behavioral;