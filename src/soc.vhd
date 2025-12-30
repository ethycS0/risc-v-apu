LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY soc IS
    PORT (
        clk     : IN  STD_LOGIC;
        uart_rx : IN  STD_LOGIC;
        uart_tx : OUT STD_LOGIC
    );
END ENTITY soc;

ARCHITECTURE structural OF soc IS

    -- SIGNALS
    SIGNAL rst_counter : unsigned(7 downto 0) := (others => '0');
    SIGNAL sys_rst     : std_logic := '1';

    SIGNAL cpu_instr_addr  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpu_instr_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpu_data_addr   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpu_data_read   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpu_data_write  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cpu_write_en    : STD_LOGIC;
    SIGNAL cpu_byte_en     : STD_LOGIC_VECTOR(3 DOWNTO 0);

    SIGNAL uart_tx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL uart_tx_valid   : STD_LOGIC := '0';
    SIGNAL uart_tx_ready   : STD_LOGIC;
    SIGNAL uart_rx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0); 
    SIGNAL uart_rx_new     : STD_LOGIC;                   

    -- Small Data Memory (Using registers/LUTs to be safe)
    TYPE dmem_type IS ARRAY(0 TO 63) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dmem : dmem_type := (OTHERS => x"00000000");

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

BEGIN

    -- 1. POR
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst_counter < x"FF" THEN
                rst_counter <= rst_counter + 1;
                sys_rst <= '1';
            ELSE
                sys_rst <= '0';
            END IF;
        END IF;
    END PROCESS;

    -- 2. CORE
    U_CORE : core
    PORT MAP(
        i_clk           => clk,
        i_rst           => sys_rst,
        o_instr_addr    => cpu_instr_addr,
        i_instr_data    => cpu_instr_data,
        o_data_addr     => cpu_data_addr,
        i_data_read     => cpu_data_read,
        o_data_write    => cpu_data_write,
        o_data_write_en => cpu_write_en,
        o_data_byte_en  => cpu_byte_en
    );

    -- 3. UART
    U_UART : uart
    GENERIC MAP (
        G_CLK      => 27_000_000,
        G_BAUDRATE => 115200
    )
    PORT MAP (
        i_clk      => clk,
        i_rst      => sys_rst,
        i_data     => uart_tx_data,
        i_tx_new   => uart_tx_valid,
        o_tx_ready => uart_tx_ready,
        o_rx_new   => uart_rx_new,
        o_data     => uart_rx_data,
        i_rx       => uart_rx,
        o_tx       => uart_tx
    );

    -- 4. HARDCODED ROM (Combinational Instruction Fetch)
    -- This guarantees Logic (LUT) implementation, avoiding BRAM timing issues.
    PROCESS(cpu_instr_addr)
    BEGIN
        -- Look at the lower 8 bits of the address (Byte Address)
        CASE cpu_instr_addr(7 DOWNTO 0) IS
            
            -- 0x00: lui x15, 0x20000 (Result: x15 = 0x20000000)
            WHEN x"00" => cpu_instr_data <= x"200007B7";
            
            -- BUBBLES for Hazard avoidance
            WHEN x"04" => cpu_instr_data <= x"00000013"; -- nop
            WHEN x"08" => cpu_instr_data <= x"00000013"; -- nop
            WHEN x"0C" => cpu_instr_data <= x"00000013"; -- nop
            
            -- 0x10: li x10, 0x41 ('A')
            WHEN x"10" => cpu_instr_data <= x"04100513";
            
            -- BUBBLES
            WHEN x"14" => cpu_instr_data <= x"00000013"; -- nop
            WHEN x"18" => cpu_instr_data <= x"00000013"; -- nop
            WHEN x"1C" => cpu_instr_data <= x"00000013"; -- nop
            
            -- 0x20: sw x10, 0(x15) (Write 'A' to UART)
            WHEN x"20" => cpu_instr_data <= x"00A7A023";

            -- 0x24: jal x0, -4 (Infinite Loop: Stuck at 0x24)
            -- To prevent flooding, we just stop here.
            -- If you see ONE 'A', it worked.
            WHEN x"24" => cpu_instr_data <= x"FFDFF06F"; 

            -- Default: NOP
            WHEN OTHERS => cpu_instr_data <= x"00000013";
        END CASE;
    END PROCESS;


    -- 5. DATA READ MUX (Combinational)
    PROCESS(cpu_data_addr, dmem, uart_rx_data, uart_tx_ready)
        VARIABLE addr_int : INTEGER;
    BEGIN
        addr_int := to_integer(unsigned(cpu_data_addr(7 DOWNTO 2))); -- Reduced size
        cpu_data_read <= (OTHERS => '0'); 

        IF cpu_data_addr(31 DOWNTO 12) = x"20000" THEN
            CASE cpu_data_addr(11 DOWNTO 0) IS
                WHEN x"000" => cpu_data_read <= x"000000" & uart_rx_data;
                WHEN x"004" => cpu_data_read <= x"0000000" & "000" & uart_tx_ready;
                WHEN OTHERS => cpu_data_read <= (OTHERS => '0');
            END CASE;
        ELSIF addr_int < 64 THEN
            cpu_data_read <= dmem(addr_int);
        END IF;
    END PROCESS;

    -- 6. WRITE LOGIC
    P_MEM_WRITE : PROCESS (clk)
        VARIABLE dmem_addr_int : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            uart_tx_valid <= '0'; 

            IF cpu_write_en = '1' THEN
                IF cpu_data_addr(31 DOWNTO 12) = x"20000" THEN
                    -- UART WRITE
                    uart_tx_data  <= cpu_data_write(7 DOWNTO 0);
                    uart_tx_valid <= '1';
                ELSE
                    -- RAM WRITE (Small)
                    dmem_addr_int := to_integer(unsigned(cpu_data_addr(7 DOWNTO 2)));
                    IF dmem_addr_int < 64 THEN
                         -- Simplified write for test (ignore byte enables for now)
                         dmem(dmem_addr_int) <= cpu_data_write;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE structural;
