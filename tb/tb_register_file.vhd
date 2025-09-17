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
			clk : IN std_logic;
			rst : IN std_logic;
			wr_en : IN std_logic;

			wr_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
			wr_data : IN std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);

			rd1_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
			rd1_data : OUT std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);

			rd2_addr : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
			rd2_data : OUT std_logic_vector(DATA_WIDTH - 1 DOWNTO 0)
		);
	END COMPONENT register_file;

	SIGNAL tb_clk : std_logic := '0';
	SIGNAL tb_rst : std_logic;
	SIGNAL tb_wr_en : std_logic;
	SIGNAL tb_wr_addr : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_wr_data : std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd1_addr : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd1_data : std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd2_addr : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_rd2_data : std_logic_vector(DATA_WIDTH - 1 DOWNTO 0);

	SIGNAL stop_sim : BOOLEAN := false;
 
BEGIN
	dut_inst : register_file
	PORT MAP(
		clk => tb_clk, 
		rst => tb_rst, 
		wr_en => tb_wr_en, 
		wr_addr => tb_wr_addr, 
		wr_data => tb_wr_data, 
		rd1_addr => tb_rd1_addr, 
		rd1_data => tb_rd1_data, 
		rd2_addr => tb_rd2_addr, 
		rd2_data => tb_rd2_data
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
		REPORT "INFO: Starting REGISTER FILE Testbench...";

		tb_rst <= '1';
		tb_wr_en <= '0';
		WAIT FOR CLK_PERIOD * 2;
		tb_rst <= '0';
		WAIT FOR CLK_PERIOD;
 
		REPORT "TEST: Write TO x10 AND x20";
		tb_wr_en <= '1';
		tb_wr_addr <= std_logic_vector(to_unsigned(10, ADDR_WIDTH));
		tb_wr_data <= x"AAAAAAAA";
		WAIT FOR CLK_PERIOD;

		tb_wr_addr <= std_logic_vector(to_unsigned(20, ADDR_WIDTH));
		tb_wr_data <= x"BBBBBBBB";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= std_logic_vector(to_unsigned(10, ADDR_WIDTH));
		tb_rd2_addr <= std_logic_vector(to_unsigned(20, ADDR_WIDTH));
		WAIT FOR CLK_PERIOD / 4;

		ASSERT tb_rd1_data = x"AAAAAAAA" REPORT "FAILURE: Read from x10 failed." SEVERITY error;
		ASSERT tb_rd2_data = x"BBBBBBBB" REPORT "FAILURE: Read from x20 failed." SEVERITY error;
		REPORT "SUCCESS: Read from x10 AND x20 correct.";
		WAIT FOR CLK_PERIOD;

		REPORT "TEST: Attempt TO write TO x0";
		tb_wr_en <= '1';
		tb_wr_addr <= (OTHERS => '0');
		tb_wr_data <= x"DEADBEEF";
		WAIT FOR CLK_PERIOD;

		tb_wr_en <= '0';
		tb_rd1_addr <= (OTHERS => '0');
		WAIT FOR CLK_PERIOD / 4;

		ASSERT tb_rd1_data = x"00000000" REPORT "FAILURE: x0 was NOT zero!" SEVERITY error;
		REPORT "SUCCESS: x0 remained zero as expected.";
		WAIT FOR CLK_PERIOD;

		REPORT "INFO: ALL tests passed. Simulation finished.";
		stop_sim <= true;
		WAIT;
	END PROCESS stimulus_proc;

END ARCHITECTURE test;
