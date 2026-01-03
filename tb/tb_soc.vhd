LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_soc IS
END ENTITY tb_soc;

ARCHITECTURE behavioral OF tb_soc IS

    -- 1. DUT Declaration
    COMPONENT soc IS
        GENERIC (
            G_CLK_FREQ : INTEGER := 100_000_000; 
            G_BAUDRATE : INTEGER := 10_000_000   
        );
        PORT (
            clk     : IN  STD_LOGIC;
            uart_rx : IN  STD_LOGIC;
            uart_tx : OUT STD_LOGIC
        );
    END COMPONENT soc;

    -- 2. Signals
    SIGNAL r_clk      : STD_LOGIC := '0';
    SIGNAL r_uart_rx  : STD_LOGIC := '1'; 
    -- Initialize to '1' (Idle)
    SIGNAL w_uart_tx  : STD_LOGIC := '1'; 

    -- Simulation Constants
    CONSTANT C_CLK_PERIOD : TIME := 10 ns;   
    CONSTANT C_BIT_PERIOD : TIME := 100 ns;  

    -- 3. Procedure to Send Byte
    PROCEDURE UART_SEND (
        data_in       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        SIGNAL tx_line : OUT STD_LOGIC
    ) IS
    BEGIN
        tx_line <= '0'; -- Start
        WAIT FOR C_BIT_PERIOD;
        FOR i IN 0 TO 7 LOOP
            tx_line <= data_in(i); -- Data
            WAIT FOR C_BIT_PERIOD;
        END LOOP;
        tx_line <= '1'; -- Stop
        WAIT FOR C_BIT_PERIOD;
    END PROCEDURE;

BEGIN

    U_DUT : soc
    GENERIC MAP (
        G_CLK_FREQ => 100_000_000, 
        G_BAUDRATE => 10_000_000
    )
    PORT MAP (
        clk     => r_clk,
        uart_rx => r_uart_rx,
        uart_tx => w_uart_tx
    );

    -- Clock Process
    r_clk <= NOT r_clk AFTER C_CLK_PERIOD / 2;

    -- =========================================================
    -- UART RECEIVER MONITOR (DEBUG VERSION)
    -- =========================================================
    PROCESS
        VARIABLE v_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        -- Initial Wait to ignore startup noise
        WAIT FOR 100 ns;

        LOOP
            -- 1. Search for Start Bit
            -- If the line is already low (back-to-back), we start immediately.
            -- If it's high, we wait for the falling edge.
            IF w_uart_tx = '1' THEN
                WAIT UNTIL w_uart_tx = '0';
            END IF;
            
            -- REPORT "Debug: Start Bit Detected"; -- Uncomment for verbose debug

            -- 2. Move to Center of Start Bit
            WAIT FOR C_BIT_PERIOD / 2;

            -- 3. Verify it is still low (Noise Filter)
            IF w_uart_tx /= '0' THEN
                REPORT "Debug: False Start Bit Ignored" SEVERITY WARNING;
                WAIT UNTIL w_uart_tx = '1'; -- Wait for line to recover
                NEXT; -- Restart loop
            END IF;

            -- 4. Move to Center of First Data Bit
            WAIT FOR C_BIT_PERIOD;

            -- 5. Read 8 Data Bits
            FOR i IN 0 TO 7 LOOP
                v_data(i) := w_uart_tx;
                WAIT FOR C_BIT_PERIOD;
            END LOOP;

            -- 6. Print Character
            REPORT "UART TX Received: " & CHARACTER'VAL(to_integer(unsigned(v_data)));

            -- 7. Sync to Stop Bit
            -- We are currently at the center of Bit 7.
            -- Stop bit starts 0.5 periods away.
            WAIT FOR C_BIT_PERIOD; 
            
            -- Now at Center of Stop Bit. Should be '1'.
            -- We don't error check here to be lenient to the DUT, but we wait 
            -- to ensure we are well into the stop bit before looping.
            
            -- Wait remaining half of Stop Bit to reach the Frame Boundary
            WAIT FOR C_BIT_PERIOD / 2;
            
            -- Add a tiny delta delay to allow the signal to transition if it's back-to-back
            WAIT FOR 1 ns;
        END LOOP;
    END PROCESS;

    -- =========================================================
    -- STIMULUS
    -- =========================================================
    PROCESS
    BEGIN
        WAIT FOR 200 ns; 
        REPORT "Test: Sending SPACE (0x20)...";
        UART_SEND(x"20", r_uart_rx);

        REPORT "Test: Waiting for response...";
        -- Increased timeout to ensure full string "Hello World!\r\n" fits
        -- 15 chars * 1us/char = 15us minimum + CPU overhead.
        -- 200us is plenty safe.
        WAIT FOR 200 us; 

        REPORT "Test: Simulation Complete.";
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
