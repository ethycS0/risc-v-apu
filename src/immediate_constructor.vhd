LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY immediate_constructor_unit IS
	PORT (
		i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_immediate : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY immediate_constructor_unit;

ARCHITECTURE behavioral OF immediate_constructor_unit IS
BEGIN
	imm_reconstruct : PROCESS (i_instruction)
	BEGIN
		o_immediate <= (OTHERS => '0');

		CASE i_instruction(6 DOWNTO 0) IS

                        -- U-Type (LUI, AUIPC) 
			WHEN "0110111" | "0010111" =>
				o_immediate <= i_instruction(31 DOWNTO 12) & x"000";

                        -- J-Type (JAL) 
			WHEN "1101111" =>
				o_immediate <= (11 DOWNTO 1 => i_instruction(31)) & i_instruction(19 DOWNTO 12) & i_instruction(20) & i_instruction(30 DOWNTO 21) & '0';

                        -- B-Type (Branches) 
			WHEN "1100011" =>
				o_immediate <= (19 DOWNTO 1 => i_instruction(31)) & i_instruction(7) & i_instruction(30 DOWNTO 25) & i_instruction(11 DOWNTO 8) & '0';

                        -- I-Type (JALR, Loads, Immediate Arithmetic)
			WHEN "1100111" | "0000011" | "0010011" =>
				o_immediate <= (19 DOWNTO 0 => i_instruction(31)) & i_instruction(31 DOWNTO 20);

                        -- S-Type (Stores)
			WHEN "0100011" =>
				o_immediate <= (19 DOWNTO 0 => i_instruction(31)) & i_instruction(31 DOWNTO 25) & i_instruction(11 DOWNTO 7);

                        -- R-Type, FENCE, others that have no immediate
			WHEN OTHERS =>
				o_immediate <= (OTHERS => '0');

		END CASE;
	END PROCESS imm_reconstruct;
END ARCHITECTURE behavioral;

