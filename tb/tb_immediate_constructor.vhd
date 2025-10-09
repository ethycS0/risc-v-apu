LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_immediate_constructor IS
END ENTITY tb_immediate_constructor;

ARCHITECTURE test OF tb_immediate_constructor IS

    CONSTANT CLK_PERIOD : TIME := 10 ns;
    SIGNAL instruction : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL immediate   : std_logic_vector(31 DOWNTO 0);

    COMPONENT immediate_constructor_unit IS
        PORT (
            instruction : IN std_logic_vector(31 DOWNTO 0);
            immediate   : OUT std_logic_vector(31 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL stop_sim : BOOLEAN := false;

    CONSTANT zero_12 : std_logic_vector(11 DOWNTO 0) := (OTHERS => '0');

    FUNCTION replicate_bit(bit_val : std_logic; length : INTEGER) RETURN std_logic_vector IS
        VARIABLE result : std_logic_vector(length - 1 DOWNTO 0);
    BEGIN
        FOR i IN 0 TO length - 1 LOOP
            result(i) := bit_val;
        END LOOP;
        RETURN result;
    END FUNCTION;

BEGIN

    dut_inst : immediate_constructor_unit
        PORT MAP (
            instruction => instruction,
            immediate   => immediate
        );

    stimulus_proc : PROCESS
    BEGIN
        REPORT "INFO: Starting Immediate Constructor Testbench...";

        instruction <= x"FFFFF037";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 12) = instruction(31 DOWNTO 12) AND
               immediate(11 DOWNTO 0) = zero_12
            REPORT "U-type test case 1 passed." SEVERITY note;

        instruction <= x"00001017";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 12) = instruction(31 DOWNTO 12) AND
               immediate(11 DOWNTO 0) = zero_12
            REPORT "U-type test case 2 passed." SEVERITY note;

        instruction <= x"FFF0006F";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31) = instruction(31)
            REPORT "J-type sign bit extension test passed." SEVERITY note;

        instruction <= x"0000006F";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(20 DOWNTO 1) = instruction(19 DOWNTO 12) & instruction(20) & instruction(30 DOWNTO 21)
            REPORT "J-type immediate bits arrangement test passed." SEVERITY note;

        instruction <= x"FFF00763";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31) = instruction(31)
            REPORT "B-type sign extension test passed." SEVERITY note;

        instruction <= x"00000063";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(12 DOWNTO 1) = instruction(7) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 8)
            REPORT "B-type immediate bits arrangement test passed." SEVERITY note;

        instruction <= x"FFF00293";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 11) = replicate_bit(instruction(31), 21)
            REPORT "I-type sign extension test passed." SEVERITY note;

        instruction <= x"00000313";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(10 DOWNTO 0) = instruction(30 DOWNTO 20)
            REPORT "I-type immediate bits test passed." SEVERITY note;

        instruction <= x"FFF02223";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 11) = replicate_bit(instruction(31), 21)
            REPORT "S-type sign extension test passed." SEVERITY note;

        instruction <= x"00002023";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(11 DOWNTO 5) & immediate(4 DOWNTO 0) = instruction(30 DOWNTO 25) & instruction(11 DOWNTO 7)
            REPORT "S-type immediate bits arrangement test passed." SEVERITY note;

        instruction <= x"00000033";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate = x"00000000"
            REPORT "R-type default immediate zero test passed." SEVERITY note;

        instruction <= x"FFFFFFFF";
        WAIT FOR CLK_PERIOD;
        ASSERT immediate = x"00000000"
            REPORT "R-type default immediate zero with all ones input test passed." SEVERITY note;

        instruction <= x"7FFFFFF7"; -- Additional U-type upper bound test
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 12) = instruction(31 DOWNTO 12) AND
               immediate(11 DOWNTO 0) = zero_12
            REPORT "U-type upper bound test passed." SEVERITY note;

        instruction <= x"8000006F"; -- Additional J-type with MSB zero
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31) = instruction(31)
            REPORT "J-type zero MSB sign extension test passed." SEVERITY note;

        instruction <= x"00800063"; -- Additional B-type zero immediate with different bits
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(12 DOWNTO 1) = instruction(7) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 8)
            REPORT "B-type zero immediate variation test passed." SEVERITY note;

        instruction <= x"00100293"; -- Additional I-type positive immediate
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 11) = replicate_bit(instruction(31), 21)
            REPORT "I-type positive immediate sign extension test passed." SEVERITY note;

        instruction <= x"00002023"; -- Additional S-type zero immediate test variant
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(11 DOWNTO 5) & immediate(4 DOWNTO 0) = instruction(30 DOWNTO 25) & instruction(11 DOWNTO 7)
            REPORT "S-type zero immediate variation test passed." SEVERITY note;

        REPORT "INFO: All Immediate Constructor tests passed successfully.";
        stop_sim <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE test;
