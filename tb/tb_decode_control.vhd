LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_decode_control IS
END ENTITY tb_decode_control;

ARCHITECTURE test OF tb_decode_control IS

	COMPONENT decode_control_unit IS
		PORT (
			i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_reg_write : OUT STD_LOGIC;
			o_mem_read : OUT STD_LOGIC;
			o_mem_write : OUT STD_LOGIC;
			o_alu_src_a : OUT t_AluSrc_A;
			o_alu_src_b : OUT t_AluSrc_B;
			o_wb_src : OUT t_WritebackSrc;
			o_pc_src : OUT t_PcSrc;
			o_alu_op_type : OUT t_ExecControl
		);
	END COMPONENT decode_control_unit;

	SIGNAL tb_instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_reg_write : STD_LOGIC;
	SIGNAL tb_mem_read : STD_LOGIC;
	SIGNAL tb_mem_write : STD_LOGIC;
	SIGNAL tb_alu_src_a : t_AluSrc_A;
	SIGNAL tb_alu_src_b : t_AluSrc_B;
	SIGNAL tb_wb_src : t_WritebackSrc;
	SIGNAL tb_pc_src : t_PcSrc;
	SIGNAL tb_alu_op_type : t_ExecControl;
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : decode_control_unit
	PORT MAP(
		i_instruction => tb_instruction,
		o_reg_write => tb_reg_write,
		o_mem_read => tb_mem_read,
		o_mem_write => tb_mem_write,
		o_alu_src_a => tb_alu_src_a,
		o_alu_src_b => tb_alu_src_b,
		o_wb_src => tb_wb_src,
		o_pc_src => tb_pc_src,
		o_alu_op_type => tb_alu_op_type
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Decode Control Unit Testbench";
		REPORT "========================================================";

		-- TEST 1: LUI
		tb_instruction <= x"12345037";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_src_a = ALU_A_ZERO AND tb_alu_src_b = ALU_B_IMM AND tb_alu_op_type = OP_LUI THEN
			REPORT "TEST 1 (LUI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (LUI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: AUIPC
		tb_instruction <= x"12345097";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_src_a = ALU_A_PC AND tb_alu_src_b = ALU_B_IMM AND tb_alu_op_type = OP_AUIPC THEN
			REPORT "TEST 2 (AUIPC): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (AUIPC): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: JAL
		tb_instruction <= x"008000EF";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_pc_src = PC_SRC_JUMP AND tb_wb_src = WB_SRC_PC4 AND tb_alu_op_type = OP_JUMP THEN
			REPORT "TEST 3 (JAL): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (JAL): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: JALR
		tb_instruction <= x"008080E7";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_pc_src = PC_SRC_JUMP AND tb_wb_src = WB_SRC_PC4 AND tb_alu_op_type = OP_JUMP THEN
			REPORT "TEST 4 (JALR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (JALR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: BEQ
		tb_instruction <= x"00208463";
		WAIT FOR 10 ns;
		IF tb_pc_src = PC_SRC_BRANCH AND tb_alu_op_type = OP_BRANCH AND tb_alu_src_b = ALU_B_RS2 THEN
			REPORT "TEST 5 (BEQ): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (BEQ): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: BNE
		tb_instruction <= x"00209463";
		WAIT FOR 10 ns;
		IF tb_pc_src = PC_SRC_BRANCH AND tb_alu_op_type = OP_BRANCH THEN
			REPORT "TEST 6 (BNE): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (BNE): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: LW
		tb_instruction <= x"00412083";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_mem_read = '1' AND tb_wb_src = WB_SRC_MEM AND tb_alu_op_type = OP_LOAD_STORE THEN
			REPORT "TEST 7 (LW): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (LW): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: LB
		tb_instruction <= x"00410083";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_mem_read = '1' AND tb_wb_src = WB_SRC_MEM THEN
			REPORT "TEST 8 (LB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (LB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: SW
		tb_instruction <= x"00112223";
		WAIT FOR 10 ns;
		IF tb_mem_write = '1' AND tb_alu_op_type = OP_LOAD_STORE AND tb_alu_src_b = ALU_B_IMM THEN
			REPORT "TEST 9 (SW): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (SW): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: SB
		tb_instruction <= x"00110123";
		WAIT FOR 10 ns;
		IF tb_mem_write = '1' AND tb_alu_op_type = OP_LOAD_STORE THEN
			REPORT "TEST 10 (SB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (SB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: ADDI
		tb_instruction <= x"00A08093";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_src_b = ALU_B_IMM AND tb_alu_op_type = OP_I_TYPE THEN
			REPORT "TEST 11 (ADDI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (ADDI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: SLTI
		tb_instruction <= x"00A12093";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_op_type = OP_I_TYPE THEN
			REPORT "TEST 12 (SLTI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (SLTI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: XORI
		tb_instruction <= x"00A14093";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_op_type = OP_I_TYPE THEN
			REPORT "TEST 13 (XORI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (XORI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: ADD
		tb_instruction <= x"002080B3";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_src_b = ALU_B_RS2 AND tb_alu_op_type = OP_R_TYPE THEN
			REPORT "TEST 14 (ADD): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (ADD): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: SUB
		tb_instruction <= x"402080B3";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_op_type = OP_R_TYPE THEN
			REPORT "TEST 15 (SUB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (SUB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 16: XOR
		tb_instruction <= x"002141B3";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_alu_op_type = OP_R_TYPE THEN
			REPORT "TEST 16 (XOR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 16 (XOR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 17: Invalid Opcode
		tb_instruction <= x"00000013";
		WAIT FOR 10 ns;
		IF tb_alu_op_type = OP_I_TYPE THEN
			REPORT "TEST 17 (NOP/ADDI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 17 (NOP/ADDI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 18: BLT
		tb_instruction <= x"0020C463";
		WAIT FOR 10 ns;
		IF tb_pc_src = PC_SRC_BRANCH AND tb_alu_op_type = OP_BRANCH THEN
			REPORT "TEST 18 (BLT): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 18 (BLT): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 19: LHU
		tb_instruction <= x"00415083";
		WAIT FOR 10 ns;
		IF tb_reg_write = '1' AND tb_mem_read = '1' THEN
			REPORT "TEST 19 (LHU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 19 (LHU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 20: SH
		tb_instruction <= x"00111123";
		WAIT FOR 10 ns;
		IF tb_mem_write = '1' THEN
			REPORT "TEST 20 (SH): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 20 (SH): FAIL" SEVERITY error;
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
