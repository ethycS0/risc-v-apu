LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL; -- Ensure this package has t_CsrOpcodes
USE std.env.ALL;        -- For 'stop' procedure

ENTITY tb_csr_unit IS
END ENTITY tb_csr_unit;

ARCHITECTURE behavioral OF tb_csr_unit IS
    -- Constants
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    CONSTANT CSR_ADDR_WIDTH : INTEGER := 12;

    -- Signals connecting to DUT
    SIGNAL s_clk        : STD_LOGIC := '0';
    SIGNAL s_rst        : STD_LOGIC := '0';
    SIGNAL s_write_en   : STD_LOGIC := '0';
    SIGNAL s_csr_op     : t_CsrOpcodes := RW;
    SIGNAL s_csr_addr   : STD_LOGIC_VECTOR(CSR_ADDR_WIDTH - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_csr_data   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_read_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_epc        : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_mtvec      : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN

    -- 1. Instantiate the Device Under Test (DUT)
    U_CSR_UNIT : ENTITY work.csr_unit
        PORT MAP(
            i_clk       => s_clk,
            i_rst       => s_rst,
            i_write_en  => s_write_en,
            i_csr_op    => s_csr_op,
            i_csr_addr  => s_csr_addr,
            i_csr_data  => s_csr_data,
            o_read_data => s_read_data,
            o_epc       => s_epc,
            o_mtvec     => s_mtvec
        );

    -- 2. Clock Generation Process
    p_clk : PROCESS
    BEGIN
        WHILE TRUE LOOP
            s_clk <= '0'; WAIT FOR CLK_PERIOD / 2;
            s_clk <= '1'; WAIT FOR CLK_PERIOD / 2;
        END LOOP;
    END PROCESS;

    -- 3. Stimulus Process
    p_test : PROCESS
    BEGIN
        REPORT "--- STARTING CSR UNIT TESTS ---";

        -- =========================================================
        -- TEST 1: Reset Behavior
        -- =========================================================
        s_rst <= '1';
        WAIT FOR CLK_PERIOD * 2;
        s_rst <= '0';
        WAIT FOR CLK_PERIOD;

        -- Check MISA Reset Value (Should be RV32I M-Mode: 0x40000001)
        s_csr_addr <= x"301"; -- MISA
        WAIT FOR 1 ns; -- Delta cycle wait for combinatorial read
        ASSERT s_read_data = x"40000001"
            REPORT "FAIL: Reset Value of MISA incorrect. Got: " & to_hstring(s_read_data)
            SEVERITY FAILURE;
        REPORT "PASS: Reset behavior verified.";


        -- =========================================================
        -- TEST 2: CSRRW (Atomic Read/Write) on MEPC (x341)
        -- =========================================================
        -- We will write 0xDEADBEEF to MEPC
        s_write_en <= '1';
        s_csr_op   <= RW;
        s_csr_addr <= x"341"; -- MEPC
        s_csr_data <= x"DEADBEEF";
        WAIT FOR CLK_PERIOD; -- Wait for clock edge to commit write

        -- Now Read it back (Disable write to prevent overwrite)
        s_write_en <= '0';
        WAIT FOR CLK_PERIOD; 
        
        ASSERT s_read_data = x"DEADBEEF"
            REPORT "FAIL: CSRRW failed on MEPC. Got: " & to_hstring(s_read_data)
            SEVERITY FAILURE;
        REPORT "PASS: CSRRW (Write) verified.";


        -- =========================================================
        -- TEST 3: CSRRS (Atomic Set Bits) on MEPC
        -- =========================================================
        -- Current MEPC: 0xDEADBEEF (1101 ... 1111)
        -- Operation: OR with 0x0000FFFF
        -- Expected: 0xDEADFFFF
        
        s_write_en <= '1';
        s_csr_op   <= RS;
        s_csr_addr <= x"341"; 
        s_csr_data <= x"0000FFFF";
        WAIT FOR CLK_PERIOD;

        -- Read back
        s_write_en <= '0';
        WAIT FOR CLK_PERIOD;

        ASSERT s_read_data = x"DEADFFFF"
            REPORT "FAIL: CSRRS failed. Expected DEADFFFF, Got: " & to_hstring(s_read_data)
            SEVERITY FAILURE;
        REPORT "PASS: CSRRS (Set Bits) verified.";


        -- =========================================================
        -- TEST 4: CSRRC (Atomic Clear Bits) on MEPC
        -- =========================================================
        -- Current MEPC: 0xDEADFFFF
        -- Operation: AND NOT 0x000000FF (Clear bottom 8 bits)
        -- Expected: 0xDEADFF00

        s_write_en <= '1';
        s_csr_op   <= RC;
        s_csr_addr <= x"341";
        s_csr_data <= x"000000FF";
        WAIT FOR CLK_PERIOD;

        -- Read back
        s_write_en <= '0';
        WAIT FOR CLK_PERIOD;

        ASSERT s_read_data = x"DEADFF00"
            REPORT "FAIL: CSRRC failed. Expected DEADFF00, Got: " & to_hstring(s_read_data)
            SEVERITY FAILURE;
        REPORT "PASS: CSRRC (Clear Bits) verified.";


        -- =========================================================
        -- TEST 5: Read-Only Protection (MVENDORID xF11)
        -- =========================================================
        -- Try to write all Ones
        s_write_en <= '1';
        s_csr_op   <= RW;
        s_csr_addr <= x"F11";
        s_csr_data <= x"FFFFFFFF";
        WAIT FOR CLK_PERIOD;

        s_write_en <= '0';
        WAIT FOR CLK_PERIOD;

        ASSERT s_read_data = x"00000000"
            REPORT "FAIL: Read-Only register MVENDORID was overwritten!"
            SEVERITY FAILURE;
        REPORT "PASS: Read-Only protection verified.";


        -- =========================================================
        -- TEST 6: Performance Counter Increment (MCYCLE xB00)
        -- =========================================================
        -- We have been running for several cycles with write_en=0 mostly.
        -- Read MCYCLE. It should be non-zero.
        s_csr_addr <= x"B00";
        WAIT FOR 1 ns;
        
        ASSERT unsigned(s_read_data) > 0
            REPORT "FAIL: MCYCLE is not incrementing! Value: " & to_hstring(s_read_data)
            SEVERITY FAILURE;
            
        -- Sample current value
        REPORT "Current MCYCLE: " & to_hstring(s_read_data);
        
        -- Wait 10 cycles
        WAIT FOR CLK_PERIOD * 10;
        
        -- Read again. It should be roughly 10 higher.
        ASSERT unsigned(s_read_data) > 10
            REPORT "FAIL: MCYCLE did not increment enough."
            SEVERITY FAILURE;
        
        REPORT "PASS: Counter Increment verified.";

        REPORT "--- ALL TESTS PASSED SUCCESSFULLY ---";
        stop; -- End simulation gracefully
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
