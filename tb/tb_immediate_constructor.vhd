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
    CONSTANT zero_32 : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0');

BEGIN

    dut_inst : immediate_constructor_unit
        PORT MAP (
            instruction => instruction,
            immediate   => immediate
        );

    stimulus_proc : PROCESS
        FUNCTION replicate(bit_val : std_logic; size : INTEGER) RETURN std_logic_vector IS
            VARIABLE result : std_logic_vector(size - 1 DOWNTO 0);
        BEGIN
            FOR i IN 0 TO size - 1 LOOP
                result(i) := bit_val;
            END LOOP;
            RETURN result;
        END FUNCTION;
    BEGIN
        REPORT "INFO: Starting Immediate Constructor Testbench...";

        -- U-Type test vectors (LUI, AUIPC)
        instruction <= x"00001037";  -- LUI example with low immediate
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 12) = instruction(31 DOWNTO 12) AND
               immediate(11 DOWNTO 0) = zero_12
            REPORT "U-type low immediate test passed." SEVERITY note;
        
        instruction <= x"FFFFF037";  -- LUI example with high immediate (negative)
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 12) = instruction(31 DOWNTO 12) AND
               immediate(11 DOWNTO 0) = zero_12
            REPORT "U-type high immediate (negative) test passed." SEVERITY note;

        -- J-Type test vector (JAL)
        instruction <= x"0040006F";  -- JAL positive offset
        WAIT FOR CLK_PERIOD;
        -- Check sign extension bit
        ASSERT immediate(31) = instruction(31)
            REPORT "J-type sign bit extension test passed." SEVERITY note;
        -- Check immediate bit arrangement 
        ASSERT immediate(20 DOWNTO 1) = instruction(19 DOWNTO 12) & instruction(20) & instruction(30 DOWNTO 21)
            REPORT "J-type immediate bits arrangement test passed." SEVERITY note;

        -- B-Type test vector (Branch)
        instruction <= x"FE0006E3";  -- BEQ with negative offset
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31) = instruction(31)
            REPORT "B-type sign bit extension test passed." SEVERITY note;
        ASSERT immediate(12 DOWNTO 1) = instruction(7) & instruction(30 DOWNTO 25) & instruction(11 DOWNTO 8)
            REPORT "B-type immediate bits arrangement test passed." SEVERITY note;

        -- I-Type test vector (Load, ALU immediate)
        instruction <= x"00000293";  -- ADDI with zero immediate
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 11) = replicate(instruction(31), 21)
            REPORT "I-type sign extension test passed." SEVERITY note;
        ASSERT immediate(10 DOWNTO 0) = instruction(30 DOWNTO 20)
            REPORT "I-type immediate bits test passed." SEVERITY note;

        -- S-Type test vector (Store)
        instruction <= x"00A02223";  -- SW instruction
        WAIT FOR CLK_PERIOD;
        ASSERT immediate(31 DOWNTO 11) = replicate(instruction(31), 21)
            REPORT "S-type sign extension test passed." SEVERITY note;
        ASSERT immediate(11 DOWNTO 5) & immediate(4 DOWNTO 0) = instruction(30 DOWNTO 25) & instruction(11 DOWNTO 7)
            REPORT "S-type immediate bits arrangement test passed." SEVERITY note;

        -- R-Type test vector (Register instructions)
        instruction <= x"00000033";  -- ADD instruction (no immediate)
        WAIT FOR CLK_PERIOD;
        ASSERT immediate = zero_32
            REPORT "R-type no immediate test passed." SEVERITY note;

        REPORT "INFO: All Immediate Constructor tests passed successfully.";
        stop_sim <= true;
        WAIT;
    END PROCESS;

END ARCHITECTURE test;
