LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_execution_unit IS
END ENTITY tb_execution_unit;

ARCHITECTURE test OF tb_execution_unit IS

	COMPONENT execution_unit IS
		PORT (
			i_pc : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs1_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs2_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_immediate : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_funct3 : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct7 : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			i_alu_op_type : IN t_ExecControl;
			i_alu_src_a : IN t_AluSrc_A;
			i_alu_src_b : IN t_AluSrc_B;
			i_pc_src : IN t_PcSrc;
			i_mem_read : IN STD_LOGIC;
			i_mem_write : IN STD_LOGIC;
			i_reg_write : IN STD_LOGIC;
			i_wb_src : IN t_WritebackSrc;
			i_rd_addr : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			o_branch_taken : OUT STD_LOGIC;
			o_pc_target_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_alu_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_rs2_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc4 : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_read : OUT STD_LOGIC;
			o_mem_write : OUT STD_LOGIC;
			o_reg_write : OUT STD_LOGIC;
			o_wb_src : OUT t_WritebackSrc;
			o_rd_addr : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT execution_unit;

	SIGNAL tb_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_pc4 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_rs1_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_rs2_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_immediate : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL tb_funct7 : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL tb_alu_op_type : t_ExecControl;
	SIGNAL tb_alu_src_a : t_AluSrc_A;
	SIGNAL tb_alu_src_b : t_AluSrc_B;
	SIGNAL tb_pc_src : t_PcSrc;
	SIGNAL tb_mem_read : STD_LOGIC;
	SIGNAL tb_mem_write : STD_LOGIC;
	SIGNAL tb_reg_write : STD_LOGIC;
	SIGNAL tb_wb_src : t_WritebackSrc;
	SIGNAL tb_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL tb_branch_taken : STD_LOGIC;
	SIGNAL tb_pc_target : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_rs2_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_pc4_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_mem_read_out : STD_LOGIC;
	SIGNAL tb_mem_write_out : STD_LOGIC;
	SIGNAL tb_reg_write_out : STD_LOGIC;
	SIGNAL tb_wb_src_out : t_WritebackSrc;
	SIGNAL tb_rd_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : execution_unit
	PORT MAP(
		i_pc => tb_pc,
		i_pc4 => tb_pc4,
		i_rs1_data => tb_rs1_data,
		i_rs2_data => tb_rs2_data,
		i_immediate => tb_immediate,
		i_funct3 => tb_funct3,
		i_funct7 => tb_funct7,
		i_alu_op_type => tb_alu_op_type,
		i_alu_src_a => tb_alu_src_a,
		i_alu_src_b => tb_alu_src_b,
		i_pc_src => tb_pc_src,
		i_mem_read => tb_mem_read,
		i_mem_write => tb_mem_write,
		i_reg_write => tb_reg_write,
		i_wb_src => tb_wb_src,
		i_rd_addr => tb_rd_addr,
		o_branch_taken => tb_branch_taken,
		o_pc_target_addr => tb_pc_target,
		o_alu_result => tb_alu_result,
		o_rs2_data => tb_rs2_out,
		o_pc4 => tb_pc4_out,
		o_mem_read => tb_mem_read_out,
		o_mem_write => tb_mem_write_out,
		o_reg_write => tb_reg_write_out,
		o_wb_src => tb_wb_src_out,
		o_rd_addr => tb_rd_addr_out
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Execution Unit Testbench";
		REPORT "========================================================";

		-- Initialize
		tb_mem_read <= '0';
		tb_mem_write <= '0';
		tb_reg_write <= '0';
		tb_wb_src <= WB_SRC_ALU;
		tb_rd_addr <= "00001";
		tb_pc_src <= PC_SRC_PC4;

		-- TEST 1: ADD R-Type
		tb_pc <= x"00001000";
		tb_pc4 <= x"00001004";
		tb_rs1_data <= x"0000000A";
		tb_rs2_data <= x"00000014";
		tb_immediate <= x"00000000";
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		tb_alu_op_type <= OP_R_TYPE;
		tb_alu_src_a <= ALU_A_RS1;
		tb_alu_src_b <= ALU_B_RS2;
		WAIT FOR 10 ns;
		IF tb_alu_result = x"0000001E" THEN
			REPORT "TEST 1 (ADD): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (ADD): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: SUB R-Type
		tb_funct7 <= "0100000";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"FFFFFFF6" THEN
			REPORT "TEST 2 (SUB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (SUB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: ADDI I-Type
		tb_immediate <= x"00000064";
		tb_alu_op_type <= OP_I_TYPE;
		tb_alu_src_b <= ALU_B_IMM;
		tb_funct3 <= "000";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"0000006E" THEN
			REPORT "TEST 3 (ADDI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (ADDI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: LUI
		tb_immediate <= x"12345000";
		tb_alu_op_type <= OP_LUI;
		tb_alu_src_a <= ALU_A_ZERO;
		WAIT FOR 10 ns;
		IF tb_alu_result = x"12345000" THEN
			REPORT "TEST 4 (LUI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (LUI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: AUIPC
		tb_pc <= x"00001000";
		tb_immediate <= x"00002000";
		tb_alu_op_type <= OP_AUIPC;
		tb_alu_src_a <= ALU_A_PC;
		WAIT FOR 10 ns;
		IF tb_alu_result = x"00003000" THEN
			REPORT "TEST 5 (AUIPC): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (AUIPC): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: BEQ Taken
		tb_rs1_data <= x"00000010";
		tb_rs2_data <= x"00000010";
		tb_pc <= x"00001000";
		tb_immediate <= x"00000008";
		tb_alu_op_type <= OP_BRANCH;
		tb_alu_src_a <= ALU_A_RS1;
		tb_alu_src_b <= ALU_B_RS2;
		tb_pc_src <= PC_SRC_BRANCH;
		tb_funct3 <= "000";
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' AND tb_pc_target = x"00001008" THEN
			REPORT "TEST 6 (BEQ Taken): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (BEQ Taken): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: BEQ Not Taken
		tb_rs1_data <= x"00000010";
		tb_rs2_data <= x"00000020";
		WAIT FOR 10 ns;
		IF tb_branch_taken = '0' THEN
			REPORT "TEST 7 (BEQ Not): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (BEQ Not): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: BNE Taken
		tb_funct3 <= "001";
		WAIT FOR 10 ns;
		IF tb_branch_taken = '1' THEN
			REPORT "TEST 8 (BNE Taken): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (BNE Taken): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: JAL
		tb_pc <= x"00002000";
		tb_immediate <= x"00000100";
		tb_alu_op_type <= OP_JUMP;
		tb_alu_src_a <= ALU_A_PC;
		tb_alu_src_b <= ALU_B_IMM;
		tb_pc_src <= PC_SRC_JUMP;
		WAIT FOR 10 ns;
		IF tb_pc_target = x"00002100" THEN
			REPORT "TEST 9 (JAL): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (JAL): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;
		-- TEST 10: JALR
		tb_rs1_data <= x"00003000";
		tb_immediate <= x"00000010";
		tb_alu_src_a <= ALU_A_RS1;
		tb_alu_src_b <= ALU_B_IMM;
		WAIT FOR 10 ns;
		IF tb_pc_target = x"00003010" THEN
			REPORT "TEST 10 (JALR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (JALR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: XOR
		tb_rs1_data <= x"AAAAAAAA";
		tb_rs2_data <= x"55555555";
		tb_alu_op_type <= OP_R_TYPE;
		tb_alu_src_b <= ALU_B_RS2;
		tb_funct3 <= "100";
		tb_funct7 <= "0000000";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"FFFFFFFF" THEN
			REPORT "TEST 11 (XOR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (XOR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: OR
		tb_funct3 <= "110";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"FFFFFFFF" THEN
			REPORT "TEST 12 (OR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (OR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: AND
		tb_funct3 <= "111";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"00000000" THEN
			REPORT "TEST 13 (AND): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (AND): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: SLT
		tb_rs1_data <= x"FFFFFFF0";
		tb_rs2_data <= x"00000010";
		tb_funct3 <= "010";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"00000001" THEN
			REPORT "TEST 14 (SLT): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (SLT): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: SLTU
		tb_funct3 <= "011";
		WAIT FOR 10 ns;
		IF tb_alu_result = x"00000000" THEN
			REPORT "TEST 15 (SLTU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (SLTU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		REPORT "========================================================";
		REPORT "PASSED: " & INTEGER'image(test_passed) & "/15";
		REPORT "FAILED: " & INTEGER'image(test_failed) & "/15";
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