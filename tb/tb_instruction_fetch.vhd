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

    -- Instantiate DUT
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

    -- Clock generation process
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

    -- Stimulus process
    stimulus_proc : PROCESS
    BEGIN
        REPORT "Starting instruction fetch unit simulation";

        -- Reset and initialization
        tb_rst <= '1';
        tb_branch <= '0';
        tb_stall <= '0';
        tb_instr_data <= x"00000000";
        tb_branch_addr <= x"00000040";
        WAIT FOR CLK_PERIOD * 2;

        tb_rst <= '0';  -- Release reset
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;

        -- Check reset PC value
        ASSERT tb_pc_out = RESET_ADDRESS
        REPORT "Reset PC check passed" SEVERITY note;

        -- Provide instruction data, check fetch output
        tb_instr_data <= x"DEADBEEF";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_instruction = x"DEADBEEF"
        REPORT "Instruction fetch check passed" SEVERITY note;

        -- Test branch taken (jump to branch address)
        tb_branch <= '1';
        tb_branch_addr <= x"00000080";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_pc_out = x"00000080"
        REPORT "Branch address PC update passed" SEVERITY note;

        tb_branch <= '0';  -- Stop branch
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;

        -- Test stall (PC should not advance)
        tb_stall <= '1';
        tb_instr_data <= x"CAFEBABE";
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_pc_out = x"00000080"
        REPORT "Stall holds PC passed" SEVERITY note;

        tb_stall <= '0';  -- Release stall
        WAIT UNTIL tb_clk = '1';
        WAIT FOR 1 ns;
        ASSERT tb_pc_out = std_logic_vector(unsigned(tb_branch_addr) + to_unsigned(4, ADDR_WIDTH))
        REPORT "PC increments after stall passed" SEVERITY note;

        -- Finish simulation
        REPORT "Instruction fetch unit testbench completed successfully";
        stop_sim <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE test;
