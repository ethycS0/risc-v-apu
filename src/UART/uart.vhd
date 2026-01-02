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
		o_tx       : OUT STD_LOGIC;

		i_rx     : IN  STD_LOGIC;
		o_rx_new : OUT STD_LOGIC;
		o_data   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END ENTITY uart;

ARCHITECTURE behavioral OF uart IS
	CONSTANT c_clk_per_bit : INTEGER := (G_CLK / G_BAUDRATE);

	TYPE t_state IS (IDLE, TX_START, TX_DATA, TX_STOP, CLEANUP);
	SIGNAL s_tx_state : t_state := IDLE;

	SIGNAL s_tx_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL s_tx_bit_idx : INTEGER RANGE 0 TO 7 := 0;
	SIGNAL s_tx_cnt : INTEGER RANGE 0 TO c_clk_per_bit := 0;

	TYPE r_state IS (IDLE, RX_START, RX_DATA, RX_STOP);
	SIGNAL s_rx_state : r_state := IDLE;
	SIGNAL s_rx_cnt : INTEGER RANGE 0 TO c_clk_per_bit := 0;
	SIGNAL s_rx_bit_idx : INTEGER RANGE 0 TO 7 := 0;
	SIGNAL s_rx_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_rx_sync : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";

BEGIN
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

					WHEN IDLE =>
						o_tx <= '1';
						o_tx_ready <= '1';
						s_tx_cnt <= 0;
						s_tx_bit_idx <= 0;

						IF i_tx_new = '1' THEN
							s_tx_data <= i_data;
							s_tx_state <= TX_START;
							o_tx_ready <= '0';
						END IF;

					WHEN TX_START =>
						o_tx <= '0';

						IF s_tx_cnt < c_clk_per_bit - 1 THEN
							s_tx_cnt <= s_tx_cnt + 1;
						ELSE
							s_tx_cnt <= 0;
							s_tx_state <= TX_DATA;
						END IF;

					WHEN TX_DATA =>
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

					WHEN TX_STOP =>
						o_tx <= '1';

						IF s_tx_cnt < c_clk_per_bit - 1 THEN
							s_tx_cnt <= s_tx_cnt + 1;
						ELSE
							s_tx_cnt <= 0;
							s_tx_state <= CLEANUP;
						END IF;

					WHEN CLEANUP =>
						o_tx_ready <= '1';
						IF i_tx_new = '0' THEN
							s_tx_state <= IDLE;
						END IF;

				END CASE;
			END IF;
		END IF;
	END PROCESS P_TX;

	P_SYNC : PROCESS (i_clk)
	BEGIN
		IF rising_edge(i_clk) THEN
			r_rx_sync <= r_rx_sync(0) & i_rx;
		END IF;
	END PROCESS P_SYNC;

	o_data <= s_rx_data;

	P_RX : PROCESS (i_clk, i_rst)
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_rst = '1' THEN
				s_rx_state <= IDLE;
				o_rx_new <= '0';
				s_rx_cnt <= 0;
				s_rx_bit_idx <= 0;
                        ELSE
				o_rx_new <= '0';

				CASE s_rx_state IS
					WHEN IDLE =>
						s_rx_cnt <= 0;
						s_rx_bit_idx <= 0;
						IF r_rx_sync(1) = '0' THEN
							s_rx_state <= RX_START;
						END IF;

					WHEN RX_START =>
						IF s_rx_cnt = (c_clk_per_bit / 2) THEN
							IF r_rx_sync(1) = '0' THEN
								s_rx_cnt <= 0;
								s_rx_state <= RX_DATA;
							ELSE
								s_rx_state <= IDLE;
							END IF;
						ELSE
							s_rx_cnt <= s_rx_cnt + 1;
						END IF;

					WHEN RX_DATA =>
						IF s_rx_cnt < c_clk_per_bit - 1 THEN
							s_rx_cnt <= s_rx_cnt + 1;
						ELSE
							s_rx_cnt <= 0;
							s_rx_data(s_rx_bit_idx) <= r_rx_sync(1);

							IF s_rx_bit_idx < 7 THEN
								s_rx_bit_idx <= s_rx_bit_idx + 1;
							ELSE
								s_rx_state <= RX_STOP;
							END IF;
						END IF;

					WHEN RX_STOP =>
						IF s_rx_cnt < c_clk_per_bit - 1 THEN
							s_rx_cnt <= s_rx_cnt + 1;
						ELSE
							o_rx_new <= '1';
							s_rx_state <= IDLE;
						END IF;
				END CASE;
			END IF;
		END IF;
	END PROCESS P_RX;

END ARCHITECTURE behavioral;

