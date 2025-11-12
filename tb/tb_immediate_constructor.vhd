LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_immediate_constructor IS
END ENTITY tb_immediate_constructor;

ARCHITECTURE test OF tb_immediate_constructor IS

	COMPONENT immediate_constructor_unit IS
		PORT (
			i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_immediate : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT immediate_constructor_unit;

	SIGNAL tb_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_immediate : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : immediate_constructor_unit
	PORT MAP(
		i_instruction => tb_instruction,
		o_immediate => tb_immediate
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Immediate Constructor Testbench";
		REPORT "========================================================";

		-- TEST 1: LUI Positive
		tb_instruction <= x"12345037";
		WAIT FOR 10 ns;
		IF tb_immediate = x"12345000" THEN
			REPORT "TEST 1 (LUI Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (LUI Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: LUI Negative
		tb_instruction <= x"FFFFF037";
		WAIT FOR 10 ns;
		IF tb_immediate = x"FFFFF000" THEN
			REPORT "TEST 2 (LUI Neg): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (LUI Neg): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: AUIPC Positive
		tb_instruction <= x"00001097";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00001000" THEN
			REPORT "TEST 3 (AUIPC Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (AUIPC Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: AUIPC Zero
		tb_instruction <= x"00000097";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000000" THEN
			REPORT "TEST 4 (AUIPC Zero): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (AUIPC Zero): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: ADDI Positive
		tb_instruction <= x"00A08093";
		WAIT FOR 10 ns;
		IF tb_immediate = x"0000000A" THEN
			REPORT "TEST 5 (ADDI Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (ADDI Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: ADDI Negative
		tb_instruction <= x"FF608093";
		WAIT FOR 10 ns;
		IF tb_immediate = x"FFFFFFF6" THEN
			REPORT "TEST 6 (ADDI Neg): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (ADDI Neg): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: ADDI Max Positive
		tb_instruction <= x"7FF08093";
		WAIT FOR 10 ns;
		IF tb_immediate = x"000007FF" THEN
			REPORT "TEST 7 (ADDI Max): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (ADDI Max): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: ADDI Max Negative
		tb_instruction <= x"80008093";
		WAIT FOR 10 ns;
		IF tb_immediate = x"FFFFF800" THEN
			REPORT "TEST 8 (ADDI Min): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (ADDI Min): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: LW Positive Offset
		tb_instruction <= x"00412083";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000004" THEN
			REPORT "TEST 9 (LW Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (LW Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: LW Negative Offset
		tb_instruction <= x"FFC12083";
		WAIT FOR 10 ns;
		IF tb_immediate = x"FFFFFFFC" THEN
			REPORT "TEST 10 (LW Neg): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (LW Neg): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: JALR Positive
		tb_instruction <= x"008080E7";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000008" THEN
			REPORT "TEST 11 (JALR Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (JALR Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: JALR Zero
		tb_instruction <= x"000080E7";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000000" THEN
			REPORT "TEST 12 (JALR Zero): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (JALR Zero): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: SW Positive
		tb_instruction <= x"00112223";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000004" THEN
			REPORT "TEST 13 (SW Pos): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (SW Pos): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: SW Negative
		tb_instruction <= x"FE112E23";
		WAIT FOR 10 ns;
		IF tb_immediate = x"FFFFFFFC" THEN
			REPORT "TEST 14 (SW Neg): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (SW Neg): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: SW Zero
		tb_instruction <= x"00002023";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000000" THEN
			REPORT "TEST 15 (SW Zero): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (SW Zero): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 16: SB (Store Byte)
		tb_instruction <= x"00208123";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000002" THEN
			REPORT "TEST 16 (SB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 16 (SB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 17: LBU (Load Byte Unsigned)
		tb_instruction <= x"00314103";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000003" THEN
			REPORT "TEST 17 (LBU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 17 (LBU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 18: ADD (R-Type)
		tb_instruction <= x"002080B3";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000000" THEN
			REPORT "TEST 18 (ADD R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 18 (ADD R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 19: XOR (R-Type)
		tb_instruction <= x"002141B3";
		WAIT FOR 10 ns;
		IF tb_immediate = x"00000000" THEN
			REPORT "TEST 19 (XOR R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 19 (XOR R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 20: XORI (I-Type ALU)
		tb_instruction <= x"00F14113";
		WAIT FOR 10 ns;
		IF tb_immediate = x"0000000F" THEN
			REPORT "TEST 20 (XORI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 20 (XORI): FAIL" SEVERITY error;
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