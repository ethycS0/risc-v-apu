LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;
USE std.textio.ALL;

ENTITY tb_instruction_fetch IS
END ENTITY tb_instruction_fetch;

ARCHITECTURE test OF tb_instruction_fetch IS

	CONSTANT CLK_PERIOD : TIME := 10 ns;
	CONSTANT MEMORY_ADDR_WIDTH : INTEGER := 32;
	CONSTANT INSTRUCTION_WIDTH : INTEGER := 32;
	CONSTANT RESET_ADDRESS : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000";

	COMPONENT instruction_fetch_unit IS
		PORT (
			clk : IN STD_LOGIC;
			rst : IN STD_LOGIC;
			stall : IN STD_LOGIC;
			i_pc_src : IN t_PcSrc;
			i_branch_addr : IN STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
			i_jump_addr : IN STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
			o_instr_addr : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
			i_instr_data : IN STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);
			o_instruction : OUT STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);
			o_pc : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
			o_pc_plus_4 : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0)
		);
	END COMPONENT instruction_fetch_unit;

	SIGNAL tb_clk : STD_LOGIC := '0';
	SIGNAL tb_rst : STD_LOGIC;
	SIGNAL tb_stall : STD_LOGIC;
	SIGNAL tb_pc_src : t_PcSrc;
	SIGNAL tb_branch_addr : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_jump_addr : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_instr_addr : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_instr_data : STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_instruction : STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_pc : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL tb_pc_plus_4 : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);

	SIGNAL stop_sim : BOOLEAN := false;

BEGIN

	dut_inst : instruction_fetch_unit
	PORT MAP(
		clk => tb_clk,
		rst => tb_rst,
		stall => tb_stall,
		i_pc_src => tb_pc_src,
		i_branch_addr => tb_branch_addr,
		i_jump_addr => tb_jump_addr,
		o_instr_addr => tb_instr_addr,
		i_instr_data => tb_instr_data,
		o_instruction => tb_instruction,
		o_pc => tb_pc,
		o_pc_plus_4 => tb_pc_plus_4
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
		VARIABLE test_passed : INTEGER := 0;
		VARIABLE test_failed : INTEGER := 0;
	BEGIN
		REPORT "========================================================";
		REPORT "RISC-V APU Instruction Fetch Unit Testbench";
		REPORT "========================================================";

		tb_rst <= '1';
		tb_stall <= '0';
		tb_pc_src <= PC_SRC_PC4;
		tb_branch_addr <= (OTHERS => '0');
		tb_jump_addr <= (OTHERS => '0');
		tb_instr_data <= x"00000000";
		WAIT FOR CLK_PERIOD * 2;

		tb_rst <= '0';
		WAIT FOR CLK_PERIOD / 2;

		-- TEST 1: Reset PC
		IF tb_pc = RESET_ADDRESS THEN
			REPORT "TEST 1 (Reset PC): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 1 (Reset PC): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 2: PC+4 Adder
		IF tb_pc_plus_4 = x"00000004" THEN
			REPORT "TEST 2 (PC+4 Adder): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 2 (PC+4 Adder): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 3: PC Increment
		tb_instr_data <= x"12345678";
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00000004" THEN
			REPORT "TEST 3 (PC Increment): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 3 (PC Increment): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 4: Instruction
		IF tb_instruction = x"12345678" THEN
			REPORT "TEST 4 (Instruction): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 4 (Instruction): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 5: Sequential
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00000008" THEN
			REPORT "TEST 5 (Sequential): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 5 (Sequential): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 6: Branch - SET BEFORE CLOCK
		tb_pc_src <= PC_SRC_BRANCH;
		tb_branch_addr <= x"00001000";
		WAIT FOR 1 ns; -- Let signals propagate
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00001000" THEN
			REPORT "TEST 6 (Branch): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 6 (Branch): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 7: Jump - SET BEFORE CLOCK
		tb_pc_src <= PC_SRC_JUMP;
		tb_jump_addr <= x"00002000";
		WAIT FOR 1 ns;
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00002000" THEN
			REPORT "TEST 7 (Jump): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 7 (Jump): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 8: Return Sequential
		tb_pc_src <= PC_SRC_PC4;
		WAIT FOR 1 ns;
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00002004" THEN
			REPORT "TEST 8 (Sequential Return): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 8 (Sequential Return): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 9: Stall
		tb_stall <= '1';
		WAIT FOR 1 ns;
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00002004" THEN
			REPORT "TEST 9 (Stall): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 9 (Stall): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

		-- TEST 10: Stall Release
		tb_stall <= '0';
		WAIT FOR 1 ns;
		WAIT FOR CLK_PERIOD;

		IF tb_pc = x"00002008" THEN
			REPORT "TEST 10 (Stall Release): PASS";
			test_passed := test_passed + 1;
		ELSE
			REPORT "TEST 10 (Stall Release): FAIL" SEVERITY error;
			test_failed := test_failed + 1;
		END IF;

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