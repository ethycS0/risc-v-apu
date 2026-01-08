--! @file uart.vhd
--! UART Transceiver
--! @author ethycS
--! @details This module implements a full-duplex UART (Universal Asynchronous
--! Receiver/Transmitter) with configurable clock frequency and baud rate. It supports
--! 8-bit data transfer with no parity and 1 stop bit (8N1 format).
--!
--! Features:
--! - Configurable baud rate via generics (default 115200)
--! - Independent TX and RX state machines for full-duplex operation
--! - Two-stage synchronizer on RX input for metastability protection
--! - Mid-bit sampling for RX to improve noise immunity
--! - Ready/valid handshaking on TX interface
--! - New data flag on RX interface
--!
--! TX operation:
--! - Assert i_tx_new with data on i_data when o_tx_ready is high
--! - Module transmits: start bit (0), 8 data bits (LSB first), stop bit (1)
--! - o_tx_ready deasserts during transmission, reasserts when complete
--!
--! RX operation:
--! - Module monitors i_rx line for falling edge (start bit)
--! - Samples data bits at mid-bit time for noise rejection
--! - Asserts o_rx_new for one cycle when valid byte received
--! - Data available on o_data when o_rx_new is high

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY uart IS
	GENERIC (
		G_CLK      : INTEGER := 27_000_000; --! System clock frequency in Hz (default 27 MHz)
		G_BAUDRATE : INTEGER := 115200      --! UART baud rate in bits per second (default 115200)
	);
	PORT (
		i_clk : IN STD_LOGIC; --! System clock
		i_rst : IN STD_LOGIC; --! Synchronous reset (Active High)

		i_data     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); --! Transmit data byte (sampled when i_tx_new asserted)
		i_tx_new   : IN  STD_LOGIC;                    --! Transmit request (start new transmission)
		o_tx_ready : OUT STD_LOGIC;                    --! Transmitter ready flag (high when idle, can accept new data)
		o_tx       : OUT STD_LOGIC;                    --! UART TX output line (serial data out)

		i_rx     : IN  STD_LOGIC;                    --! UART RX input line (serial data in)
		o_rx_new : OUT STD_LOGIC;                    --! Receive data valid flag (pulsed high for one cycle)
		o_data   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)  --! Received data byte (valid when o_rx_new is high)
	);
END ENTITY uart;

ARCHITECTURE behavioral OF uart IS

	CONSTANT c_clk_per_bit : INTEGER := ((G_CLK + G_BAUDRATE/2) / G_BAUDRATE); --! Clock cycles per UART bit period

	TYPE t_state IS (IDLE, TX_START, TX_DATA, TX_STOP);     --! TX state machine states
	TYPE r_state IS (IDLE, RX_START, RX_DATA, RX_STOP);     --! RX state machine states

	SIGNAL s_tx_state : t_state := IDLE; --! Current TX state
	SIGNAL s_rx_state : r_state := IDLE; --! Current RX state

	SIGNAL s_tx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); --! TX shift register (captured from i_data)
	SIGNAL s_tx_cnt     : INTEGER RANGE 0 TO c_clk_per_bit := 0;           --! TX clock divider counter (counts clocks per bit)
	SIGNAL s_tx_bit_idx : INTEGER RANGE 0 TO 7 := 0;                       --! TX bit index counter (0-7 for data bits)

	SIGNAL s_rx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); --! RX shift register (assembled received data)
	SIGNAL s_rx_cnt     : INTEGER RANGE 0 TO c_clk_per_bit := 0;           --! RX clock divider counter
	SIGNAL s_rx_bit_idx : INTEGER RANGE 0 TO 7 := 0;                       --! RX bit index counter (0-7 for data bits)
	SIGNAL r_rx_sync    : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";            --! Two-stage synchronizer for RX input (metastability filter)

BEGIN

	-- Output received data directly from shift register
	o_data <= s_rx_data;

	--! @brief Transmit State Machine Process
	--! @details Synchronous process that implements the UART TX state machine. The
	--! machine sequences through five states to transmit an 8N1 serial frame:
	--!
	--! - IDLE: Wait for i_tx_new assertion, capture i_data into shift register
	--! - TX_START: Transmit start bit (logic 0) for one bit period
	--! - TX_DATA: Transmit 8 data bits LSB-first, one per bit period
	--! - TX_STOP: Transmit stop bit (logic 1) for one bit period
	--!
	--! Timing is controlled by s_tx_cnt, which counts system clocks per bit period
	--! (c_clk_per_bit). The o_tx_ready flag indicates when the transmitter can accept
	--! new data.
	P_TX : PROCESS (i_clk, i_rst)
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				s_tx_state <= IDLE;
				o_tx <= '1';
				o_tx_ready <= '1';
				s_tx_cnt <= 0;
				s_tx_bit_idx <= 0;
				s_tx_data <= (OTHERS => '0');
			ELSE

				CASE s_tx_state IS

					WHEN IDLE =>  -- Wait for transmission request
						o_tx <= '1';
						o_tx_ready <= '1';
						s_tx_cnt <= 0;
						s_tx_bit_idx <= 0;

						IF i_tx_new = '1' THEN
							s_tx_data <= i_data;  -- Capture input data
							s_tx_state <= TX_START;
							o_tx_ready <= '0';
						END IF;

					WHEN TX_START =>  -- Transmit start bit (0)
						o_tx <= '0';

						IF s_tx_cnt < c_clk_per_bit - 1 THEN
							s_tx_cnt <= s_tx_cnt + 1;
						ELSE
							s_tx_cnt <= 0;
							s_tx_state <= TX_DATA;
						END IF;

					WHEN TX_DATA =>  -- Transmit 8 data bits (LSB first)
						o_tx <= s_tx_data(s_tx_bit_idx);

						IF s_tx_cnt < c_clk_per_bit - 1 THEN
							s_tx_cnt <= s_tx_cnt + 1;
						ELSE
							s_tx_cnt <= 0;
							IF s_tx_bit_idx < 7 THEN
								s_tx_bit_idx <= s_tx_bit_idx + 1;
							ELSE
								s_tx_bit_idx <= 0;
								s_tx_state <= TX_STOP;
							END IF;
						END IF;

					WHEN TX_STOP =>  -- Transmit stop bit (1)
						o_tx <= '1';

						IF s_tx_cnt < c_clk_per_bit - 1 THEN
							s_tx_cnt <= s_tx_cnt + 1;
						ELSE
							s_tx_cnt <= 0;
							s_tx_state <= IDLE;
						END IF;
				END CASE;
			END IF;
		END IF;
	END PROCESS P_TX;

	--! @brief RX Input Synchronizer Process
	--! @details Two-stage flip-flop synchronizer to prevent metastability on the
	--! asynchronous RX input. The input passes through two registers clocked by the
	--! system clock before being used by the RX state machine. This is essential for
	--! crossing clock domains safely (from external async UART clock to system clock).
	P_SYNC : PROCESS (i_clk)
	BEGIN
		IF rising_edge(i_clk) THEN
			r_rx_sync <= r_rx_sync(0) & i_rx;
		END IF;
	END PROCESS P_SYNC;

	--! @brief Receive State Machine Process
	--! @details Synchronous process that implements the UART RX state machine. The
	--! machine sequences through four states to receive an 8N1 serial frame:
	--!
	--! - IDLE: Monitor synchronized RX line for falling edge (start bit detection)
	--! - RX_START: Verify start bit by sampling at mid-bit time (noise rejection)
	--! - RX_DATA: Sample 8 data bits at mid-bit time, assemble into shift register
	--! - RX_STOP: Wait for stop bit duration, then assert o_rx_new and return to IDLE
	--!
	--! Mid-bit sampling: The RX_START state waits for half a bit period before
	--! verifying the start bit, and RX_DATA samples each bit at the center of its
	--! period. This improves noise immunity by avoiding sampling near bit transitions.
	--! The o_rx_new output pulses high for one cycle when a complete byte is received.
	P_RX : PROCESS (i_clk, i_rst)
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				s_rx_state <= IDLE;
				o_rx_new <= '0';
				s_rx_cnt <= 0;
				s_rx_bit_idx <= 0;
			ELSE
				o_rx_new <= '0';  -- Default: clear rx_new flag

				CASE s_rx_state IS

					WHEN IDLE =>  -- Wait for start bit (falling edge)
						s_rx_cnt <= 0;
						s_rx_bit_idx <= 0;
						IF r_rx_sync(1) = '0' THEN  -- Start bit detected
							s_rx_state <= RX_START;
						END IF;

					WHEN RX_START =>  -- Verify start bit at mid-bit time
						IF s_rx_cnt = (c_clk_per_bit / 2) THEN
							IF r_rx_sync(1) = '0' THEN      -- Start bit still low (valid)
								s_rx_cnt <= 0;
								s_rx_state <= RX_DATA;
							ELSE                            -- False start bit (glitch)
								s_rx_state <= IDLE;
							END IF;
						ELSE
							s_rx_cnt <= s_rx_cnt + 1;
						END IF;

					WHEN RX_DATA =>  -- Sample 8 data bits at mid-bit time
						IF s_rx_cnt < c_clk_per_bit - 1 THEN
							s_rx_cnt <= s_rx_cnt + 1;
						ELSE
							s_rx_cnt <= 0;
							s_rx_data(s_rx_bit_idx) <= r_rx_sync(1);  -- Sample bit at center

							IF s_rx_bit_idx < 7 THEN
								s_rx_bit_idx <= s_rx_bit_idx + 1;
							ELSE
								s_rx_state <= RX_STOP;
							END IF;
						END IF;

					WHEN RX_STOP =>  -- Wait for stop bit duration
						IF s_rx_cnt < c_clk_per_bit - 1 THEN
							s_rx_cnt <= s_rx_cnt + 1;
						ELSE
							o_rx_new <= '1';  -- Signal valid byte received
							s_rx_state <= IDLE;
						END IF;
				END CASE;
			END IF;
		END IF;
	END PROCESS P_RX;

END ARCHITECTURE behavioral;

