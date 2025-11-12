LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_alu_control IS
END ENTITY tb_alu_control;

ARCHITECTURE test OF tb_alu_control IS

	COMPONENT alu_control_unit IS
		PORT (
			i_alu_op_type : IN t_ExecControl;
			i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			o_alu_command : OUT t_AluOpcodes
		);
	END COMPONENT alu_control_unit;

	SIGNAL tb_alu_op_type : t_ExecControl;
	SIGNAL tb_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL tb_funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL tb_alu_command : t_AluOpcodes;
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : alu_control_unit
	PORT MAP(
		i_alu_op_type => tb_alu_op_type,
		i_funct3 => tb_funct3,
		i_funct7 => tb_funct7,
		o_alu_command => tb_alu_command
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU ALU Control Unit Testbench";
		REPORT "========================================================";

		-- TEST 1: LUI
		tb_alu_op_type <= OP_LUI;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_COPY_B THEN
			REPORT "TEST 1 (LUI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (LUI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: AUIPC
		tb_alu_op_type <= OP_AUIPC;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 2 (AUIPC): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (AUIPC): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: Load/Store
		tb_alu_op_type <= OP_LOAD_STORE;
		tb_funct3 <= "010";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 3 (Load/Store): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (Load/Store): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: JAL/JALR
		tb_alu_op_type <= OP_JUMP;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 4 (Jump): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (Jump): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: Branch
		tb_alu_op_type <= OP_BRANCH;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SUB THEN
			REPORT "TEST 5 (Branch): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (Branch): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: ADD R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 6 (ADD R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (ADD R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: SUB R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "000";
		tb_funct7 <= "0100000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SUB THEN
			REPORT "TEST 7 (SUB R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (SUB R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: SLL R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "001";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLL THEN
			REPORT "TEST 8 (SLL R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (SLL R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: SLT R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "010";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLT THEN
			REPORT "TEST 9 (SLT R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (SLT R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: SLTU R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "011";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLTU THEN
			REPORT "TEST 10 (SLTU R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (SLTU R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: XOR R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "100";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_XOR THEN
			REPORT "TEST 11 (XOR R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (XOR R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: SRL R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "101";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SRL THEN
			REPORT "TEST 12 (SRL R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (SRL R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: SRA R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "101";
		tb_funct7 <= "0100000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SRA THEN
			REPORT "TEST 13 (SRA R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (SRA R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: OR R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "110";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_OR THEN
			REPORT "TEST 14 (OR R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (OR R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: AND R-Type
		tb_alu_op_type <= OP_R_TYPE;
		tb_funct3 <= "111";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_AND THEN
			REPORT "TEST 15 (AND R-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (AND R-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 16: ADDI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 16 (ADDI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 16 (ADDI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 17: SLTI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "010";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLT THEN
			REPORT "TEST 17 (SLTI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 17 (SLTI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 18: SLTIU I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "011";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLTU THEN
			REPORT "TEST 18 (SLTIU I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 18 (SLTIU I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 19: XORI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "100";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_XOR THEN
			REPORT "TEST 19 (XORI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 19 (XORI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 20: ORI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "110";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_OR THEN
			REPORT "TEST 20 (ORI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 20 (ORI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 21: ANDI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "111";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_AND THEN
			REPORT "TEST 21 (ANDI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 21 (ANDI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 22: SLLI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "001";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SLL THEN
			REPORT "TEST 22 (SLLI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 22 (SLLI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 23: SRLI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "101";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SRL THEN
			REPORT "TEST 23 (SRLI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 23 (SRLI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 24: SRAI I-Type
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "101";
		tb_funct7 <= "0100000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_SRA THEN
			REPORT "TEST 24 (SRAI I-Type): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 24 (SRAI I-Type): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 25: I-Type No SUB
		tb_alu_op_type <= OP_I_TYPE;
		tb_funct3 <= "000";
		tb_funct7 <= "0100000";
		WAIT FOR 10 ns;
		IF tb_alu_command = ALU_ADD THEN
			REPORT "TEST 25 (I-Type No SUB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 25 (I-Type No SUB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		REPORT "========================================================";
		REPORT "PASSED: " & INTEGER'image(test_passed) & "/25";
		REPORT "FAILED: " & INTEGER'image(test_failed) & "/25";
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