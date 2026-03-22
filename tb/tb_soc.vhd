--! @file tb_soc.vhd
--! SoC Functional Testbench
--! @author ethycS
--! @details This testbench verifies basic functionality of the System-on-Chip (SoC)
--! by testing UART communication and processor operation. It provides a simple
--! stimulus-response test environment for interactive debugging and functional
--! verification.
--!
--! Test sequence:
--! 1. Generate system clock (100 MHz)
--! 2. Wait for system initialization
--! 3. Send test character via UART RX (to SoC)
--! 4. Monitor UART TX output from SoC
--! 5. Decode and display received characters
--!
--! UART configuration:
--! - Clock frequency: 100 MHz
--! - Baud rate: 10 Mbps (high speed for fast simulation)
--! - Bit period: 100 ns (10 clock cycles per bit)
--! - Format: 8N1 (8 data bits, no parity, 1 stop bit)
--!
--! The testbench includes a UART receiver monitor that continuously watches the TX
--! line and decodes received bytes, reporting them via VHDL REPORT statements. This
--! allows observation of processor output during simulation. A UART transmit procedure
--! is provided to send test data to the SoC.
--!
--! This testbench is intended for interactive testing and debugging, not for
--! comprehensive verification (use tb_soc_riscof for compliance testing).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY tb_soc IS
END ENTITY tb_soc;

ARCHITECTURE behavioral OF tb_soc IS

	--! System-on-Chip component declaration
	COMPONENT soc IS
		GENERIC (
			G_CLK_FREQ : INTEGER := 100_000_000;
			G_BAUDRATE : INTEGER := 10_000_000;
                        G_RAM_SIZE  : INTEGER := 8192;       
                        G_CODE_FILE : STRING  := "code.hex"; 
                        G_SIM       : BOOLEAN := FALSE       
		);
		PORT (
			clk     : IN  STD_LOGIC;
			uart_rx : IN  STD_LOGIC;
			uart_tx : OUT STD_LOGIC
		);
	END COMPONENT soc;

	SIGNAL r_clk     : STD_LOGIC := '0'; --! System clock signal (100 MHz)
	SIGNAL r_uart_rx : STD_LOGIC := '1'; --! UART RX input to SoC (idle high)
	SIGNAL w_uart_tx : STD_LOGIC := '1'; --! UART TX output from SoC

	CONSTANT C_CLK_PERIOD : TIME := 10 ns;  --! Clock period (100 MHz = 10 ns)
	CONSTANT C_BIT_PERIOD : TIME := 100 ns; --! UART bit period (10 Mbps = 100 ns)

	CONSTANT C_INPUT_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"20"; --! Test input character (ASCII space)

	--! @brief UART Transmit Procedure
	--! @details Generates a UART serial frame on the specified TX line to send one byte
	--! of data to the SoC. The procedure implements the 8N1 format:
	--! - Start bit: Logic 0 for one bit period
	--! - 8 data bits: Transmitted LSB first
	--! - Stop bit: Logic 1 for one bit period
	--!
	--! Parameters:
	--! - data_in: 8-bit data byte to transmit
	--! - tx_line: Signal to drive with serial data (connected to SoC UART RX)
	--!
	--! The procedure uses C_BIT_PERIOD for timing, matching the configured baud rate.
	--! After transmission completes (stop bit), the line remains idle high until the
	--! next call. This procedure is blocking - it completes transmission before returning.
	PROCEDURE UART_SEND (
		data_in  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		SIGNAL tx_line : OUT STD_LOGIC
	) IS
	BEGIN
		tx_line <= '0';  -- Start bit
		WAIT FOR C_BIT_PERIOD;

		FOR i IN 0 TO 7 LOOP  -- Data bits (LSB first)
			tx_line <= data_in(i);
			WAIT FOR C_BIT_PERIOD;
		END LOOP;

		tx_line <= '1';  -- Stop bit
		WAIT FOR C_BIT_PERIOD;
	END PROCEDURE;

BEGIN

	--! @brief Device Under Test (SoC) Instance
	--! @details Instantiates the SoC with high-speed UART configuration for fast
	--! simulation. The baud rate is set to 10 Mbps (100 ns per bit) to reduce
	--! simulation time while maintaining accurate timing relationships.
	U_DUT : soc
	GENERIC MAP(
		G_CLK_FREQ => 100_000_000,
		G_BAUDRATE => 10_000_000,
                G_RAM_SIZE  => 8192,       
                G_CODE_FILE => "code.hex",
                G_SIM       => TRUE
	)
	PORT MAP(
		clk     => r_clk,
		uart_rx => r_uart_rx,
		uart_tx => w_uart_tx
	);

	-- Clock generation (100 MHz)
	r_clk <= NOT r_clk AFTER C_CLK_PERIOD / 2;

	--! @brief UART RX Monitor Process
	--! @details Continuous monitoring process that watches the SoC UART TX line and
	--! decodes received bytes. The process implements a complete UART receiver:
	--!
	--! Operation:
	--! 1. Wait for falling edge (start bit detection)
	--! 2. Wait half a bit period and verify start bit (mid-bit sampling)
	--! 3. If false start detected, ignore and wait for next falling edge
	--! 4. Sample 8 data bits at bit center (LSB first)
	--! 5. Wait through stop bit period
	--! 6. Report received character and repeat
	--!
	--! The mid-bit sampling improves noise immunity by sampling at the center of each
	--! bit period rather than at transitions. False start bit detection prevents
	--! synchronization errors from glitches. Received bytes are reported as both hex
	--! values and ASCII characters (if printable) for easy observation during simulation.
	--!
	--! This process runs continuously throughout simulation, providing real-time
	--! visibility into processor output via the UART interface.
	P_RX_MONITOR : PROCESS
		VARIABLE v_data : STD_LOGIC_VECTOR(7 DOWNTO 0); -- Received byte buffer
	BEGIN
		WAIT FOR 100 ns;  -- Initial settling delay

		LOOP
			-- Wait for start bit (falling edge on idle-high line)
			IF w_uart_tx = '1' THEN
				WAIT UNTIL w_uart_tx = '0';
			END IF;

			-- Verify start bit at mid-bit time (noise rejection)
			WAIT FOR C_BIT_PERIOD / 2;
			IF w_uart_tx /= '0' THEN
				REPORT "Debug: False Start Bit Ignored" SEVERITY WARNING;
				WAIT UNTIL w_uart_tx = '1';  -- Wait for line to return idle
				NEXT;  -- Restart detection
			END IF;

			-- Sample data bits (LSB first) at bit center
			WAIT FOR C_BIT_PERIOD;
			FOR i IN 0 TO 7 LOOP
				v_data(i) := w_uart_tx;
				WAIT FOR C_BIT_PERIOD;
			END LOOP;

			-- Report received character
			REPORT "UART TX Received: " & CHARACTER'VAL(to_integer(unsigned(v_data)));

			-- Wait through stop bit
			WAIT FOR C_BIT_PERIOD;
			WAIT FOR C_BIT_PERIOD / 2;  -- Position for next start bit detection
			WAIT FOR 1 ns;  -- Small delta to avoid race conditions
		END LOOP;
	END PROCESS;

	--! @brief Test Stimulus Process
	--! @details Generates test stimulus by sending a test character to the SoC via UART.
	--! The process sequence:
	--! 1. Wait 200 ns for system initialization and reset release
	--! 2. Send test character (ASCII space, 0x20) via UART_SEND procedure
	--! 3. Wait 200 us for processor to receive, process, and respond
	--! 4. Report test completion and halt stimulus generation
	--!
	--! The long wait after transmission allows time for:
	--! - UART reception by SoC
	--! - Processor interrupt handling (if implemented)
	--! - Test program execution
	--! - Response transmission via UART TX
	--!
	--! For interactive testing, additional stimulus sequences can be added or modified.
	--! The test character (C_INPUT_DATA) can be changed to test different inputs.
	P_STIM : PROCESS
	BEGIN
		WAIT FOR 200 ns;  -- System initialization delay

		REPORT "Test: Sending Input...";

		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		UART_SEND(C_INPUT_DATA, r_uart_rx);
		WAIT FOR 1000 us;  -- Allow time for processing and response
		REPORT "Test: Waiting for response...";
		WAIT FOR 1000 us;  -- Allow time for processing and response

		REPORT "Test: Simulation Complete.";
		WAIT;  -- Halt stimulus (RX monitor continues)
	END PROCESS;

END ARCHITECTURE behavioral;

