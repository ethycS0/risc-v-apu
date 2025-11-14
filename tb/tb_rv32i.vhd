LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL; 

ENTITY tb_rv32i IS
END ENTITY tb_rv32i;

ARCHITECTURE behavioral OF tb_rv32i IS

    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT rv32i IS
        PORT (
            i_clk           : IN  STD_LOGIC;
            i_rst           : IN  STD_LOGIC;
            -- Instruction Memory Interface
            o_instr_addr    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            i_instr_data    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            -- Data Memory Interface
            o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            o_data_write_en : OUT STD_LOGIC;
            o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT rv32i;

    -- Testbench Constants
    CONSTANT CLK_PERIOD : TIME := 10 ns;

    -- Testbench Signals
    SIGNAL s_clk           : STD_LOGIC := '0';
    SIGNAL s_rst           : STD_LOGIC := '0';
    SIGNAL s_instr_addr    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_instr_data    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_addr     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_read     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write    : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write_en : STD_LOGIC;
    SIGNAL s_data_byte_en  : STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- Memory Simulation
    TYPE t_memory IS ARRAY(0 TO 63) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    
        -- Instruction Memory (Program ROM)
-- Instruction Memory (Program ROM)
    -- This program tests the forwarding unit and load-use hazards.
    -- It contains NO NOPs.
    CONSTANT c_INSTR_MEM : t_memory := (
        -- Program:
        -- 1. addi x1, x0, 10           (x1 = 10)
        -- 2. add x2, x1, x1           (x2 = 10 + 10 = 20)
        --    -> Tests EX/MEM -> EX forwarding for x1
        -- 3. sub x3, x2, x1           (x3 = 20 - 10 = 10)
        --    -> Tests EX/MEM -> EX forwarding for x2
        --    -> Tests MEM/WB -> EX forwarding for x1
        -- 4. sw x3, 0(x0)             (Store 10 at Mem[0])
        --    -> This checks our first result.
        --
        -- 5. lw x4, 0(x0)             (Load 10 from Mem[0])
        -- 6. add x5, x4, x4           (x5 = 10 + 10 = 20)
        --    -> !!! TESTS LOAD-USE HAZARD !!!
        --    -> CPU must stall for 1 cycle, then forward from MEM/WB
        -- 7. sw x5, 4(x0)             (Store 20 at Mem[4])
        --    -> This checks our second result.
        
        -- Assembler output:
        0  => x"00A00093", -- 1. addi x1, x0, 10
        1  => x"00108133", -- 2. add  x2, x1, x1
        2  => x"401101B3", -- 3. sub  x3, x2, x1
        3  => x"00302023", -- 4. sw   x3, 0(x0)
        4  => x"00002203", -- 5. lw   x4, 0(x0)
        5  => x"004202B3", -- 6. add  x5, x4, x4
        6  => x"00502223", -- 7. sw   x5, 4(x0)
        
        -- Loop
        7  => x"00000013", -- 8. nop
        
        OTHERS => x"00000013"
    );    
    
    -- Data Memory (RAM)
    SIGNAL s_DATA_MEM : t_memory := (OTHERS => (OTHERS => '0'));

BEGIN

    -- 1. Instantiate the Unit Under Test (UUT)
    UUT : rv32i
        PORT MAP(
            i_clk           => s_clk,
            i_rst           => s_rst,
            o_instr_addr    => s_instr_addr,
            i_instr_data    => s_instr_data,
            o_data_addr     => s_data_addr,
            i_data_read     => s_data_read,
            o_data_write    => s_data_write,
            o_data_write_en => s_data_write_en,
            o_data_byte_en  => s_data_byte_en
        );

    -- 2. Clock Generation Process
    clk_gen_proc : PROCESS
    BEGIN
        WHILE NOW < 500 ns LOOP -- Run simulation for 500 ns
            s_clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            s_clk <= '1';
            WAIT FOR CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS clk_gen_proc;

    -- 3. Instruction Memory (ROM) Process
    -- Combinational read based on instruction address
    instr_mem_proc : PROCESS (s_instr_addr)
        VARIABLE v_addr_index : INTEGER;
    BEGIN
        -- Address is byte-based, memory is word-based (32-bit)
        -- We divide by 4 by shifting right 2 bits.
        -- Using (7 DOWNTO 2) for a 64-word (256-byte) memory.
        v_addr_index := to_integer(unsigned(s_instr_addr(7 DOWNTO 2)));

        IF v_addr_index < c_INSTR_MEM'length THEN
            s_instr_data <= c_INSTR_MEM(v_addr_index);
        ELSE
            s_instr_data <= x"00000013"; -- Default to NOP if out of bounds
        END IF;
    END PROCESS instr_mem_proc;

    -- 4. Data Memory (RAM) Process
    -- Clocked write, Asynchronous read
    data_mem_proc : PROCESS (s_clk, s_data_addr, s_DATA_MEM)
        VARIABLE v_addr_index : INTEGER;
    BEGIN
        -- Asynchronous Read
        -- (This process is sensitive to s_data_addr and s_DATA_MEM)
        v_addr_index := to_integer(unsigned(s_data_addr(7 DOWNTO 2)));
        IF v_addr_index < s_DATA_MEM'length THEN
            s_data_read <= s_DATA_MEM(v_addr_index);
        ELSE
            s_data_read <= (OTHERS => 'X'); -- Read from out of bounds
        END IF;

        -- Synchronous (Clocked) Write
        IF rising_edge(s_clk) THEN
            IF s_data_write_en = '1' THEN
                v_addr_index := to_integer(unsigned(s_data_addr(7 DOWNTO 2)));
                IF v_addr_index < s_DATA_MEM'length THEN
                    
                    -- Handle byte enables for SB, SH
                    IF s_data_byte_en(0) = '1' THEN
                        s_DATA_MEM(v_addr_index)(7 DOWNTO 0) <= s_data_write(7 DOWNTO 0);
                    END IF;
                    IF s_data_byte_en(1) = '1' THEN
                        s_DATA_MEM(v_addr_index)(15 DOWNTO 8) <= s_data_write(15 DOWNTO 8);
                    END IF;
                    IF s_data_byte_en(2) = '1' THEN
                        s_DATA_MEM(v_addr_index)(23 DOWNTO 16) <= s_data_write(23 DOWNTO 16);
                    END IF;
                    IF s_data_byte_en(3) = '1' THEN
                        s_DATA_MEM(v_addr_index)(31 DOWNTO 24) <= s_data_write(31 DOWNTO 24);
                    END IF;
                    
                END IF;
            END IF;
        END IF;
    END PROCESS data_mem_proc;

-- 5. Stimulus and Verification Process
    stim_proc : PROCESS
        -- Variables for checking results
        VARIABLE v_gotten_result_1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE v_gotten_result_2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE v_test_passed     : BOOLEAN := TRUE;
        
        -- Expected result 1 (from ALU-ALU forwarding)
        CONSTANT c_expected_1 : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"0000000A"; -- 10
        -- Expected result 2 (from Load-Use hazard)
        CONSTANT c_expected_2 : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000014"; -- 20
        
    BEGIN
        REPORT "TB: Starting simulation.";
        -- Assert Reset
        s_rst <= '1';
        WAIT FOR 2 * CLK_PERIOD; -- Hold reset for 2 cycles
        s_rst <= '0';
        REPORT "TB: Reset de-asserted. CPU is running.";

        -- This program has 7 instructions + 1 load-use stall cycle
        -- The first 'sw' (inst 4) writes to memory in its MEM stage
        -- The second 'sw' (inst 7) writes to memory in its MEM stage
        -- Let's trace the second 'sw' (instruction 7):
        -- C1: IF(i1)
        -- ...
        -- C5: IF(i5:lw)
        -- C6: IF(i6:add), ID(i5:lw)
        -- C7: IF(i7:sw),  ID(i6:add), EX(i5:lw)
        -- C8: IF(nop),    ID(i7:sw),  EX(i6:add)  -> Load-Use Hazard Detected in previous cycle!
        --    -> Corrected trace:
        -- C7: IF(i7:sw),  ID(i6:add), EX(i5:lw), MEM(i4:sw) -> 1st result (10) written to Mem[0]
        -- C8: IF(nop),    ID(i7:sw),  EX(i6:add), MEM(i5:lw) -> Hazard Detected! ID(i6) needs EX(i5) which is 'lw'.
        -- C9: IF(nop),    ID(i7:sw),  EX(bubble), MEM(i6:add), WB(i5:lw)
        -- C10: IF(nop),   ID(bubble), EX(i7:sw),  MEM(bubble), WB(i6:add) -> Data forwarded from WB(i5) to EX(i6) in C9
        -- C11: IF(nop),   ID(nop),    EX(bubble), MEM(i7:sw),  WB(bubble)
        -- C12: IF(nop),   ID(nop),    EX(nop),    MEM(bubble), WB(i7:sw)  -> 2nd result (20) written to Mem[4]

        -- We must wait at least 13 cycles. Let's wait 30.
        WAIT FOR 30 * CLK_PERIOD;

        REPORT "TB: Checking results...";
        
        -- Read the results from our simulated Data Memory
        v_gotten_result_1 := s_DATA_MEM(0); -- Address 0
        v_gotten_result_2 := s_DATA_MEM(1); -- Address 4 (index 1)
        
        -- Print and Check
        REPORT "----------------------------------------";
        REPORT "Part 1: ALU-ALU Forwarding Test";
        REPORT "  Expected Result at Mem[0]: x""0000000A""";
        
        IF v_gotten_result_1 = c_expected_1 THEN
            REPORT "  Gotten Result at Mem[0] (see waveform).";
            REPORT "  ALU-ALU TEST: PASSED";
        ELSE
            REPORT "  Gotten Result at Mem[0] (see waveform).";
            REPORT "  ALU-ALU TEST: FAILED!";
            v_test_passed := FALSE;
        END IF;
        
        REPORT "----------------------------------------";
        REPORT "Part 2: Load-Use Hazard Test";
        REPORT "  Expected Result at Mem[4]: x""00000014""";
        
        IF v_gotten_result_2 = c_expected_2 THEN
            REPORT "  Gotten Result at Mem[4] (see waveform).";
            REPORT "  LOAD-USE TEST: PASSED";
        ELSE
            REPORT "  Gotten Result at Mem[4] (see waveform).";
            REPORT "  LOAD-USE TEST: FAILED!";
            v_test_passed := FALSE;
        END IF;
        
        REPORT "========================================";
        
        IF v_test_passed THEN
            REPORT "OVERALL RESULT: ALL TESTS PASSED!";
        ELSE
            ASSERT FALSE REPORT "One or more forwarding tests FAILED" SEVERITY ERROR;
        END IF;

        REPORT "TB: Simulation finished.";
        WAIT; -- Stop the process
    END PROCESS stim_proc;

END ARCHITECTURE behavioral;
