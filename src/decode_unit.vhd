LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.rv32i_pkg.ALL;

ENTITY decode_unit IS

	PORT (
		instruction : IN std_logic_vector(31 DOWNTO 0);
		operation : OUT exec_op_t
	);

END ENTITY decode_unit;

ARCHITECTURE behavioral OF decode_unit IS
BEGIN
	decode_process : PROCESS (instruction)
	BEGIN
		CASE instruction(6 DOWNTO 2) IS
			-- LUI
			WHEN b"01101" => 
				operation <= OP_LUI;

			-- AUIPC
			WHEN b"00101" => 
				operation <= OP_AUIPC;
 
			-- JAL
			WHEN b"11011" => 
				operation <= OP_JAL;
 
			-- JALR
			WHEN b"11001" => 
				operation <= OP_JALR;
 
			-- BRANCH Operations
			WHEN b"11000" => 
				CASE instruction(14 DOWNTO 12) IS
					WHEN b"000" => 
						operation <= OP_BEQ;
					WHEN b"001" => 
						operation <= OP_BNE;
					WHEN b"100" => 
						operation <= OP_BLT;
					WHEN b"101" => 
						operation <= OP_BGE;
					WHEN b"110" => 
						operation <= OP_BLTU;
					WHEN b"111" => 
						operation <= OP_BGEU;
					WHEN OTHERS => 
						operation <= OP_INVALID;
                                END CASE;
 
			-- LOAD Operations
			WHEN b"00000" => 
				CASE instruction(14 DOWNTO 12) IS
					WHEN b"000" => 
						operation <= OP_LB;
					WHEN b"001" => 
						operation <= OP_LH;
					WHEN b"010" => 
						operation <= OP_LW;
					WHEN b"100" => 
						operation <= OP_LBU;
					WHEN b"101" => 
						operation <= OP_LHU;
					WHEN OTHERS => 
						operation <= OP_INVALID;
                                END CASE;
 
			-- STORE Operations
			WHEN b"01000" => 
				CASE instruction(14 DOWNTO 12) IS
					WHEN b"000" => 
						operation <= OP_SB;
					WHEN b"001" => 
						operation <= OP_SH;
					WHEN b"010" => 
						operation <= OP_SW;
					WHEN OTHERS => 
						operation <= OP_INVALID;
                                END CASE;
 
			-- ALU Operations
			WHEN b"00100" | b"01100" => 
				CASE instruction(14 DOWNTO 12) IS
					WHEN b"000" => 
						IF instruction(6 DOWNTO 2) = b"01100" AND instruction(30) = '1' THEN
							operation <= OP_SUB;
						ELSE
							operation <= OP_ADD;
						END IF;
					WHEN b"010" => 
						operation <= OP_SLT;
					WHEN b"011" => 
						operation <= OP_SLTU;
					WHEN b"100" => 
						operation <= OP_XOR;
					WHEN b"110" => 
						operation <= OP_OR;
					WHEN b"111" => 
						operation <= OP_AND;
					WHEN b"001" => 
						operation <= OP_SLL;
					WHEN b"101" => 
						IF instruction(30) = '1' THEN
							operation <= OP_SRA;
						ELSE
							operation <= OP_SRL;
						END IF;
					WHEN OTHERS => 
						operation <= OP_INVALID;
                                END CASE;

			-- Memory operations FENCE n PAUSE
			WHEN b"00011" => 
				IF instruction = x"0100000F" THEN 
					operation <= OP_PAUSE;
				ELSIF instruction(14 DOWNTO 12) = b"000" THEN 
					IF instruction(31 DOWNTO 28) = b"1000" THEN
						operation <= OP_FENCE_TSO;
					ELSE
						operation <= OP_FENCE;
					END IF;
				ELSE
					operation <= OP_INVALID;
				END IF;

                        -- Env Operations
			WHEN b"11100" => 
				CASE instruction(14 DOWNTO 12) IS -- funct3
					WHEN b"000" => 
						CASE instruction(31 DOWNTO 20) IS
							WHEN x"000" => 
								operation <= OP_ECALL;
							WHEN x"001" =>
								operation <= OP_EBREAK;
							WHEN OTHERS => 
								operation <= OP_INVALID;
                                                END CASE;
					WHEN OTHERS => 
						operation <= OP_INVALID;
                                END CASE;

			-- Errors
			WHEN OTHERS => 
				operation <= OP_INVALID;
		END CASE;
	END PROCESS decode_process;

END ARCHITECTURE behavioral;
