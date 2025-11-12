LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_writeback_unit IS
END ENTITY tb_writeback_unit;

ARCHITECTURE test OF tb_writeback_unit IS

	COMPONENT writeback_unit IS
		PORT (
			i_read_data : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
			i_alu_result : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
			i_pc4 : IN STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
			i_reg_write : IN STD_LOGIC;
			i_wb_src : IN t_WritebackSrc;
			i_rd_addr : IN STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			o_reg_write_en : OUT STD_LOGIC;
			o_rd_addr : OUT STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			o_rd_data : OUT STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0)
		);
	END COMPONENT writeback_unit;

	SIGNAL tb_read_data : STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_alu_result : STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_pc4 : STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_reg_write : STD_LOGIC;
	SIGNAL tb_wb_src : t_WritebackSrc;
	SIGNAL tb_rd_addr : STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_reg_write_en : STD_LOGIC;
	SIGNAL tb_rd_addr_out : STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd_data : STD_LOGIC_VECTOR(REGFILE_DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : writeback_unit
	PORT MAP(
		i_read_data => tb_read_data,
		i_alu_result => tb_alu_result,
		i_pc4 => tb_pc4,
		i_reg_write => tb_reg_write,
		i_wb_src => tb_wb_src,
		i_rd_addr => tb_rd_addr,
		o_reg_write_en => tb_reg_write_en,
		o_rd_addr => tb_rd_addr_out,
		o_rd_data => tb_rd_data
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Writeback Unit Testbench";
		REPORT "========================================================";

		-- TEST 1: ALU Result (ADD)
		tb_alu_result <= x"12345678";
		tb_read_data <= x"DEADBEEF";
		tb_pc4 <= x"00001004";
		tb_reg_write <= '1';
		tb_wb_src <= WB_SRC_ALU;
		tb_rd_addr <= "00101";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"12345678" AND tb_reg_write_en = '1' AND tb_rd_addr_out = "00101" THEN
			REPORT "TEST 1 (ALU ADD): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (ALU ADD): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: ALU Result (SUB)
		tb_alu_result <= x"FFFFFFF0";
		tb_wb_src <= WB_SRC_ALU;
		WAIT FOR 10 ns;
		IF tb_rd_data = x"FFFFFFF0" THEN
			REPORT "TEST 2 (ALU SUB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (ALU SUB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: ALU Result (ADDI)
		tb_alu_result <= x"0000ABCD";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"0000ABCD" THEN
			REPORT "TEST 3 (ALU ADDI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (ALU ADDI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: Memory Read (LW)
		tb_read_data <= x"CAFEBABE";
		tb_wb_src <= WB_SRC_MEM;
		WAIT FOR 10 ns;
		IF tb_rd_data = x"CAFEBABE" THEN
			REPORT "TEST 4 (LW): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (LW): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: Memory Read (LH)
		tb_read_data <= x"00001234";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"00001234" THEN
			REPORT "TEST 5 (LH): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (LH): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: Memory Read (LB)
		tb_read_data <= x"FFFFFF80";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"FFFFFF80" THEN
			REPORT "TEST 6 (LB): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (LB): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: PC+4 (JAL)
		tb_pc4 <= x"00002004";
		tb_wb_src <= WB_SRC_PC4;
		WAIT FOR 10 ns;
		IF tb_rd_data = x"00002004" THEN
			REPORT "TEST 7 (JAL): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (JAL): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: PC+4 (JALR)
		tb_pc4 <= x"00003008";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"00003008" THEN
			REPORT "TEST 8 (JALR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (JALR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: Write Disable
		tb_reg_write <= '0';
		tb_wb_src <= WB_SRC_ALU;
		WAIT FOR 10 ns;
		IF tb_reg_write_en = '0' THEN
			REPORT "TEST 9 (Write Disable): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (Write Disable): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: Register Address Passthrough
		tb_rd_addr <= "11111";
		tb_reg_write <= '1';
		WAIT FOR 10 ns;
		IF tb_rd_addr_out = "11111" THEN
			REPORT "TEST 10 (Addr Passthrough): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (Addr Passthrough): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: ALU XOR
		tb_alu_result <= x"FFFFFFFF";
		tb_wb_src <= WB_SRC_ALU;
		WAIT FOR 10 ns;
		IF tb_rd_data = x"FFFFFFFF" THEN
			REPORT "TEST 11 (ALU XOR): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (ALU XOR): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: ALU LUI
		tb_alu_result <= x"12345000";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"12345000" THEN
			REPORT "TEST 12 (LUI): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (LUI): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: ALU AUIPC
		tb_alu_result <= x"00010000";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"00010000" THEN
			REPORT "TEST 13 (AUIPC): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (AUIPC): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: Memory LHU
		tb_read_data <= x"0000FFFF";
		tb_wb_src <= WB_SRC_MEM;
		WAIT FOR 10 ns;
		IF tb_rd_data = x"0000FFFF" THEN
			REPORT "TEST 14 (LHU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (LHU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: Memory LBU
		tb_read_data <= x"000000FF";
		WAIT FOR 10 ns;
		IF tb_rd_data = x"000000FF" THEN
			REPORT "TEST 15 (LBU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (LBU): FAIL" SEVERITY error;
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