LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY alu IS
	PORT (
		i_alu_opcode : IN t_AluOpcodes;
		i_alu_x : IN std_logic_vector(31 DOWNTO 0);
		i_alu_y : IN std_logic_vector(31 DOWNTO 0);

		o_result : OUT std_logic_vector(31 DOWNTO 0);
		o_flags : OUT t_AluFlags
	);

END ENTITY alu;

ARCHITECTURE behavioral OF alu IS
	-- Internal signals for the adder/subtractor
	SIGNAL adder_b_operand : std_logic_vector(31 DOWNTO 0);
	SIGNAL adder_carry_in : std_logic;
	SIGNAL extended_adder_result : std_logic_vector(32 DOWNTO 0); -- Extended to capture carry-out

	-- Internal signals for results of different functional units
	SIGNAL adder_result : std_logic_vector(31 DOWNTO 0);
	SIGNAL logic_result : std_logic_vector(31 DOWNTO 0);
	SIGNAL shifter_result : std_logic_vector(31 DOWNTO 0);
	SIGNAL slt_result : std_logic_vector(31 DOWNTO 0);
        SIGNAL adder_carry_term : signed(32 DOWNTO 0);

        SIGNAL internal_flags : t_AluFlags;

BEGIN
        -- Adder Implementation for ADD | SUB | SLT | SLTU
	adder_carry_in <= '1' WHEN (i_alu_opcode = ALU_SUB) OR (i_alu_opcode = ALU_SLT) OR (i_alu_opcode = ALU_SLTU) ELSE '0';
	adder_b_operand <= i_alu_y XOR (31 DOWNTO 0 => adder_carry_in);
        adder_carry_term <= to_signed(1, 33) WHEN adder_carry_in = '1' ELSE to_signed(0, 33);

        extended_adder_result <= std_logic_vector( ('0' & signed(i_alu_x)) + ('0' & signed(adder_b_operand)) + adder_carry_term );
	adder_result <= extended_adder_result(31 DOWNTO 0);

        internal_flags.carry    <= extended_adder_result(32);
        internal_flags.overflow <= extended_adder_result(32) XOR extended_adder_result(31); 
        internal_flags.negative <= adder_result(31);
        internal_flags.zero     <= '1' WHEN adder_result = (31 DOWNTO 0 => '0') ELSE '0';

        -- Logic Implementation for XOR | OR | AND
	logic_operation : PROCESS (i_alu_opcode, i_alu_x, i_alu_y)
	BEGIN
		CASE i_alu_opcode IS
			WHEN ALU_XOR => logic_result <= i_alu_x XOR i_alu_y;
			WHEN ALU_OR => logic_result <= i_alu_x OR i_alu_y;
			WHEN ALU_AND => logic_result <= i_alu_x AND i_alu_y;
			WHEN OTHERS => logic_result <= (OTHERS => '0');
		END CASE;
	END PROCESS;

        -- Shift Implementation for SLL | SRL | SRA
	shifter_result <= std_logic_vector(shift_left(unsigned(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SLL ELSE
	                  std_logic_vector(shift_right(unsigned(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SRL ELSE
	                  std_logic_vector(shift_right(signed(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SRA ELSE
	                  (OTHERS => '0');

        -- SLT|U Implementation 
	slt_result <= (31 DOWNTO 1 => '0') & (internal_flags.negative XOR internal_flags.overflow) WHEN i_alu_opcode = ALU_SLT ELSE
	              (31 DOWNTO 1 => '0') & (NOT internal_flags.carry) WHEN i_alu_opcode = ALU_SLTU ELSE
	              (OTHERS => '0');

	-- Final Multiplexer
	final_mux : PROCESS (i_alu_opcode, adder_result, logic_result, shifter_result, slt_result, i_alu_y)
	BEGIN
		CASE i_alu_opcode IS
			WHEN ALU_ADD | ALU_SUB => o_result <= adder_result;
			WHEN ALU_SLT | ALU_SLTU => o_result <= slt_result;
			WHEN ALU_XOR | ALU_OR | ALU_AND => o_result <= logic_result;
			WHEN ALU_SLL | ALU_SRL | ALU_SRA => o_result <= shifter_result;
                        WHEN ALU_COPY_B => o_result <= i_alu_y;
			WHEN OTHERS => o_result <= (OTHERS => 'X'); -- Undefined
		END CASE;
	END PROCESS;

        o_flags <= internal_flags;

END ARCHITECTURE behavioral;
