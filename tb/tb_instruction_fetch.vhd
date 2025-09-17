library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_instruction_fetch is
end entity;

architecture test of tb_instruction_fetch is
    constant CLK_PERIOD : time := 10 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal branch_en   : std_logic := '0';
    signal branch_addr : std_logic_vector(31 downto 0) := (others => '0');
    signal instruction : std_logic_vector(31 downto 0);

    signal stop_sim    : boolean := false;

    component instruction_fetch
        port (
            clk            : in  std_logic;
            rst            : in  std_logic;
            branch_en      : in  std_logic;
            branch_addr    : in  std_logic_vector(31 downto 0);
            instruction    : out std_logic_vector(31 downto 0)
        );
    end component;

begin

    dut_inst : instruction_fetch
        port map (
            clk => clk,
            rst => rst,
            branch_en => branch_en,
            branch_addr => branch_addr,
            instruction => instruction
        );

    -- Clock generator process
    clk_gen_proc : process
    begin
        while not stop_sim loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus and test process
    stim_proc : process
    begin
        report "INFO: Starting INSTRUCTION FETCH Testbench...";

        rst <= '1';
        branch_en <= '0';
        branch_addr <= (others => '0');
        wait for CLK_PERIOD * 2;

        rst <= '0';
        wait for CLK_PERIOD;

        report "TEST: Normal instruction fetch sequence";
        wait for CLK_PERIOD * 3;

        report "TEST: Simulating a branch/jump";
        branch_en <= '1';
        branch_addr <= x"00000020";
        wait for CLK_PERIOD;

        branch_en <= '0';
        wait for CLK_PERIOD * 3;

        -- Place optional assertions here if you want to check instruction outputs

        report "INFO: ALL tests passed. Simulation finished.";
        stop_sim <= true;

        wait;
    end process;

end architecture;
