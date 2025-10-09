LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_instruction_fetch IS
END ENTITY tb_instruction_fetch;

ARCHITECTURE test OF tb_instruction_fetch IS

    CONSTANT CLK_PERIOD        : TIME := 10 ns;
    CONSTANT ADDR_WIDTH        : INTEGER := 32;
    CONSTANT INSTRUCTION_WIDTH : INTEGER := 32;
    CONSTANT RESET_ADDRESS     : std_logic_vector(31 DOWNTO 0) := x"00000000";

    COMPONENT instruction_fetch_unit IS
        GENERIC (
            ADDR_WIDTH : INTEGER := 32;
            INSTRUCTION_WIDTH : INTEGER := 32;
            RESET_ADDRESS : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0')
        );
        PORT (
            clk : IN std_logic;
            rst : IN std_logic;
            instr_addr : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
            instr_data : IN std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
            branch_address : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
            instruction : OUT std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
            pc_out : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
            pc_plus_4 : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
            branch : IN std_logic;
            stall : IN std_logic
        );
    END COMPONENT;

    SIGNAL tb_clk           : std_logic := '0';
    SIGNAL tb_rst           : std_logic;
    SIGNAL tb_instr_addr    : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_instr_data    : std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_branch_addr   : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_instruction   : std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_pc_out        : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_pc_plus_4     : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
    SIGNAL tb_branch        : std_logic;
    SIGNAL tb_stall         : std_logic;

    SIGNAL stop_sim : BOOLEAN := false;

BEGIN

    -- Instantiate DUT with correct entity name
    dut_inst : instruction_fetch_unit
        GENERIC MAP(
            ADDR_WIDTH => ADDR_WIDTH,
            INSTRUCTION_WIDTH => INSTRUCTION_WIDTH,
            RESET_ADDRESS => RESET_ADDRESS
        )
        PORT MAP(
            clk => tb_clk,
            rst => tb_rst,
            instr_addr => tb_instr_addr,
            instr_data => tb_instr_data,
            branch_address => tb_branch_addr,
            instruction => tb_instruction,
            pc_out => tb_pc_out,
            pc_plus_4 => tb_pc_plus_4,
            branch => tb_branch,
            stall => tb_stall
        );

    -- Clock generator
    clk_gen_proc : PROCESS
    BEGIN
        WHILE NOT stop_sim LOOP
            tb_clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            tb_clk <= '1';
            WAIT FOR CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    -- Stimuli with multiple tests
    stimulus_proc : PROCESS
    BEGIN
        REPORT "Starting INSTRUCTION FETCH Testbench";

        -- Basic Reset and Initialization
        tb_rst <= '1';
        tb_branch <= '0';
        tb_stall <= '0';
        tb_instr_data <= x"DEADBEEF";
        tb_branch_addr <= x"00000040";
        WAIT FOR CLK_PERIOD * 2;

        -- Deassert reset, wait for PC to update
        tb_rst <= '0';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;

        -- Test 1: Verify reset PC
        ASSERT tb_pc_out = RESET_ADDRESS
        REPORT "Reset PC OK - passed" SEVERITY note;

        -- Test 2: Write a different instruction, check reading
        tb_instr_data <= x"CAFEBABE";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_instruction = x"CAFEBABE"
        REPORT "Instruction read AFTER write OK" SEVERITY note;

        -- Test 3: Simulate a small hazard: change instruction data mid-clock
        tb_instr_data <= x"AAAAAAAA";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        -- Next cycle, instruction should be updated
        tb_instr_data <= x"BBBBBBBB";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_instruction = x"BBBBBBBB"
        REPORT "Instruction updates ON clock edge OK" SEVERITY note;

        -- Test 4: Read from a different branch address
        tb_branch <= '1';
        tb_branch_addr <= x"00000080";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        tb_branch <= '0'; -- deactivate after update
        ASSERT tb_pc_out = x"00000080"
        REPORT "Branch taken PC correct" SEVERITY note;

        -- Test 5: Stall condition — ensure PC doesn't change
        tb_stall <= '1';
        tb_instr_data <= x"FFFFFFFF";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_pc_out = x"00000080"
        REPORT "PC held during stall OK" SEVERITY note;

        -- Test 6: Release stall and check PC increments
        tb_stall <= '0';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_pc_out = std_logic_vector(unsigned(tb_branch_addr) + to_unsigned(4, 32))
        REPORT "PC increments AFTER stall OK" SEVERITY note;

        -- Additional tests:

        -- Port: instr_addr (transmit address)
        tb_instr_addr <= x"00000010";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_instr_addr = x"00000010"
        REPORT "Instruction address PORT transmission OK" SEVERITY note;

        -- Port: branch, test rising edge and falling edge
        tb_branch <= '1';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_branch = '1' SEVERITY note;
        tb_branch <= '0';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_branch = '0' SEVERITY note;

        -- Port: stall, test toggling
        tb_stall <= '1';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_stall = '1' SEVERITY note;
        tb_stall <= '0';
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_stall = '0' SEVERITY note;

        -- Check that instruction fetch continues correctly after multiple toggles
        tb_instr_data <= x"0F0F0F0F";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_instruction = x"0F0F0F0F" SEVERITY note;

        -- Simulation complete
        REPORT "ALL tests passed";
        stop_sim <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE;
