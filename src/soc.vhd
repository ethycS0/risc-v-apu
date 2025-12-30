LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY soc IS 
        PORT(
                i_clk : IN STD_LOGIC;
                i_rst : IN STD_LOGIC;

                o_uart_tx : OUT STD_LOGIC;
                i_uart_rx : IN STD_LOGIC
            );
END ENTITY soc;

ARCHITECTURE structural OF soc IS  
            TYPE imem_type IS ARRAY(0 TO 1023) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
            TYPE dmem_type IS ARRAY(0 TO 1023) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
            SIGNAL dmem : dmem_type := (OTHERS => x"00000000");
BEGIN

END ARCHITECTURE structural;
