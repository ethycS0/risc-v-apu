--! @file alu.vhd
--! Arithmetic Logic Unit
--! @author ethycS
--! @details This module implements the 32-bit Arithmetic Logic Unit (ALU) for the
--! RV32I processor. It performs arithmetic, logical, shift, and comparison operations
--! based on the provided opcode.
--!
--! Supported operations:
--! - Arithmetic: ADD, SUB
--! - Logical: AND, OR, XOR
--! - Shift: SLL (logical left), SRL (logical right), SRA (arithmetic right)
--! - Comparison: SLT (signed), SLTU (unsigned)
--! - Pass-through: COPY_B (used for LUI and other immediate operations)
--!
--! The ALU uses a unified adder-subtractor for arithmetic and comparison operations,
--! with flag generation for signed/unsigned comparisons. Subtraction and comparison
--! operations are implemented using two's complement (invert + carry-in).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY alu IS
	PORT (
		i_alu_opcode : IN t_AluOpcodes;                  --! ALU operation selection
		i_alu_x      : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! Operand A input
		i_alu_y      : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! Operand B input

		o_result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! ALU result output
		o_flags  : OUT t_AluFlags                     --! ALU flags (carry, overflow, negative, zero)
	);

END ENTITY alu;

ARCHITECTURE behavioral OF alu IS

	SIGNAL adder_b_operand       : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Modified B operand (inverted for subtraction/comparison)
	SIGNAL adder_carry_in        : STD_LOGIC;                     --! Carry-in signal for adder (1 for SUB/SLT/SLTU, 0 for ADD)
	SIGNAL adder_carry_term      : signed(32 DOWNTO 0);           --! Carry term for two's complement arithmetic
	SIGNAL extended_adder_result : STD_LOGIC_VECTOR(32 DOWNTO 0); --! 33-bit adder result with carry-out bit
	SIGNAL adder_result          : STD_LOGIC_VECTOR(31 DOWNTO 0); --! 32-bit addition/subtraction result
	SIGNAL logic_result          : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Result from logical operations (AND/OR/XOR)
	SIGNAL shifter_result        : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Result from shift operations (SLL/SRL/SRA)
	SIGNAL slt_result            : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Result from set-less-than operations (SLT/SLTU)
	SIGNAL internal_flags        : t_AluFlags;                    --! Internal flag register for carry, overflow, negative, zero

BEGIN

	-- Generate carry-in for subtraction and comparison operations (two's complement)
	adder_carry_in <= '1' WHEN (i_alu_opcode = ALU_SUB) OR (i_alu_opcode = ALU_SLT) OR (i_alu_opcode = ALU_SLTU) ELSE '0';
	
	-- Conditionally invert B operand for subtraction (A - B = A + ~B + 1)
	adder_b_operand <= i_alu_y XOR (31 DOWNTO 0 => adder_carry_in);
	
	-- Convert carry-in to signed value for addition
	adder_carry_term <= to_signed(1, 33) WHEN adder_carry_in = '1' ELSE to_signed(0, 33);

	-- Unified 33-bit adder for addition, subtraction, and comparison
	extended_adder_result <= STD_LOGIC_VECTOR(('0' & signed(i_alu_x)) + ('0' & signed(adder_b_operand)) + adder_carry_term);
	adder_result <= extended_adder_result(31 DOWNTO 0);

	-- Generate ALU flags from adder result
	internal_flags.carry <= extended_adder_result(32);
	internal_flags.overflow <= '1' WHEN (i_alu_x(31) = adder_b_operand(31)) AND (adder_result(31) /= i_alu_x(31)) ELSE '0';
	internal_flags.negative <= adder_result(31);
	internal_flags.zero <= '1' WHEN adder_result = (31 DOWNTO 0 => '0') ELSE '0';

	-- Barrel shifter implementation for SLL, SRL, SRA (shift amount from lower 5 bits of Y)
	shifter_result <= STD_LOGIC_VECTOR(shift_left(unsigned(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SLL ELSE
	                  STD_LOGIC_VECTOR(shift_right(unsigned(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SRL ELSE
	                  STD_LOGIC_VECTOR(shift_right(signed(i_alu_x), to_integer(unsigned(i_alu_y(4 DOWNTO 0))))) WHEN i_alu_opcode = ALU_SRA ELSE
	                  (OTHERS => '0');

	-- Set-less-than result generation (1 if A < B, 0 otherwise)
	slt_result <= (31 DOWNTO 1 => '0') & (internal_flags.negative XOR internal_flags.overflow) WHEN i_alu_opcode = ALU_SLT ELSE
	              (31 DOWNTO 1 => '0') & (NOT internal_flags.carry) WHEN i_alu_opcode = ALU_SLTU ELSE
	              (OTHERS => '0');

	-- Bitwise logical result generation (AND, OR, XOR) 
        logic_result <= i_alu_x XOR i_alu_y WHEN i_alu_opcode = ALU_XOR ELSE 
                        i_alu_x OR i_alu_y WHEN i_alu_opcode = ALU_OR ELSE 
                        i_alu_x AND i_alu_y WHEN i_alu_opcode = ALU_AND ELSE
                        (OTHERS => '0');

	--! @brief Final Output Multiplexer Process
	--! @details Selects the appropriate result based on the ALU opcode. This process
	--! acts as the final output stage multiplexer, choosing between adder, logical,
	--! shifter, comparison, or pass-through results.
	P_FINAL_OUTPUT_MUX : PROCESS (i_alu_opcode, adder_result, logic_result, shifter_result, slt_result, i_alu_y)
	BEGIN
		CASE i_alu_opcode IS
			WHEN ALU_ADD | ALU_SUB           => o_result <= adder_result;
			WHEN ALU_SLT | ALU_SLTU          => o_result <= slt_result;
			WHEN ALU_XOR | ALU_OR | ALU_AND  => o_result <= logic_result;
			WHEN ALU_SLL | ALU_SRL | ALU_SRA => o_result <= shifter_result;
			WHEN ALU_COPY_B                  => o_result <= i_alu_y;
			WHEN OTHERS                      => o_result <= (OTHERS => 'X');
		END CASE;
	END PROCESS;

	-- Output internal flags
	o_flags <= internal_flags;

END ARCHITECTURE behavioral;

