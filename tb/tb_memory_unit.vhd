LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_memory_unit IS
END ENTITY tb_memory_unit;

ARCHITECTURE test OF tb_memory_unit IS

	COMPONENT memory_stage IS
		PORT (
			i_alu_result_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_rs2_data_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pc4_ex : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_funct3_ex : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_mem_read_ex : IN STD_LOGIC;
			i_mem_write_ex : IN STD_LOGIC;
			i_reg_write_ex : IN STD_LOGIC;
			i_wb_src_ex : IN t_WritebackSrc;
			i_rd_addr_ex : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_mem_read_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_addr : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
			o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_en : OUT STD_LOGIC;
			o_mem_byte_en : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			o_final_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_alu_result_mem : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pc4_mem : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_reg_write_mem : OUT STD_LOGIC;
			o_wb_src_mem : OUT t_WritebackSrc;
			o_rd_addr_mem : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT memory_stage;

	SIGNAL tb_alu_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_rs2_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_pc4 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_funct3 : STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL tb_mem_read : STD_LOGIC;
	SIGNAL tb_mem_write : STD_LOGIC;
	SIGNAL tb_reg_write : STD_LOGIC;
	SIGNAL tb_wb_src : t_WritebackSrc;
	SIGNAL tb_rd_addr : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL tb_mem_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_mem_addr : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_mem_write_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_mem_write_en : STD_LOGIC;
	SIGNAL tb_mem_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL tb_final_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_alu_result_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_pc4_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL tb_reg_write_out : STD_LOGIC;
	SIGNAL tb_wb_src_out : t_WritebackSrc;
	SIGNAL tb_rd_addr_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : memory_stage
	PORT MAP(
		i_alu_result_ex => tb_alu_result,
		i_rs2_data_ex => tb_rs2_data,
		i_pc4_ex => tb_pc4,
		i_funct3_ex => tb_funct3,
		i_mem_read_ex => tb_mem_read,
		i_mem_write_ex => tb_mem_write,
		i_reg_write_ex => tb_reg_write,
		i_wb_src_ex => tb_wb_src,
		i_rd_addr_ex => tb_rd_addr,
		i_mem_read_data => tb_mem_read_data,
		o_mem_addr => tb_mem_addr,
		o_mem_write_data => tb_mem_write_data,
		o_mem_write_en => tb_mem_write_en,
		o_mem_byte_en => tb_mem_byte_en,
		o_final_read_data => tb_final_read_data,
		o_alu_result_mem => tb_alu_result_out,
		o_pc4_mem => tb_pc4_out,
		o_reg_write_mem => tb_reg_write_out,
		o_wb_src_mem => tb_wb_src_out,
		o_rd_addr_mem => tb_rd_addr_out
	);

	stimulus_proc : PROCESS
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Memory Unit Testbench";
		REPORT "========================================================";

		tb_pc4 <= x"00001004";
		tb_reg_write <= '1';
		tb_wb_src <= WB_SRC_MEM;
		tb_rd_addr <= "00001";

		-- TEST 1: LW Word Aligned
		tb_alu_result <= x"00001000";
		tb_mem_read_data <= x"DEADBEEF";
		tb_funct3 <= "010";
		tb_mem_read <= '1';
		tb_mem_write <= '0';
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"DEADBEEF" AND tb_mem_addr = x"00001000" THEN
			REPORT "TEST 1 (LW): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (LW): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: LH Lower Half
		tb_alu_result <= x"00001000";
		tb_mem_read_data <= x"ABCD1234";
		tb_funct3 <= "001";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"00001234" THEN
			REPORT "TEST 2 (LH Lower): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (LH Lower): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: LH Upper Half
		tb_alu_result <= x"00001002";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"FFFFABCD" THEN
			REPORT "TEST 3 (LH Upper): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (LH Upper): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: LB Byte 0
		tb_alu_result <= x"00001000";
		tb_mem_read_data <= x"ABCD1234";
		tb_funct3 <= "000";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"00000034" THEN
			REPORT "TEST 4 (LB Byte0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (LB Byte0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: LB Byte 1
		tb_alu_result <= x"00001001";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"00000012" THEN
			REPORT "TEST 5 (LB Byte1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (LB Byte1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: LB Byte 2
		tb_alu_result <= x"00001002";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"FFFFFFCD" THEN
			REPORT "TEST 6 (LB Byte2): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (LB Byte2): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: LBU Unsigned
		tb_alu_result <= x"00001002";
		tb_mem_read_data <= x"ABCD1234";
		tb_funct3 <= "100";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"000000CD" THEN
			REPORT "TEST 7 (LBU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (LBU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: LHU Unsigned
		tb_alu_result <= x"00001000";
		tb_funct3 <= "101";
		WAIT FOR 10 ns;
		IF tb_final_read_data = x"00001234" THEN
			REPORT "TEST 8 (LHU): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (LHU): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: SW Word
		tb_alu_result <= x"00002000";
		tb_rs2_data <= x"12345678";
		tb_funct3 <= "010";
		tb_mem_read <= '0';
		tb_mem_write <= '1';
		WAIT FOR 10 ns;
		IF tb_mem_write_en = '1' AND tb_mem_byte_en = "1111" AND tb_mem_write_data = x"12345678" THEN
			REPORT "TEST 9 (SW): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (SW): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: SH Lower
		tb_alu_result <= x"00002000";
		tb_funct3 <= "001";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "0011" THEN
			REPORT "TEST 10 (SH Lower): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (SH Lower): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 11: SH Upper
		tb_alu_result <= x"00002002";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "1100" THEN
			REPORT "TEST 11 (SH Upper): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 11 (SH Upper): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 12: SB Byte0
		tb_alu_result <= x"00002000";
		tb_funct3 <= "000";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "0001" THEN
			REPORT "TEST 12 (SB Byte0): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 12 (SB Byte0): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 13: SB Byte1
		tb_alu_result <= x"00002001";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "0010" THEN
			REPORT "TEST 13 (SB Byte1): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 13 (SB Byte1): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 14: SB Byte2
		tb_alu_result <= x"00002002";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "0100" THEN
			REPORT "TEST 14 (SB Byte2): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 14 (SB Byte2): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 15: SB Byte3
		tb_alu_result <= x"00002003";
		WAIT FOR 10 ns;
		IF tb_mem_byte_en = "1000" THEN
			REPORT "TEST 15 (SB Byte3): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 15 (SB Byte3): FAIL" SEVERITY error;
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
