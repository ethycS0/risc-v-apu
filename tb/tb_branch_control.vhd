LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_branch_control IS
END ENTITY tb_branch_control;

ARCHITECTURE test OF tb_branch_control IS

	COMPONENT branch_condition_unit IS
		PORT (
			i_flags : IN t_AluFlags;
			i_funct3 : IN std_logic_vector(2 DOWNTO 0);
			i_branch_active : IN std_logic;
			o_branch_taken : OUT std_logic
		);
	END COMPONENT branch_condition_unit;

	SIGNAL tb_flags : t_AluFlags;
	SIGNAL tb_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL tb_branch_active : STD_LOGIC;
	SIGNAL tb_branch_taken : STD_LOGIC;
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : branch_condition_unit
	PORT MAP(
		i_flags => tb_flags,
		i_funct3 => tb_funct3,
		i_branch_active => tb_branch_active,
		o_branch_taken => tb_branch_taken
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Branch Control Testbench";
		REPORT "========================================================";

		-- TEST 1: Branch Inactive
		tb_branch_active <= '0';
		tb_funct3 <= "000";
		tb_flags.zero <= '1';
		tb_flags.negative <= '0';
		tb_flags.overflow <= '0';
		tb_flags.carry <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 1 (Inactive): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (Inactive): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		tb_branch_active <= '1';

		-- TEST 2: BEQ Taken
		tb_funct3 <= "000";
		tb_flags.zero <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 2 (BEQ Taken): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (BEQ Taken): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: BEQ Not Taken
		tb_funct3 <= "000";
		tb_flags.zero <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 3 (BEQ Not): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (BEQ Not): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: BNE Taken
		tb_funct3 <= "001";
		tb_flags.zero <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 4 (BNE Taken): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (BNE Taken): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: BNE Not Taken
		tb_funct3 <= "001";
		tb_flags.zero <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 5 (BNE Not): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (BNE Not): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: BLT N=1 V=0
		tb_funct3 <= "100";
		tb_flags.negative <= '1';
		tb_flags.overflow <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 6 (BLT N=1 V=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (BLT N=1 V=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: BLT N=0 V=1
		tb_funct3 <= "100";
		tb_flags.negative <= '0';
		tb_flags.overflow <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 7 (BLT N=0 V=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (BLT N=0 V=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: BLT N=0 V=0
		tb_funct3 <= "100";
		tb_flags.negative <= '0';
		tb_flags.overflow <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 8 (BLT N=0 V=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (BLT N=0 V=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: BLT N=1 V=1
		tb_funct3 <= "100";
		tb_flags.negative <= '1';
		tb_flags.overflow <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 9 (BLT N=1 V=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (BLT N=1 V=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: BGE N=0 V=0
		tb_funct3 <= "101";
		tb_flags.negative <= '0';
		tb_flags.overflow <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 10 (BGE N=0 V=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (BGE N=0 V=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: BGE N=1 V=1
		tb_funct3 <= "101";
		tb_flags.negative <= '1';
		tb_flags.overflow <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 11 (BGE N=1 V=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (BGE N=1 V=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: BGE N=1 V=0
		tb_funct3 <= "101";
		tb_flags.negative <= '1';
		tb_flags.overflow <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 12 (BGE N=1 V=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (BGE N=1 V=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: BGE N=0 V=1
		tb_funct3 <= "101";
		tb_flags.negative <= '0';
		tb_flags.overflow <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 13 (BGE N=0 V=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (BGE N=0 V=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: BLTU C=0
		tb_funct3 <= "110";
		tb_flags.carry <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 14 (BLTU C=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (BLTU C=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: BLTU C=1
		tb_funct3 <= "110";
		tb_flags.carry <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 15 (BLTU C=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (BLTU C=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 16: BGEU C=1
		tb_funct3 <= "111";
		tb_flags.carry <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 16 (BGEU C=1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 16 (BGEU C=1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 17: BGEU C=0
		tb_funct3 <= "111";
		tb_flags.carry <= '0';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 17 (BGEU C=0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 17 (BGEU C=0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 18: Invalid 010
		tb_funct3 <= "010";
		tb_flags.zero <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 18 (Invalid 010): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 18 (Invalid 010): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 19: Invalid 011
		tb_funct3 <= "011";
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 19 (Invalid 011): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 19 (Invalid 011): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 20: BEQ All Flags
		tb_funct3 <= "000";
		tb_flags.zero <= '1';
		tb_flags.negative <= '1';
		tb_flags.overflow <= '1';
		tb_flags.carry <= '1';
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 20 (BEQ All Flags): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 20 (BEQ All Flags): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		REPORT "========================================================";
		REPORT "PASSED: " & INTEGER'image(test_passed) & "/20";
		REPORT "FAILED: " & INTEGER'image(test_failed) & "/20";
		IF test_failed = 0 THEN
			REPORT "ALL TESTS PASSED";
		ELSE
			REPORT "SOME TESTS FAILED" SEVERITY error;
		END IF;
		REPORT "========================================================";

		stop_sim <= true;
		WAIT;
	END PROCESS stimulus_proc;

END ARCHITECTURE test;
