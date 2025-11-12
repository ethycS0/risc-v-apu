LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_branch_adder IS
END ENTITY tb_branch_adder;

ARCHITECTURE behavioral OF tb_branch_adder IS

	CONSTANT CLK_PERIOD : TIME := 10 ns;

	SIGNAL tb_i_pc : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_i_imm : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tb_o_branch_address : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN

	uut : ENTITY work.branch_adder
		PORT MAP(
			i_pc => tb_i_pc,
			i_imm => tb_i_imm,
			o_branch_address => tb_o_branch_address
		);

	stim_proc : PROCESS
	BEGIN
		-- Test 1: Zero offset (branch to same address as PC)
		tb_i_pc <= x"00000100";
		tb_i_imm <= x"00000000";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000100"
		REPORT "Test 1 failed: Zero offset" SEVERITY error;

		-- Test 2: Positive offset (forward branch)
		-- Branch offset +12 bytes for BEQ-like instruction
		tb_i_pc <= x"00000100";
		tb_i_imm <= x"0000000C";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"0000010C"
		REPORT "Test 2 failed: Forward branch +12" SEVERITY error;

		-- Test 3: Negative offset (backward branch)
		-- Branch offset -8 bytes for loop branch
		tb_i_pc <= x"00000100";
		tb_i_imm <= x"FFFFFFF8"; -- -8 in two's complement
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"000000F8"
		REPORT "Test 3 failed: Backward branch -8" SEVERITY error;

		-- Test 4: Large positive offset
		-- JAL can target ±1 MiB range
		tb_i_pc <= x"00000100";
		tb_i_imm <= x"00000400"; -- +1024 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000500"
		REPORT "Test 4 failed: Large forward branch" SEVERITY error;

		-- Test 5: Large negative offset
		tb_i_pc <= x"00001000";
		tb_i_imm <= x"FFFFF000"; -- -4096 in two's complement
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000000"
		REPORT "Test 5 failed: Large backward branch" SEVERITY error;

		-- Test 6: Branch instruction offset encoding
		-- B-type immediate is in multiples of 2
		-- Simulating BEQ with offset = 8 (encoded as imm=8)
		tb_i_pc <= x"00001000";
		tb_i_imm <= x"00000008";
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00001008"
		REPORT "Test 6 failed: B-type branch" SEVERITY error;

		-- Test 7: JAL instruction offset encoding
		-- J-type offset to target PC + 2048
		tb_i_pc <= x"00002000";
		tb_i_imm <= x"00000800"; -- +2048 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00002800"
		REPORT "Test 7 failed: J-type jump" SEVERITY error;

		-- Test 8: Boundary condition - Max positive immediate (20-bit)
		tb_i_pc <= x"00000000";
		tb_i_imm <= x"000FFFFF"; -- Max 20-bit positive
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"000FFFFF"
		REPORT "Test 8 failed: Maximum positive offset" SEVERITY error;

		-- Test 9: Sign extension test
		-- Negative offset with sign extension
		tb_i_pc <= x"00010000";
		tb_i_imm <= x"FFFF0000"; -- -65536
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000000"
		REPORT "Test 9 failed: Sign extension" SEVERITY error;

		-- Test 10: PC alignment check (must be 4-byte boundary in RV32I)
		tb_i_pc <= x"00001004"; -- PC at aligned boundary
		tb_i_imm <= x"00000010"; -- +16 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00001014"
		REPORT "Test 10 failed: PC alignment" SEVERITY error;

		-- Test 11: JALR-style offset (I-type immediate range)
		-- JALR uses 12-bit signed immediate
		tb_i_pc <= x"00001000";
		tb_i_imm <= x"000007FF"; -- Max positive 12-bit immediate
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"000017FF"
		REPORT "Test 11 failed: JALR max positive offset" SEVERITY error;

		-- Test 12: JALR negative offset
		tb_i_pc <= x"00001000";
		tb_i_imm <= x"FFFFF800"; -- Min negative 12-bit immediate (-2048)
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000800"
		REPORT "Test 12 failed: JALR negative offset" SEVERITY error;

		-- Test 13: Edge case - wrapping around 32-bit boundary (overflow)
		tb_i_pc <= x"FFFFFFF0";
		tb_i_imm <= x"00000020"; -- +32 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000010"
		REPORT "Test 13 failed: 32-bit overflow wrap" SEVERITY error;

		-- Test 14: Edge case - underflow (wrapping backward)
		tb_i_pc <= x"00000010";
		tb_i_imm <= x"FFFFFFE0"; -- -32 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"FFFFFFF0"
		REPORT "Test 14 failed: 32-bit underflow wrap" SEVERITY error;

		-- Test 15: BNE backward branch (common loop pattern)
		tb_i_pc <= x"00000080";
		tb_i_imm <= x"FFFFFFFC"; -- -4 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"0000007C"
		REPORT "Test 15 failed: Loop backward branch -4" SEVERITY error;

		-- Test 16: Branch to immediate next instruction
		tb_i_pc <= x"00000100";
		tb_i_imm <= x"00000004"; -- +4 bytes (next instruction)
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000104"
		REPORT "Test 16 failed: Branch to next instruction" SEVERITY error;

		-- Test 17: Maximum B-type range forward (+4094)
		tb_i_pc <= x"00000000";
		tb_i_imm <= x"00000FFE"; -- +4094 bytes (max B-type)
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000FFE"
		REPORT "Test 17 failed: Max B-type forward branch" SEVERITY error;

		-- Test 18: Maximum B-type range backward (-4096)
		tb_i_pc <= x"00002000";
		tb_i_imm <= x"FFFFF000"; -- -4096 bytes (min B-type)
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00001000"
		REPORT "Test 18 failed: Max B-type backward branch" SEVERITY error;

		-- Test 19: JAL max forward range (~1 MB)
		tb_i_pc <= x"00000000";
		tb_i_imm <= x"000FFFFE"; -- +1,048,574 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"000FFFFE"
		REPORT "Test 19 failed: JAL max forward" SEVERITY error;

		-- Test 20: JAL max backward range (~-1 MB)
		tb_i_pc <= x"00100000";
		tb_i_imm <= x"FFF00000"; -- -1,048,576 bytes
		WAIT FOR CLK_PERIOD;
		ASSERT tb_o_branch_address = x"00000000"
		REPORT "Test 20 failed: JAL max backward" SEVERITY error;

		REPORT "All branch_adder tests passed successfully." SEVERITY note;
		WAIT;
	END PROCESS;

END ARCHITECTURE behavioral;

