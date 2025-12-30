LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY uart IS
	GENERIC (
		G_CLK : INTEGER := 27_000_000;
		G_BAUDRATE : INTEGER := 115200
	);
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		i_data     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		i_tx_new   : IN  STD_LOGIC;
		o_tx_ready : OUT STD_LOGIC;

		o_rx_new : OUT STD_LOGIC;
		o_data   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

		i_rx : IN  STD_LOGIC;
		o_tx : OUT STD_LOGIC
	);
END ENTITY uart;

ARCHITECTURE behavioral OF uart IS
	CONSTANT c_clk_per_bit : INTEGER := (G_CLK / G_BAUDRATE);
	SIGNAL s_baud_tick : STD_LOGIC := '0';

	TYPE tx_state_t IS (IDLE, START_BIT, DATA_BITS, STOP_BIT);
	TYPE rx_state_t IS (IDLE, START_BIT, DATA_BITS, STOP_BIT);

	SIGNAL s_tx_state : tx_state_t := IDLE;
	SIGNAL s_rx_state : rx_state_t := IDLE;

	SIGNAL s_rx_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL s_tx_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

	SIGNAL r_rx_sync1 : STD_LOGIC := '1';
	SIGNAL r_rx_sync2 : STD_LOGIC := '1';

BEGIN

	o_data <= s_rx_data;

	P_BAUD : PROCESS (i_clk, i_rst)
		VARIABLE baud_count : INTEGER := 0;
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				baud_count := 0;
				s_baud_tick <= '0';
			ELSE
				IF baud_count = c_clk_per_bit - 1 THEN
					s_baud_tick <= '1';
					baud_count := 0;
				ELSE
					s_baud_tick <= '0';
					baud_count := baud_count + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS P_BAUD;

	P_TX : PROCESS (i_clk, i_rst)
		VARIABLE tx_bit_idx : INTEGER := 0;
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				s_tx_state <= IDLE;
				o_tx <= '1';
				o_tx_ready <= '1';
				tx_bit_idx := 0;
			ELSE
                                    IF s_tx_state = IDLE THEN
                                        o_tx_ready <= '1';
                                    ELSE
                                        o_tx_ready <= '0';
                                    END IF;

				IF s_baud_tick = '1' THEN
					CASE s_tx_state IS
						WHEN IDLE =>
							o_tx <= '1';

						WHEN START_BIT =>
							o_tx <= '0';
							s_tx_state <= DATA_BITS;
							tx_bit_idx := 0;

						WHEN DATA_BITS =>
							o_tx <= s_tx_data(tx_bit_idx);
							IF tx_bit_idx = 7 THEN
								tx_bit_idx := 0;
								s_tx_state <= STOP_BIT;
							ELSE
								tx_bit_idx := tx_bit_idx + 1;
							END IF;

						WHEN STOP_BIT =>
							o_tx <= '1';
							s_tx_state <= IDLE;
					END CASE;
				END IF;

				IF s_tx_state = IDLE AND i_tx_new = '1' THEN
					s_tx_data <= i_data;
					s_tx_state <= START_BIT;
					o_tx_ready <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS P_TX;

	P_RX : PROCESS (i_clk, i_rst)
		VARIABLE rx_bit_idx : INTEGER := 0;
		VARIABLE rx_baud_counter : INTEGER := 0;
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				rx_bit_idx := 0;
				rx_baud_counter := 0;
				o_rx_new <= '0';
				s_rx_state <= IDLE;
			ELSE
				o_rx_new <= '0';

				CASE s_rx_state IS
					WHEN IDLE =>
						rx_bit_idx := 0;
						rx_baud_counter := 0;
						IF r_rx_sync2 = '0' THEN
							s_rx_state <= START_BIT;
							rx_baud_counter := 0;
						END IF;

					WHEN START_BIT =>
						IF rx_baud_counter = (c_clk_per_bit / 2) - 1 THEN
							IF r_rx_sync2 = '0' THEN
								s_rx_state <= DATA_BITS;
								rx_baud_counter := 0;
								rx_bit_idx := 0;
							ELSE
								s_rx_state <= IDLE;
							END IF;
						ELSE
							rx_baud_counter := rx_baud_counter + 1;
						END IF;

					WHEN DATA_BITS =>
						IF rx_baud_counter = c_clk_per_bit - 1 THEN
							s_rx_data(rx_bit_idx) <= r_rx_sync2;
							rx_baud_counter := 0;

							IF rx_bit_idx = 7 THEN
								rx_bit_idx := 0;
								s_rx_state <= STOP_BIT;
							ELSE
								rx_bit_idx := rx_bit_idx + 1;
							END IF;
						ELSE
							rx_baud_counter := rx_baud_counter + 1;
						END IF;

					WHEN STOP_BIT =>
						IF rx_baud_counter = c_clk_per_bit - 1 THEN
							IF r_rx_sync2 = '1' THEN
								o_rx_new <= '1';
							END IF;
							s_rx_state <= IDLE;
						ELSE
							rx_baud_counter := rx_baud_counter + 1;
						END IF;
				END CASE;
			END IF;
		END IF;
	END PROCESS P_RX;

	P_SYNC : PROCESS (i_clk)
	BEGIN
		IF rising_edge(i_clk) THEN
			r_rx_sync1 <= i_rx;
			r_rx_sync2 <= r_rx_sync1;
		END IF;
	END PROCESS P_SYNC;

END ARCHITECTURE behavioral;

