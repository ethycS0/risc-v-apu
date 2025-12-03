LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY id_control_unit IS
	PORT (
		i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Primary control signals
		o_reg_write : OUT STD_LOGIC;
		o_mem_read : OUT STD_LOGIC;
		o_mem_write : OUT STD_LOGIC;

		-- Mux select signals
		o_src_a : OUT t_SrcA;
		o_src_b : OUT t_SrcB;
		o_wb_src : OUT t_WritebackSrc;

		-- Intermediate ALUOp type
                o_opr_unit : OUT t_OprUnit;
		o_opr_type : OUT t_OprType
	);
END ENTITY id_control_unit;

ARCHITECTURE behavioral OF id_control_unit IS
BEGIN
	U_CONTROL_SIGNAL_GEN : PROCESS (i_instruction)
	BEGIN
		o_reg_write <= '0';
		o_mem_read <= '0';
		o_mem_write <= '0';
		o_src_a <= SRC_A_RS1;
		o_src_b <= SRC_B_RS2;
		o_wb_src <= WB_SRC_EX_RESULT;
		o_opr_type <= OP_ILLEGAL;
                o_opr_unit <= UNIT_ALU;

		CASE i_instruction(6 DOWNTO 0) IS

                        -- U-Type: LUI
			WHEN "0110111" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_ZERO;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_LUI;

                        -- U-Type: AUIPC
			WHEN "0010111" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_PC;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_AUIPC;

                        -- J-Type: JAL
			WHEN "1101111" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_PC;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_opr_type <= OP_JUMP;

                        -- I-Type: JALR
			WHEN "1100111" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_opr_type <= OP_JUMP;

                        -- B-Type: Branches
			WHEN "1100011" =>
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_RS2;
				o_opr_type <= OP_BRANCH;

                        -- I-Type: Loads
			WHEN "0000011" =>
				o_reg_write <= '1';
				o_mem_read <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_wb_src <= WB_SRC_MEM;
				o_opr_type <= OP_LOAD_STORE;

                        -- S-Type: Stores
			WHEN "0100011" =>
				o_mem_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_LOAD_STORE;

                        -- I-Type: Immediate arithmetic/logic
			WHEN "0010011" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_IMM;
				o_opr_type <= OP_I_TYPE;

                        -- R-Type: Register arithmetic/logic
			WHEN "0110011" =>
				o_reg_write <= '1';
				o_src_a <= SRC_A_RS1;
				o_src_b <= SRC_B_RS2;
				o_opr_type <= OP_R_TYPE;

                        -- System and CSR
                        WHEN "1110011" =>
                                o_opr_unit <= UNIT_CSR;
                                o_opr_type <= OP_SYSTEM; 
                                o_reg_write   <= '1';      
                                IF i_instruction(14) = '1' THEN
                                    o_src_a <= SRC_A_UIMM; 
                                ELSE
                                    o_src_a <= SRC_A_RS1; 
                                END IF;
                                o_src_b <= SRC_B_IMM;

			WHEN OTHERS =>
				-- All signals remain at their default '0' or "safe" state.
				NULL;

		END CASE;
	END PROCESS U_CONTROL_SIGNAL_GEN;

END ARCHITECTURE behavioral;

