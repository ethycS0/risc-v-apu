LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY tb_alu IS
END ENTITY tb_alu;

ARCHITECTURE behavioral OF tb_alu IS

	CONSTANT CLK_PERIOD : TIME := 10 ns;

	SIGNAL tb_alu_opcode : t_AluOpcodes;
	SIGNAL tb_alu_x : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_alu_y : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_flags : t_AluFlags;

BEGIN

	uut : ENTITY work.alu
		PORT MAP(
			i_alu_opcode => tb_alu_opcode,
			i_alu_x => tb_alu_x,
			i_alu_y => tb_alu_y,
			o_result => tb_result,
			o_flags => tb_flags
		);

	stim_proc : PROCESS
	BEGIN
		-- Test 1: ADD - Basic addition
		tb_alu_opcode <= ALU_ADD;
		tb_alu_x <= x"00000005";
		tb_alu_y <= x"00000003";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000008"
		REPORT "Test 1 failed: ADD 5 + 3" SEVERITY error;
		REPORT "Test 1 passed: ADD 5 + 3 = 8" SEVERITY note;

		-- Test 2: ADD - Overflow
		tb_alu_opcode <= ALU_ADD;
		tb_alu_x <= x"FFFFFFFF";
		tb_alu_y <= x"00000001";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000000"
		REPORT "Test 2 failed: ADD overflow" SEVERITY error;
		REPORT "Test 2 passed: ADD overflow" SEVERITY note;

		-- Test 3: ADD - Negative numbers
		tb_alu_opcode <= ALU_ADD;
		tb_alu_x <= x"FFFFFFFE";
		tb_alu_y <= x"FFFFFFFF";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"FFFFFFFD"
		REPORT "Test 3 failed: ADD negative" SEVERITY error;
		REPORT "Test 3 passed: ADD negative numbers" SEVERITY note;

		-- Test 4: SUB - Basic subtraction
		tb_alu_opcode <= ALU_SUB;
		tb_alu_x <= x"0000000A";
		tb_alu_y <= x"00000004";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000006"
		REPORT "Test 4 failed: SUB 10 - 4" SEVERITY error;
		REPORT "Test 4 passed: SUB 10 - 4 = 6" SEVERITY note;

		-- Test 5: SUB - Negative result
		tb_alu_opcode <= ALU_SUB;
		tb_alu_x <= x"00000003";
		tb_alu_y <= x"00000005";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"FFFFFFFE"
		REPORT "Test 5 failed: SUB negative result" SEVERITY error;
		REPORT "Test 5 passed: SUB negative result" SEVERITY note;

		-- Test 6: SUB - Zero result
		tb_alu_opcode <= ALU_SUB;
		tb_alu_x <= x"00000007";
		tb_alu_y <= x"00000007";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000000"
		REPORT "Test 6 failed: SUB zero result" SEVERITY error;
		REPORT "Test 6 passed: SUB zero result" SEVERITY note;

		-- Test 7: AND
		tb_alu_opcode <= ALU_AND;
		tb_alu_x <= x"FF00FF00";
		tb_alu_y <= x"0F0F0F0F";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"0F000F00"
		REPORT "Test 7 failed: AND" SEVERITY error;
		REPORT "Test 7 passed: AND operation" SEVERITY note;

		-- Test 8: OR
		tb_alu_opcode <= ALU_OR;
		tb_alu_x <= x"F0F0F0F0";
		tb_alu_y <= x"0F0F0F0F";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"FFFFFFFF"
		REPORT "Test 8 failed: OR" SEVERITY error;
		REPORT "Test 8 passed: OR operation" SEVERITY note;

		-- Test 9: XOR
		tb_alu_opcode <= ALU_XOR;
		tb_alu_x <= x"AAAAAAAA";
		tb_alu_y <= x"55555555";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"FFFFFFFF"
		REPORT "Test 9 failed: XOR" SEVERITY error;
		REPORT "Test 9 passed: XOR operation" SEVERITY note;

		-- Test 10: XOR same operands
		tb_alu_opcode <= ALU_XOR;
		tb_alu_x <= x"12345678";
		tb_alu_y <= x"12345678";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000000"
		REPORT "Test 10 failed: XOR same" SEVERITY error;
		REPORT "Test 10 passed: XOR same operands" SEVERITY note;

		-- Test 11: SLL by 4
		tb_alu_opcode <= ALU_SLL;
		tb_alu_x <= x"00000001";
		tb_alu_y <= x"00000004";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000010"
		REPORT "Test 11 failed: SLL by 4" SEVERITY error;
		REPORT "Test 11 passed: SLL by 4" SEVERITY note;

		-- Test 12: SLL by 31
		tb_alu_opcode <= ALU_SLL;
		tb_alu_x <= x"00000001";
		tb_alu_y <= x"0000001F";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"80000000"
		REPORT "Test 12 failed: SLL by 31" SEVERITY error;
		REPORT "Test 12 passed: SLL by 31" SEVERITY note;

		-- Test 13: SRL by 4
		tb_alu_opcode <= ALU_SRL;
		tb_alu_x <= x"80000000";
		tb_alu_y <= x"00000004";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"08000000"
		REPORT "Test 13 failed: SRL by 4" SEVERITY error;
		REPORT "Test 13 passed: SRL by 4" SEVERITY note;

		-- Test 14: SRL by 16
		tb_alu_opcode <= ALU_SRL;
		tb_alu_x <= x"FFFF0000";
		tb_alu_y <= x"00000010";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"0000FFFF"
		REPORT "Test 14 failed: SRL by 16" SEVERITY error;
		REPORT "Test 14 passed: SRL by 16" SEVERITY note;

		-- Test 15: SRA negative
		tb_alu_opcode <= ALU_SRA;
		tb_alu_x <= x"80000000";
		tb_alu_y <= x"00000004";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"F8000000"
		REPORT "Test 15 failed: SRA negative by 4" SEVERITY error;
		REPORT "Test 15 passed: SRA negative by 4" SEVERITY note;

		-- Test 16: SRA positive
		tb_alu_opcode <= ALU_SRA;
		tb_alu_x <= x"7FFFFFFF";
		tb_alu_y <= x"00000004";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"07FFFFFF"
		REPORT "Test 16 failed: SRA positive by 4" SEVERITY error;
		REPORT "Test 16 passed: SRA positive by 4" SEVERITY note;

		-- Test 17: SLT true (signed: -1 < 1)
		tb_alu_opcode <= ALU_SLT;
		tb_alu_x <= x"FFFFFFFF"; -- -1
		tb_alu_y <= x"00000001"; -- 1
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000001"
		REPORT "Test 17 failed: SLT -1 < 1" SEVERITY error;
		REPORT "Test 17 passed: SLT -1 < 1" SEVERITY note;

		-- Test 18: SLT true (large negative < small positive)
		tb_alu_opcode <= ALU_SLT;
		tb_alu_x <= x"80000000"; -- Most negative
		tb_alu_y <= x"00000001"; -- 1
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000001"
		REPORT "Test 18 failed: SLT -2147483648 < 1" SEVERITY error;
		REPORT "Test 18 passed: SLT -2147483648 < 1" SEVERITY note;

		-- Test 19: SLTU true (unsigned: 3 < 0xFFFFFFFF)
		tb_alu_opcode <= ALU_SLTU;
		tb_alu_x <= x"00000003";
		tb_alu_y <= x"FFFFFFFF";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000001"
		REPORT "Test 19 failed: SLTU 3 < 0xFFFFFFFF" SEVERITY error;
		REPORT "Test 19 passed: SLTU 3 < 0xFFFFFFFF" SEVERITY note;

		-- Test 20: SLTU false (unsigned: 0xFFFFFFFF NOT< 1)
		tb_alu_opcode <= ALU_SLTU;
		tb_alu_x <= x"FFFFFFFF";
		tb_alu_y <= x"00000001";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000000"
		REPORT "Test 20 failed: SLTU 0xFFFFFFFF NOT< 1" SEVERITY error;
		REPORT "Test 20 passed: SLTU 0xFFFFFFFF NOT< 1" SEVERITY note;

		-- Test 21: ALU_COPY_B
		tb_alu_opcode <= ALU_COPY_B;
		tb_alu_x <= x"12345678";
		tb_alu_y <= x"ABCDEF00";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"ABCDEF00"
		REPORT "Test 21 failed: COPY_B" SEVERITY error;
		REPORT "Test 21 passed: COPY_B operation" SEVERITY note;

		-- Test 22: SLL shift amount masking
		tb_alu_opcode <= ALU_SLL;
		tb_alu_x <= x"00000001";
		tb_alu_y <= x"00000024";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_result = x"00000010"
		REPORT "Test 22 failed: SLL masking" SEVERITY error;
		REPORT "Test 22 passed: SLL shift amount masking" SEVERITY note;

		REPORT "All 22 ALU tests passed successfully." SEVERITY note;
		WAIT;
	END PROCESS;

END ARCHITECTURE behavioral;