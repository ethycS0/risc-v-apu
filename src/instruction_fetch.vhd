LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_fetch_unit IS
	PORT (
		clk : IN STD_LOGIC;
		rst : IN STD_LOGIC;
		stall : IN STD_LOGIC;

		-- Control signal for selecting the next PC source
		i_pc_src : IN t_PcSrc;

		-- Address inputs from different pipeline stages
		i_branch_addr : IN STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
		i_jump_addr : IN STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0); 

		-- Memory Interface
		o_instr_addr : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
		i_instr_data : IN STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);

		-- Outputs 
		o_instruction : OUT STD_LOGIC_VECTOR(INSTRUCTION_WIDTH - 1 DOWNTO 0);
		o_pc : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
		o_pc_plus_4 : OUT STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0)
	);
END ENTITY instruction_fetch_unit;

ARCHITECTURE behavioral OF instruction_fetch_unit IS
	SIGNAL s_pc : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL s_pc_plus_4 : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL s_next_pc : STD_LOGIC_VECTOR(MEMORY_ADDR_WIDTH - 1 DOWNTO 0);
BEGIN
	o_instr_addr <= s_pc;
	o_instruction <= i_instr_data;
	o_pc <= s_pc;
	o_pc_plus_4 <= s_pc_plus_4;

        -- PC+4 Adder
	s_pc_plus_4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4);

        -- MUX from PC selection
	WITH i_pc_src SELECT
		s_next_pc <= s_pc_plus_4 WHEN PC_SRC_PC4,
		i_branch_addr WHEN PC_SRC_BRANCH,
		i_jump_addr WHEN PC_SRC_JUMP,
		s_pc WHEN OTHERS; 

	-- Sequential logic for updating the PC register
	pc_logic : PROCESS (clk, rst)
	BEGIN
		IF rst = '1' THEN
			s_pc <= RESET_ADDRESS;
		ELSIF rising_edge(clk) THEN
			IF stall = '0' THEN
				s_pc <= s_next_pc;
			END IF;
		END IF;
	END PROCESS pc_logic;

END ARCHITECTURE behavioral;

