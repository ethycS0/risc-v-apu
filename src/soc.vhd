--! @file soc.vhd
--! System-on-Chip Top Level
--! @author ethycS
--! @details This module implements the top-level System-on-Chip (SoC) integrating the
--! RV32I processor core, unified instruction/data memory, and UART peripheral with
--! memory-mapped I/O.
--!
--! System architecture:
--! - RV32I 5-stage pipelined processor core
--! - Unified memory (Harvard architecture with single memory array)
--! - UART peripheral for serial communication
--! - Memory-mapped I/O address space
--! - Power-on-reset (POR) generation circuit (Tang Primer 20K FPGA does not have IO easily accessible)
--!
--! Memory map:
--! - 0x00000000 - 0x((RAM_SIZE * 4) - 1): Main memory (code + data)
--! - 0x80000000: UART data register (read: RX data, write: TX data)
--! - 0x80000004: UART status register
--!   - Bit [0]: TX ready flag (1 = can transmit)
--!   - Bit [1]: RX data valid flag (1 = new byte received)
--!   - Write: Clear RX data valid flag
--!
--! UART interface:
--! - Write to 0x80000000: Initiates transmission of byte (if TX ready)
--! - Read from 0x80000000: Returns last received byte (latched)
--! - Write to 0x80000004: Clears RX data valid flag (acknowledge read)
--! - Read from 0x80000004: Returns TX ready and RX valid status bits
--!
--! The module includes debug outputs for RISCOF (RISC-V Compliance Framework)
--! verification, exposing data memory signals for external monitoring.
--!
--! Address decoding uses synchronous logic to match memory latency, with a
--! registered flag (r_access_was_io) to mux between memory and I/O read data.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY soc IS
	GENERIC (
		G_CLK_FREQ  : INTEGER := 27_000_000;    --! System clock frequency in Hz 
		G_BAUDRATE  : INTEGER := 921600;        --! UART baud rate in bps 
		G_RAM_SIZE  : INTEGER := 8192;          --! RAM size in 32-bit words 
		G_CODE_FILE : STRING  := "code.hex";    --! Path to initialization HEX file
		G_SIM       : BOOLEAN := FALSE          --! Simulation mode flag (TRUE for simulation)
	);
	PORT (
		clk : IN STD_LOGIC;  --! System clock input

                -- Comment for Synthesis
		-- o_debug_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Debug: Data memory address (for RISCOF)
		-- o_debug_data_wdata    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Debug: Data memory write data (for RISCOF)
		-- o_debug_data_write_en : OUT STD_LOGIC;                      --! Debug: Data memory write enable (for RISCOF)
		-- o_debug_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);   --! Debug: Data memory byte enable (for RISCOF)

		uart_rx : IN  STD_LOGIC;  --! UART receive input line
		uart_tx : OUT STD_LOGIC   --! UART transmit output line
	);
END ENTITY soc;

ARCHITECTURE structural OF soc IS

	--! RV32I processor core component declaration
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

	--! Unified instruction and data memory component declaration
	COMPONENT unified_memory_unit IS
		GENERIC (
			G_MEM_SIZE        : INTEGER := 8192;
			G_CODE            : STRING := "code.hex";
			G_SIMULATION_MODE : BOOLEAN := FALSE
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

	--! UART transceiver component declaration
	COMPONENT uart IS
		GENERIC (
			G_CLK      : INTEGER := 27_000_000;
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

	SIGNAL s_instr_addr    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Instruction memory address from core
	SIGNAL s_instr_data    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Instruction memory read data to core
	SIGNAL s_data_addr     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory address from core
	SIGNAL s_data_rdata    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory read data to core 
	SIGNAL s_data_wdata    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data memory write data from core
	SIGNAL s_data_byte_en  : STD_LOGIC_VECTOR(3 DOWNTO 0);  --! Data memory byte enable from core
	SIGNAL s_data_write_en : STD_LOGIC;                     --! Data memory write enable from core

	SIGNAL s_mem_write_en  : STD_LOGIC;                     --! Memory write enable (gated by address decode)
	SIGNAL s_mem_rdata     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory read data output (from RAM)

	SIGNAL s_uart_tx_ready : STD_LOGIC;                    --! UART TX ready flag (can accept new byte)
	SIGNAL s_uart_tx_start : STD_LOGIC;                    --! UART TX start signal (write to TX register)
	SIGNAL s_uart_rx_new   : STD_LOGIC;                    --! UART RX new data flag (pulse on byte received)
	SIGNAL s_clear_rx_flag : STD_LOGIC;                    --! Clear RX valid flag signal (write to status register)
	SIGNAL r_rx_data_valid : STD_LOGIC := '0';             --! Latched RX data valid flag (cleared by software)
	SIGNAL r_rx_byte_buf   : STD_LOGIC_VECTOR(7 DOWNTO 0); --! Latched RX byte buffer (holds last received byte)
	SIGNAL s_uart_rx_data  : STD_LOGIC_VECTOR(7 DOWNTO 0); --! UART RX data output (current received byte)

	SIGNAL r_access_was_io         : STD_LOGIC := '0';              --! Registered flag indicating I/O space access
	SIGNAL s_io_read_combinational : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Combinational I/O read data (address decoded)
	SIGNAL r_io_read_delayed       : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Registered I/O read data (matches memory latency)

	SIGNAL rst         : STD_LOGIC := '1';                --! System reset signal (active high)
	SIGNAL por_counter : UNSIGNED(21 DOWNTO 0) := (OTHERS => '0'); --! Power-on-reset counter

	CONSTANT POR_CYCLES       : UNSIGNED(21 DOWNTO 0) := TO_UNSIGNED(10, 22);               --! Number of POR clock cycles 
	CONSTANT C_RAM_BYTE_LIMIT : unsigned(31 DOWNTO 0) := to_unsigned(G_RAM_SIZE * 4, 32);   --! RAM address upper limit 

BEGIN

	--! @brief Power-On-Reset Generation Process
	--! @details Synchronous process that generates a power-on-reset pulse for the system.
	--! The reset signal remains asserted for POR_CYCLES clock cycles after power-up,
	--! allowing clocks to stabilize and ensuring all sequential logic initializes properly.
	--! After the counter reaches POR_CYCLES, the reset is deasserted and the system begins
	--! normal operation. The 10-cycle minimum reset ensures reliable startup across process,
	--! voltage, and temperature variations.
	P_POR : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF por_counter < POR_CYCLES THEN
				por_counter <= por_counter + 1;
				rst <= '1';  -- Assert reset during POR period
			ELSE
				rst <= '0';  -- Deassert reset after POR complete
			END IF;
		END IF;
	END PROCESS P_POR;

	--! @brief RV32I Processor Core Instance
	--! @details Instantiates the 5-stage pipelined RISC-V core with Harvard architecture
	--! interfaces to instruction and data memory. The core handles instruction fetch,
	--! decode, execution, memory access, and writeback operations.
	U_CORE : core
	PORT MAP(
		i_clk           => clk,
		i_rst           => rst,
		o_instr_addr    => s_instr_addr,
		i_instr_data    => s_instr_data,
		o_data_addr     => s_data_addr,
		i_data_read     => s_data_rdata,
		o_data_write    => s_data_wdata,
		o_data_write_en => s_data_write_en,
		o_data_byte_en  => s_data_byte_en
	);

	--! @brief Unified Memory Instance
	--! @details Instantiates the dual-port memory serving both instruction and data
	--! interfaces. The memory is initialized from a HEX file at elaboration time and
	--! supports byte-granular writes on the data port. Generics are passed through from
	--! the SoC level to allow flexible configuration.
	U_MEMORY : unified_memory_unit
	GENERIC MAP(
		G_MEM_SIZE        => G_RAM_SIZE,
		G_CODE            => G_CODE_FILE,
		G_SIMULATION_MODE => G_SIM
	)
	PORT MAP(
		i_clk           => clk,
		i_imem_addr     => s_instr_addr,
		o_imem_data     => s_instr_data,
		i_dmem_addr     => s_data_addr,
		i_dmem_wdata    => s_data_wdata,
		o_dmem_rdata    => s_mem_rdata,
		i_dmem_write_en => s_mem_write_en,
		i_dmem_byte_en  => s_data_byte_en
	);

	--! @brief UART Peripheral Instance
	--! @details Instantiates the UART transceiver with configurable baud rate. The UART
	--! is connected to memory-mapped registers for software control. TX data comes from
	--! the lower 8 bits of write data, and RX data is latched in the RX interface logic.
	U_UART : uart
	GENERIC MAP(
		G_CLK      => G_CLK_FREQ,
		G_BAUDRATE => G_BAUDRATE
	)
	PORT MAP(
		i_clk      => clk,
		i_rst      => rst,
		i_rx       => uart_rx,
		o_tx       => uart_tx,
		i_data     => s_data_wdata(7 DOWNTO 0),
		i_tx_new   => s_uart_tx_start,
		o_tx_ready => s_uart_tx_ready,
		o_data     => s_uart_rx_data,
		o_rx_new   => s_uart_rx_new
	);

	--! @brief UART RX Interface Logic Process
	--! @details Synchronous process that manages the UART receive data buffer and valid
	--! flag. When the UART receives a new byte (s_uart_rx_new pulse), the data is latched
	--! into r_rx_byte_buf and the valid flag is set. The valid flag remains set until
	--! software acknowledges the read by writing to the status register (0x80000004),
	--! which asserts s_clear_rx_flag. This prevents data loss if software is slow to
	--! read received bytes, as the buffer holds the last byte until acknowledged.
	P_RX_INTERFACE : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF rst = '1' THEN
				r_rx_data_valid <= '0';
				r_rx_byte_buf <= (OTHERS => '0');
			ELSE
				IF s_clear_rx_flag = '1' THEN
					r_rx_data_valid <= '0';  -- Software acknowledgment clears flag
				END IF;

				IF s_uart_rx_new = '1' THEN
					r_rx_byte_buf <= s_uart_rx_data;  -- Latch new received byte
					r_rx_data_valid <= '1';           -- Set valid flag
				END IF;
			END IF;
		END IF;
	END PROCESS;

	--! @brief Memory-Mapped Write Decode Process
	--! @details Combinational process that decodes write operations to memory vs I/O space.
	--! Address ranges:
	--! - 0x00000000 to (RAM_SIZE*4-1): RAM write (s_mem_write_en asserted)
	--! - 0x80000000: UART TX data register (s_uart_tx_start pulsed if TX ready)
	--! - 0x80000004: UART status register (write clears RX valid flag)
	--!
	--! The write decode ensures only one destination is activated per transaction. UART
	--! TX writes are gated by the TX ready flag to prevent data loss when the transmitter
	--! is busy. All I/O writes are single-cycle operations (no multi-cycle handshaking).
	P_WRITE_LOGIC : PROCESS (s_data_addr, s_data_write_en, s_uart_tx_ready)
	BEGIN
		s_mem_write_en <= '0';
		s_uart_tx_start <= '0';
		s_clear_rx_flag <= '0';

		IF unsigned(s_data_addr) < C_RAM_BYTE_LIMIT THEN
			s_mem_write_en <= s_data_write_en;  -- RAM write

		ELSIF s_data_addr = x"8000_0000" THEN  -- UART TX data register
			IF s_data_write_en = '1' AND s_uart_tx_ready = '1' THEN
				s_uart_tx_start <= '1';  -- Initiate transmission
			END IF;

		ELSIF s_data_addr = x"8000_0004" THEN  -- UART status register
			IF s_data_write_en = '1' THEN
				s_clear_rx_flag <= '1';  -- Acknowledge RX read
			END IF;
		END IF;
	END PROCESS;

	--! @brief Memory-Mapped Read Decode Process (Combinational)
	--! @details Combinational process that generates I/O read data based on the data
	--! address. This process creates the read value immediately (combinationally) which
	--! is then registered in P_IO_READ_SYNC to match the memory read latency.
	--!
	--! I/O register reads:
	--! - 0x80000000: Returns latched RX data byte in bits [7:0], upper bits zero
	--! - 0x80000004: Returns status register:
	--!   - Bit [0]: TX ready flag (1 = can transmit)
	--!   - Bit [1]: RX data valid flag (1 = new byte available)
	--!   - Bits [31:2]: Reserved (return zero)
	--!
	--! For addresses outside I/O space, this process returns zero (ignored by mux).
	P_IO_READ_COMB : PROCESS (s_data_addr, r_rx_byte_buf, s_uart_tx_ready, r_rx_data_valid)
	BEGIN
		s_io_read_combinational <= (OTHERS => '0');

		IF s_data_addr = x"8000_0000" THEN  -- UART RX data register
			s_io_read_combinational(7 DOWNTO 0) <= r_rx_byte_buf;

		ELSIF s_data_addr = x"8000_0004" THEN  -- UART status register
			s_io_read_combinational(0) <= s_uart_tx_ready;   -- TX ready
			s_io_read_combinational(1) <= r_rx_data_valid;   -- RX valid
		END IF;
	END PROCESS;

	--! @brief Memory-Mapped Read Synchronization Process
	--! @details Synchronous process that registers I/O read data and address decode
	--! flag to match the one-cycle latency of RAM reads. The r_access_was_io flag
	--! captures whether the current address targets I/O space, and this flag is used
	--! in the next cycle to select between registered I/O data and RAM data.
	--!
	--! This synchronization ensures consistent timing between RAM and I/O reads from
	--! the processor's perspective - all reads complete in one cycle after the address
	--! is presented. Without this registration, I/O reads would appear instantaneous
	--! while RAM reads take a cycle, creating timing hazards.
	P_IO_READ_SYNC : PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			r_io_read_delayed <= s_io_read_combinational;  -- Register I/O read data
			IF unsigned(s_data_addr) >= C_RAM_BYTE_LIMIT THEN
				r_access_was_io <= '1';  -- Mark as I/O access
			ELSE
				r_access_was_io <= '0';  -- Mark as RAM access
			END IF;
		END IF;
	END PROCESS;

	-- Mux between I/O and RAM read data based on registered access type
	s_data_rdata <= r_io_read_delayed WHEN r_access_was_io = '1' ELSE s_mem_rdata;

        -- Comment for Synthesis
	-- Debug outputs for RISCOF verification (expose data memory signals)
	-- o_debug_data_addr     <= s_data_addr;
	-- o_debug_data_wdata    <= s_data_wdata;
	-- o_debug_data_write_en <= s_data_write_en;
	-- o_debug_data_byte_en  <= s_data_byte_en;

END ARCHITECTURE structural;

