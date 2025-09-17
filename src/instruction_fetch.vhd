LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY instruction_fetch IS
    PORT (
        clk : IN std_logic;
        rst : IN std_logic;
        branch_en : IN std_logic;
        branch_addr : IN std_logic_vector(31 downto 0);
        instruction : OUT std_logic_vector(31 downto 0)
    );
end instruction_fetch;


ARCHITECTURE behavioral OF instruction_fetch IS
    SIGNAL PC : std_logic_vector(31 downto 0) := (OTHERS => '0');

    TYPE memory_array is ARRAY(0 to 255) OF std_logic_vector(31 downto 0);
    SIGNAL instr_mem : memory_array := (OTHERS => (OTHERS => '0'));
BEGIN
   
   PROCESS(clk, rst)
   BEGIN
      IF rst = '1' THEN
          PC <= (OTHERS => '0');
      ELSIF rising_edge(clk) THEN
          IF branch_en = '1' THEN
               PC <= branch_addr;
          ELSE
            PC <= std_logic_vector(unsigned(PC) + 4);  -- RISC-V instruction
          END IF;
      END IF;
    END PROCESS;

    instruction <= instr_mem(to_integer(unsigned(PC(9 downto 2))));

END ARCHITECTURE behavioral;