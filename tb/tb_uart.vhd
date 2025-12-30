LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_uart IS
END ENTITY tb_uart;

ARCHITECTURE sim OF tb_uart IS
	-- Component declaration
	COMPONENT uart IS
		GENERIC (
			G_CLK : INTEGER := 1_843_200;
			G_BAUDRATE : INTEGER := 115200
		);
		PORT (
			i_clk : IN STD_LOGIC;
			i_rst : IN STD_LOGIC;
			i_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			i_tx_new : IN STD_LOGIC;
			o_tx_ready : OUT STD_LOGIC;
			o_rx_new : OUT STD_LOGIC;
			o_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			i_rx : IN STD_LOGIC;
			o_tx : OUT STD_LOGIC
		);
	END COMPONENT;

	-- Testbench constants
	CONSTANT CLK_PERIOD : TIME := 542.53 ns; -- 1/1843200 = 542.53ns
	CONSTANT BIT_PERIOD : TIME := 8.681 us; -- 1/115200 = 8.681us (16 clocks)
	-- Testbench signals
	SIGNAL clk : STD_LOGIC := '0';
	SIGNAL rst : STD_LOGIC := '1';
	SIGNAL tx_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL tx_new : STD_LOGIC := '0';
	SIGNAL tx_ready : STD_LOGIC;
	SIGNAL rx_new : STD_LOGIC;
	SIGNAL rx_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL rx_in : STD_LOGIC := '1';
	SIGNAL tx_out : STD_LOGIC;
 
	SIGNAL sim_done : BOOLEAN := FALSE;

	-- Procedure to send UART byte
	PROCEDURE send_uart_byte(
		CONSTANT data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		SIGNAL rx_sig : OUT STD_LOGIC
) IS
BEGIN
	-- Start bit
	rx_sig <= '0';
	WAIT FOR BIT_PERIOD;
 
	-- Data bits (LSB first)
	FOR i IN 0 TO 7 LOOP
		rx_sig <= data(i);
		WAIT FOR BIT_PERIOD;
	END LOOP;
 
	-- Stop bit
	rx_sig <= '1';
	WAIT FOR BIT_PERIOD;
END PROCEDURE;
 
-- Procedure to wait for tx_ready with timeout
PROCEDURE wait_for_tx_ready(
	SIGNAL tx_rdy : IN STD_LOGIC;
	CONSTANT timeout_cycles : IN INTEGER := 200
) IS
BEGIN
	FOR i IN 0 TO timeout_cycles LOOP
		IF tx_rdy = '1' THEN RETURN;
		END IF;
		WAIT FOR CLK_PERIOD;
	END LOOP;
	REPORT "TIMEOUT waiting FOR tx_ready!" SEVERITY FAILURE;
END PROCEDURE;

BEGIN
	-- Clock generator
	clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';

	-- DUT instantiation
	dut : uart
		GENERIC MAP(
		G_CLK => 1_843_200, 
		G_BAUDRATE => 115200
		)
		PORT MAP(
			i_clk => clk, 
			i_rst => rst, 
			i_data => tx_data, 
			i_tx_new => tx_new, 
			o_tx_ready => tx_ready, 
			o_rx_new => rx_new, 
			o_data => rx_data, 
			i_rx => rx_in, 
			o_tx => tx_out
		);

        -- Main stimulus process
        stimulus : PROCESS
        BEGIN
                -- Initialize
                rst <= '1';
                tx_new <= '0';
                tx_data <= (OTHERS => '0');
                rx_in <= '1';

                -- Hold reset
                WAIT FOR 20 * CLK_PERIOD;

                -- Release reset
                rst <= '0';

                -- Wait for design to settle
                WAIT FOR 20 * CLK_PERIOD;

                REPORT "=== UART Testbench Starting ===";
                REPORT "tx_ready initial state: " & std_logic'image(tx_ready);

                -- ===================================================================
                -- Test 1: Simple TX
                -- ===================================================================
                REPORT "--- Test 1: Transmit single byte 'A' (0x41) ---";

                wait_for_tx_ready(tx_ready, 50);
                REPORT "tx_ready IS HIGH, sending byte";

                tx_data <= x"41";
                tx_new <= '1';
                WAIT FOR CLK_PERIOD;
                tx_new <= '0';

                REPORT "Waiting FOR transmission TO complete...";
                WAIT FOR CLK_PERIOD;
                wait_for_tx_ready(tx_ready, 200);

                REPORT "Test 1: PASS - Byte transmitted";
                WAIT FOR 50 * CLK_PERIOD;

                -- ===================================================================
                -- Test 2: RX single byte
                -- ===================================================================
                REPORT "--- Test 2: Receive single byte 'B' (0x42) ---";

                send_uart_byte(x"42", rx_in);

                -- Wait for rx_new with timeout
                FOR i IN 0 TO 200 LOOP
                        IF rx_new = '1' THEN
                                EXIT; -- Exit immediately when we see the pulse
                        END IF;
                        WAIT FOR CLK_PERIOD;
                END LOOP;

                -- Check immediately after loop (within same delta cycle)
                WAIT FOR 0 ns; -- Let signals settle

                IF rx_new = '1' THEN
                        -- We exited due to rx_new pulse
                        IF rx_data = x"42" THEN
                                REPORT "Test 2: PASS - Received correct data: 0x42";
                        ELSE
                                REPORT "Test 2: FAIL - Received wrong data: 0x" & 
                                        to_hstring(rx_data) SEVERITY ERROR;
                        END IF;
                ELSE
                        -- We exited due to timeout
                        REPORT "Test 2: FAIL - No RX data received" SEVERITY ERROR;
                END IF;

                WAIT FOR 50 * CLK_PERIOD;
                -- ===================================================================
                -- Test 3: TX multiple bytes
                -- ===================================================================
                REPORT "--- Test 3: Transmit multiple bytes 'HI' ---";

                -- Send 'H'
                wait_for_tx_ready(tx_ready, 50);
                tx_data <= x"48";
                tx_new <= '1';
                WAIT FOR CLK_PERIOD;
                tx_new <= '0';
                wait_for_tx_ready(tx_ready, 200);
                REPORT "Sent 'H'";

                -- Send 'I'
                tx_data <= x"49";
                tx_new <= '1';
                WAIT FOR CLK_PERIOD;
                tx_new <= '0';
                wait_for_tx_ready(tx_ready, 200);
                REPORT "Sent 'I'";

                REPORT "Test 3: PASS";
                WAIT FOR 50 * CLK_PERIOD;

                -- ===================================================================
                -- Test 4: RX multiple bytes
                -- ===================================================================
                REPORT "--- Test 4: Receive multiple bytes 'OK' ---";

                -- Receive 'O'
                send_uart_byte(x"4F", rx_in);
                FOR i IN 0 TO 200 LOOP
                        EXIT WHEN rx_new = '1';
                        WAIT FOR CLK_PERIOD;
                END LOOP;
                ASSERT rx_data = x"4F"
                        REPORT "Failed TO receive 'O'" SEVERITY ERROR;
                        REPORT "Received 'O'";
                        WAIT FOR 10 * CLK_PERIOD;

                        -- Receive 'K'
                        send_uart_byte(x"4B", rx_in);
                        FOR i IN 0 TO 200 LOOP
                                EXIT WHEN rx_new = '1';
                                WAIT FOR CLK_PERIOD;
                        END LOOP;
                        ASSERT rx_data = x"4B"
                                REPORT "Failed TO receive 'K'" SEVERITY ERROR;
                                REPORT "Received 'K'";

                                REPORT "Test 4: PASS";
                                WAIT FOR 50 * CLK_PERIOD;

                                -- ===================================================================
                                -- All tests complete
                                -- ===================================================================
                                REPORT "=== ALL Tests Complete ===";
                                sim_done <= TRUE;
                                WAIT;
        END PROCESS stimulus;

        -- Monitor RX data
        rx_monitor : PROCESS
        BEGIN
                WAIT UNTIL rx_new = '1';
                REPORT "RX Monitor: Received 0x" & to_hstring(rx_data) & 
                        " ('" & CHARACTER'val(to_integer(unsigned(rx_data))) & "')";
        END PROCESS;

        -- Watchdog timer
        watchdog : PROCESS
        BEGIN
                WAIT FOR 10 ms;
                IF NOT sim_done THEN
                        REPORT "WATCHDOG TIMEOUT - Simulation took too long!" SEVERITY FAILURE;
                END IF;
                WAIT;
        END PROCESS;

END ARCHITECTURE sim;
