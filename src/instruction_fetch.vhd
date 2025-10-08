LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY instruction_fetch_unit IS
	GENERIC (
		ADDR_WIDTH : INTEGER := 32;
		INSTRUCTION_WIDTH : INTEGER := 32;
		RESET_ADDRESS : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0')
        );

        PORT (
                clk : IN std_logic;
                rst : IN std_logic;

                instr_addr : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
                instr_data : IN std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
                branch_address : IN std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);

                instruction : OUT std_logic_vector(INSTRUCTION_WIDTH - 1 DOWNTO 0);
                pc_out : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
                pc_plus_4 : OUT std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);

                branch : IN std_logic;
                stall : IN std_logic
        );

END ENTITY instruction_fetch_unit;

ARCHITECTURE behavioral OF instruction_fetch_unit IS
        SIGNAL pc : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
        SIGNAL pc_increment : std_logic_vector(ADDR_WIDTH - 1 DOWNTO 0);
BEGIN
        instr_addr <= pc;
        instruction <= instr_data;
        pc_out <= pc;
        pc_plus_4 <= pc_increment;
        pc_increment <= std_logic_vector(unsigned(pc) + 4);

        pc_logic : PROCESS (clk, rst)
        BEGIN
            IF rst = '1' THEN
                pc <= RESET_ADDRESS;
            ELSIF rising_edge(clk) THEN
                IF stall = '0' THEN 
                    IF branch = '1' THEN
                        pc <= branch_address;
                    ELSE
                        pc <= pc_increment;
                    END IF;
                END IF;
            END IF;
        END PROCESS pc_logic;

END ARCHITECTURE behavioral;
