LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY soc IS
	GENERIC (
		G_CLK_FREQ : INTEGER := 27_000_000;
		G_BAUDRATE : INTEGER := 115200;
		G_RAM_SIZE : INTEGER := 2048
	);
	PORT (
		clk : IN STD_LOGIC;

		uart_rx : IN  STD_LOGIC;
		uart_tx : OUT STD_LOGIC
	);
END ENTITY soc;

ARCHITECTURE structural OF soc IS

	COMPONENT core IS
		PORT (
			i_clk           : IN  STD_LOGIC;
			i_rst           : IN  STD_LOGIC;
			o_instr_addr    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_instr_data    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_data_write_en : OUT STD_LOGIC;
			o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
		);
	END COMPONENT core;

	COMPONENT unified_memory_unit IS
		GENERIC (
			G_MEM_SIZE : INTEGER := 2048
		);
		PORT (
			i_clk           : IN  STD_LOGIC;
			i_imem_addr     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_imem_data     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_dmem_addr     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_dmem_wdata    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_dmem_rdata    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_dmem_write_en : IN  STD_LOGIC;
			i_dmem_byte_en  : IN  STD_LOGIC_VECTOR(3 DOWNTO 0)
		);
	END COMPONENT unified_memory_unit;

	COMPONENT uart IS
		GENERIC (
			G_CLK : INTEGER := 27_000_000;
			G_BAUDRATE : INTEGER := 115200
		);
		PORT (
			i_clk      : IN  STD_LOGIC;
			i_rst      : IN  STD_LOGIC;
			i_data     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			i_tx_new   : IN  STD_LOGIC;
			o_tx_ready : OUT STD_LOGIC;
			o_rx_new   : OUT STD_LOGIC;
			o_data     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			i_rx       : IN  STD_LOGIC;
			o_tx       : OUT STD_LOGIC
		);
	END COMPONENT uart;

	SIGNAL s_instr_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_instr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_rdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_wdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_data_write_en : STD_LOGIC;
	SIGNAL s_data_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);

	SIGNAL s_mem_rdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mem_write_en : STD_LOGIC;

	SIGNAL s_uart_tx_ready : STD_LOGIC;
	SIGNAL s_uart_tx_start : STD_LOGIC;

	SIGNAL s_uart_rx_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL s_uart_rx_new : STD_LOGIC;
	SIGNAL r_rx_data_valid : STD_LOGIC := '0';
	SIGNAL r_rx_byte_buf : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL s_clear_rx_flag : STD_LOGIC;

	SIGNAL rst : STD_LOGIC := '1';
	SIGNAL por_counter : UNSIGNED(21 DOWNTO 0) := (OTHERS => '0');
	CONSTANT POR_CYCLES : UNSIGNED(21 DOWNTO 0) := TO_UNSIGNED(2_700_000, 22);

BEGIN

	P_POR : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF por_counter < POR_CYCLES THEN
				por_counter <= por_counter + 1;
				rst <= '1';
			ELSE
				rst <= '0';
			END IF;
		END IF;
	END PROCESS P_POR;

	U_CORE : core
	PORT MAP(
		i_clk => clk,
		i_rst => rst,

		o_instr_addr => s_instr_addr,
		i_instr_data => s_instr_data,

		o_data_addr     => s_data_addr,
		i_data_read     => s_data_rdata,
		o_data_write    => s_data_wdata,
		o_data_write_en => s_data_write_en,
		o_data_byte_en  => s_data_byte_en
	);

	U_MEMORY : unified_memory_unit
	GENERIC MAP(
		G_MEM_SIZE => G_RAM_SIZE
	)
	PORT MAP(
		i_clk => clk,

		i_imem_addr => s_instr_addr,
		o_imem_data => s_instr_data,

		i_dmem_addr     => s_data_addr,
		i_dmem_wdata    => s_data_wdata,
		o_dmem_rdata    => s_mem_rdata,
		i_dmem_write_en => s_mem_write_en,
		i_dmem_byte_en  => s_data_byte_en
	);

	U_UART : uart
	GENERIC MAP(
		G_CLK => G_CLK_FREQ,
		G_BAUDRATE => G_BAUDRATE
	)
	PORT MAP(
		i_clk => clk,
		i_rst => rst,

		i_rx => uart_rx,
		o_tx => uart_tx,

		i_data     => s_data_wdata(7 DOWNTO 0),
		i_tx_new   => s_uart_tx_start,
		o_tx_ready => s_uart_tx_ready,

		o_data   => s_uart_rx_data,
		o_rx_new => s_uart_rx_new
	);

	P_RX_INTERFACE : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF rst = '1' THEN
				r_rx_data_valid <= '0';
				r_rx_byte_buf <= (OTHERS => '0');
			ELSE
				IF s_uart_rx_new = '1' THEN
					r_rx_byte_buf <= s_uart_rx_data;
					r_rx_data_valid <= '1';
				ELSIF s_clear_rx_flag = '1' THEN
					r_rx_data_valid <= '0';
				END IF;
			END IF;
		END IF;
	END PROCESS;

	P_BUS_INTRCON : PROCESS (s_data_addr, s_data_write_en, s_data_wdata,
		s_mem_rdata, r_rx_byte_buf, r_rx_data_valid, s_uart_tx_ready)
	BEGIN
		s_mem_write_en <= '0';
		s_uart_tx_start <= '0';
		s_clear_rx_flag <= '0';
		s_data_rdata <= (OTHERS => '0');

		IF unsigned(s_data_addr) < x"0000_2000" THEN
			s_mem_write_en <= s_data_write_en;
			s_data_rdata <= s_mem_rdata;

		ELSIF s_data_addr = x"8000_0000" THEN
			IF s_data_write_en = '1' THEN
				s_uart_tx_start <= '1';
			ELSE
				s_data_rdata(7 DOWNTO 0) <= r_rx_byte_buf;
				s_clear_rx_flag <= '1';
			END IF;

		ELSIF s_data_addr = x"8000_0004" THEN
			s_data_rdata(0) <= s_uart_tx_ready;
			s_data_rdata(1) <= r_rx_data_valid;

		END IF;
	END PROCESS;

END ARCHITECTURE structural;

