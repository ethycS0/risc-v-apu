LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY tb_register_file IS
END ENTITY tb_register_file;

ARCHITECTURE test OF tb_register_file IS

	CONSTANT CLK_PERIOD : TIME := 10 ns;
	CONSTANT DATA_WIDTH : INTEGER := 32;
	CONSTANT ADDR_WIDTH : INTEGER := 5;

	COMPONENT register_file IS
		PORT (
			i_clk : IN STD_LOGIC;
			i_rst : IN STD_LOGIC;
			i_wr_en : IN STD_LOGIC;
			i_wr_addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
			i_wr_data : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
			i_rd1_addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
			o_rd1_data : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
			i_rd2_addr : IN STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
			o_rd2_data : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0)
		);
	END COMPONENT register_file;

	SIGNAL tb_clk : STD_LOGIC := '0';
	SIGNAL tb_rst : STD_LOGIC;
	SIGNAL tb_wr_en : STD_LOGIC;
	SIGNAL tb_wr_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_wr_data : STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd1_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd1_data : STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd2_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd2_data : STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);

	SIGNAL stop_sim : BOOLEAN := false;
	SIGNAL test_passed : INTEGER := 0;
	SIGNAL test_failed : INTEGER := 0;

BEGIN

	dut_inst : register_file
	PORT MAP(
		i_clk => tb_clk,
		i_rst => tb_rst,
		i_wr_en => tb_wr_en,
		i_wr_addr => tb_wr_addr,
		i_wr_data => tb_wr_data,
		i_rd1_addr => tb_rd1_addr,
		o_rd1_data => tb_rd1_data,
		i_rd2_addr => tb_rd2_addr,
		o_rd2_data => tb_rd2_data
	);

	clk_gen_proc : PROCESS
	BEGIN
		WHILE NOT stop_sim LOOP
			tb_clk <= '0';
			WAIT FOR CLK_PERIOD / 2;
			tb_clk <= '1';
			WAIT FOR CLK_PERIOD / 2;
		END LOOP;
		WAIT;
	END PROCESS clk_gen_proc;

	stimulus_proc : PROCESS
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V RV32I Register File Testbench";
		REPORT "========================================================";

		-- Initialize
		tb_rst <= '1';
		tb_wr_en <= '0';
		tb_wr_addr <= (OTHERS => '0');
		tb_wr_data <= (OTHERS => '0');
		tb_rd1_addr <= (OTHERS => '0');
		tb_rd2_addr <= (OTHERS => '0');
		WAIT FOR CLK_PERIOD * 2;
		tb_rst <= '0';
		WAIT FOR CLK_PERIOD;

		-- ====================================================================
		-- TEST 1: x0 Hardwired Zero
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "00000";
		tb_wr_data <= x"DEADBEEF";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "00000";
		tb_rd2_addr <= "00000";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"00000000" AND tb_rd2_data = x"00000000" THEN
			REPORT "TEST 1 (x0 Zero): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 1 (x0 Zero): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 2: All Registers
		-- ====================================================================
		FOR i IN 1 TO 31 LOOP
			tb_wr_en <= '1';
			tb_wr_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			tb_wr_data <= STD_LOGIC_VECTOR(to_unsigned(i * 256, DATA_WIDTH));
			WAIT FOR CLK_PERIOD;

			tb_wr_en <= '0';
			tb_rd1_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			WAIT FOR CLK_PERIOD;

			IF tb_rd1_data /= STD_LOGIC_VECTOR(to_unsigned(i * 256, DATA_WIDTH)) THEN
				REPORT "TEST 2 (All Regs): FAIL" SEVERITY error;
				test_failed <= test_failed + 1;
			END IF;
		END LOOP;
		REPORT "TEST 2 (All Regs): PASS";
		test_passed <= test_passed + 1;

		-- ====================================================================
		-- TEST 3: Dual Port
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "00101";
		tb_wr_data <= x"12345678";
		WAIT FOR CLK_PERIOD;

		tb_wr_addr <= "01111";
		tb_wr_data <= x"ABCDEF01";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "00101";
		tb_rd2_addr <= "01111";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"12345678" AND tb_rd2_data = x"ABCDEF01" THEN
			REPORT "TEST 3 (Dual Port): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 3 (Dual Port): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 4: Same Register
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "10000";
		tb_wr_data <= x"FEDCBA98";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "10000";
		tb_rd2_addr <= "10000";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"FEDCBA98" AND tb_rd2_data = x"FEDCBA98" THEN
			REPORT "TEST 4 (Same Reg): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 4 (Same Reg): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 5: Write Enable
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "01010";
		tb_wr_data <= x"11111111";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_wr_addr <= "01010";
		tb_wr_data <= x"22222222";
		WAIT FOR CLK_PERIOD;

		tb_rd1_addr <= "01010";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"11111111" THEN
			REPORT "TEST 5 (Write Enable): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 5 (Write Enable): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 6: Overwrite
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "10100";
		tb_wr_data <= x"AAAAAAAA";
		WAIT FOR CLK_PERIOD;

		tb_wr_addr <= "10100";
		tb_wr_data <= x"55555555";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "10100";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"55555555" THEN
			REPORT "TEST 6 (Overwrite): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 6 (Overwrite): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 7: Reset
		-- ====================================================================
		tb_wr_en <= '1';
		FOR i IN 1 TO 10 LOOP
			tb_wr_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			tb_wr_data <= x"FFFFFFFF";
			WAIT FOR CLK_PERIOD;
		END LOOP;

		tb_wr_en <= '0';
		tb_rst <= '1';
		WAIT FOR CLK_PERIOD * 2;
		tb_rst <= '0';
		WAIT FOR CLK_PERIOD;

		FOR i IN 0 TO 10 LOOP
			tb_rd1_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			WAIT FOR CLK_PERIOD;

			IF tb_rd1_data /= x"00000000" THEN
				REPORT "TEST 7 (Reset): FAIL" SEVERITY error;
				test_failed <= test_failed + 1;
			END IF;
		END LOOP;
		REPORT "TEST 7 (Reset): PASS";
		test_passed <= test_passed + 1;

		-- ====================================================================
		-- TEST 8: Boundary Values
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "00001";
		tb_wr_data <= x"00000000";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "00001";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data /= x"00000000" THEN
			REPORT "TEST 8 (Boundary): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		tb_wr_en <= '1';
		tb_wr_addr <= "11111";
		tb_wr_data <= x"FFFFFFFF";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "11111";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"FFFFFFFF" THEN
			REPORT "TEST 8 (Boundary): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 8 (Boundary): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 9: Timing
		-- ====================================================================
		tb_wr_en <= '1';
		tb_wr_addr <= "00111";
		tb_wr_data <= x"CAFE0000";
		WAIT FOR CLK_PERIOD;

		tb_wr_addr <= "00111";
		tb_wr_data <= x"CAFEBABE";
		tb_rd1_addr <= "00111";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= "00111";
		WAIT FOR CLK_PERIOD;

		IF tb_rd1_data = x"CAFEBABE" THEN
			REPORT "TEST 9 (Timing): PASS";
			test_passed <= test_passed + 1;
		ELSE
			REPORT "TEST 9 (Timing): FAIL" SEVERITY error;
			test_failed <= test_failed + 1;
		END IF;

		-- ====================================================================
		-- TEST 10: Sequential
		-- ====================================================================
		tb_wr_en <= '1';
		FOR i IN 1 TO 31 LOOP
			tb_wr_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			tb_wr_data <= STD_LOGIC_VECTOR(to_unsigned(i * 1000, DATA_WIDTH));
			WAIT FOR CLK_PERIOD;
		END LOOP;

		tb_wr_en <= '0';
		FOR i IN 1 TO 31 LOOP
			tb_rd1_addr <= STD_LOGIC_VECTOR(to_unsigned(i, ADDR_WIDTH));
			WAIT FOR CLK_PERIOD;

			IF tb_rd1_data /= STD_LOGIC_VECTOR(to_unsigned(i * 1000, DATA_WIDTH)) THEN
				REPORT "TEST 10 (Sequential): FAIL" SEVERITY error;
				test_failed <= test_failed + 1;
			END IF;
		END LOOP;
		REPORT "TEST 10 (Sequential): PASS";
		test_passed <= test_passed + 1;

		-- ====================================================================
		-- Summary
		-- ====================================================================
		REPORT "========================================================";
		REPORT "PASSED: " & INTEGER'image(test_passed) & "/10";
		REPORT "FAILED: " & INTEGER'image(test_failed) & "/10";
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