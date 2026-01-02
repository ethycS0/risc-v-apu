LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_soc IS
END ENTITY tb_soc;

ARCHITECTURE behavioral OF tb_soc IS

    -- 1. DUT Declaration
    COMPONENT soc IS
        GENERIC (
            G_CLK_FREQ : INTEGER := 100_000_000; -- Fast sim clock
            G_BAUDRATE : INTEGER := 10_000_000   -- Fast sim baud
        );
        PORT (
            clk     : IN  STD_LOGIC;
            -- rst     : IN  STD_LOGIC;
            uart_rx : IN  STD_LOGIC;
            uart_tx : OUT STD_LOGIC
        );
    END COMPONENT soc;

    -- 2. Signals
    SIGNAL r_clk      : STD_LOGIC := '0';
    SIGNAL r_rst      : STD_LOGIC := '1';
    SIGNAL r_uart_rx  : STD_LOGIC := '1'; -- Idle high
    SIGNAL w_uart_tx  : STD_LOGIC;

    -- Simulation Constants
    CONSTANT C_CLK_PERIOD : TIME := 10 ns;
    CONSTANT C_BIT_PERIOD : TIME := 100 ns; -- Matching 10M Baud

    -- 3. Procedure to Send Byte to SoC (Bit-Banging)
    PROCEDURE UART_SEND (
        data_in       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL tx_line : OUT STD_LOGIC
    ) IS
    BEGIN
        -- Start Bit (Low)
        tx_line <= '0';
        WAIT FOR C_BIT_PERIOD;
        
        -- Data Bits (LSB First)
        FOR i IN 0 TO 7 LOOP
            tx_line <= data_in(i);
            WAIT FOR C_BIT_PERIOD;
        END LOOP;
        
        -- Stop Bit (High)
        tx_line <= '1';
        WAIT FOR C_BIT_PERIOD;
    END PROCEDURE;

BEGIN

    -- Instantiate SoC
    -- Note: We use high baudrate to make simulation faster
    U_DUT : soc
    GENERIC MAP (
        G_CLK_FREQ => 100_000_000, 
        G_BAUDRATE => 10_000_000
    )
    PORT MAP (
        clk     => r_clk,
        -- rst     => r_rst,
        uart_rx => r_uart_rx,
        uart_tx => w_uart_tx
    );

    -- Clock Process
    r_clk <= NOT r_clk AFTER C_CLK_PERIOD / 2;

    -- Test Process
    PROCESS
        VARIABLE v_expected : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        -- 1. Reset System
        WAIT FOR 250 ms;

        -- 2. Send 'A' (0x41) to SoC
        REPORT "Test: Sending 0x41 ('A')...";
        UART_SEND(x"41", r_uart_rx);

        -- 3. Wait for CPU to process (Poll -> Read -> Add -> Write)
        -- This depends on your CPU speed. 
        REPORT "Test: Waiting for CPU processing...";
        WAIT FOR 10 us; 

        -- 4. Check Result (Manual check or Waveform)
        -- In a waveform viewer, look at 'w_uart_tx'. 
        -- You should see the start bit, then 0x42 ('B'), then stop bit.
        
        REPORT "Test: Simulation Complete. Verify w_uart_tx in waveform.";
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
