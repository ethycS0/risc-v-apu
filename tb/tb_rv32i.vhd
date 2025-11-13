LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL; -- Make sure your package is compiled

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
    CONSTANT c_INSTR_MEM : t_memory := (
        -- Test: (5 + 10) - 3 = 12
        -- This program requires 3 NOPs between a write
        -- and a read to avoid data hazards.
        
        -- Setup initial values
        0  => x"00500093", -- 0x00: addi x1, x0, 5
        1  => x"00A00113", -- 0x04: addi x2, x0, 10
        
        -- 3-cycle bubble
        2  => x"00000013", -- 0x08: nop
        3  => x"00000013", -- 0x0C: nop
        4  => x"00000013", -- 0x10: nop
        
        -- First calculation
        5  => x"002081B3", -- 0x14: add x3, x1, x2  (x3 = 5 + 10 = 15)
        6  => x"00300213", -- 0x18: addi x4, x0, 3
        
        -- 3-cycle bubble
        7  => x"00000013", -- 0x1C: nop
        8  => x"00000013", -- 0x20: nop
        9  => x"00000013", -- 0x24: nop

        -- Second calculation
        10 => x"404182B3", -- 0x28: sub x5, x3, x4  (x5 = 15 - 3 = 12)
        
        -- 3-cycle bubble
        11 => x"00000013", -- 0x2C: nop
        12 => x"00000013", -- 0x30: nop
        13 => x"00000013", -- 0x34: nop
        
        -- Store result
        14 => x"00502023", -- 0x38: sw x5, 0(x0)
        
        -- End
        15 => x"00000013", -- 0x3C: nop
        
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
        VARIABLE v_gotten_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
        -- The expected result is 12
        CONSTANT c_expected_result : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"0000000C";
    BEGIN
        REPORT "TB: Starting simulation.";
        -- Assert Reset
        s_rst <= '1';
        WAIT FOR 2 * CLK_PERIOD; -- Hold reset for 2 cycles
        s_rst <= '0';
        REPORT "TB: Reset de-asserted. CPU is running.";

        -- This program is 15 instructions long.
        -- The final 'sw' is at index 14.
        -- IF(sw) is in C15
        -- ID(sw) is in C16
        -- EX(sw) is in C17
        -- MEM(sw) is in C18 -> Writes to data memory
        -- Let's wait for 25 cycles just to be safe.
        
        WAIT FOR 25 * CLK_PERIOD;

        REPORT "TB: Checking results...";
        
        -- Read the result from our simulated Data Memory
        -- The SW instruction was `sw x5, 0(x0)`, so we check address 0.
        v_gotten_result := s_DATA_MEM(0);
        
        -- Print and Check
        REPORT "========================================";
        REPORT "TEST CASE: (5 + 10) - 3 = 12";
        REPORT "  Expected Result at Mem[0]: x""0000000C""";
        
        IF v_gotten_result = c_expected_result THEN
            REPORT "  Gotten Result at Mem[0]:   x""0000000C""";
            REPORT "  TEST PASSED!";
        ELSE
            -- You can use VHDL-2008's to_hstring() here if your simulator supports it
            REPORT "  Gotten Result is (see waveform).";
            REPORT "  TEST FAILED!";
            ASSERT FALSE REPORT "Test Failed" SEVERITY ERROR;
        END IF;
        REPORT "========================================";

        REPORT "TB: Simulation finished.";
        WAIT; -- Stop the process
    END PROCESS stim_proc;


END ARCHITECTURE behavioral;
