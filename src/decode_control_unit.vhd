LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY decode_control_unit IS
	PORT (
		i_instruction : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Primary control signals
		o_reg_write : OUT STD_LOGIC;
		o_mem_read : OUT STD_LOGIC;
		o_mem_write : OUT STD_LOGIC;

		-- Mux select signals
		o_alu_src_a : OUT t_AluSrc_A;
		o_alu_src_b : OUT t_AluSrc_B;
		o_wb_src : OUT t_WritebackSrc;
		o_pc_src : OUT t_PcSrc; 

		-- Intermediate ALUOp type
		o_alu_op_type : OUT t_ExecControl
	);
END ENTITY decode_control_unit;

ARCHITECTURE behavioral OF decode_control_unit IS
BEGIN
	decode_process : PROCESS (i_instruction)
	BEGIN
		-- Default assignments for a "NOP" or safe state
		o_reg_write <= '0';
		o_mem_read <= '0';
		o_mem_write <= '0';
		o_alu_src_a <= ALU_A_RS1;
		o_alu_src_b <= ALU_B_RS2;
		o_wb_src <= WB_SRC_ALU;
		o_pc_src <= PC_SRC_PC4; 
		o_alu_op_type <= OP_ILLEGAL;

		CASE i_instruction(6 DOWNTO 0) IS

                        -- U-Type: LUI
			WHEN "0110111" =>
				o_reg_write <= '1';
				o_alu_src_a <= ALU_A_ZERO;
				o_alu_src_b <= ALU_B_IMM;
				o_alu_op_type <= OP_LUI;

                        -- U-Type: AUIPC
			WHEN "0010111" =>
				o_reg_write <= '1';
				o_alu_src_a <= ALU_A_PC;
				o_alu_src_b <= ALU_B_IMM;
				o_alu_op_type <= OP_AUIPC;

                        -- J-Type: JAL
			WHEN "1101111" =>
				o_reg_write <= '1';
				o_pc_src <= PC_SRC_JUMP;
				o_alu_src_a <= ALU_A_PC;
				o_alu_src_b <= ALU_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_alu_op_type <= OP_JUMP;

                        -- I-Type: JALR
			WHEN "1100111" =>
				o_reg_write <= '1';
				o_pc_src <= PC_SRC_JUMP;
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_IMM;
				o_wb_src <= WB_SRC_PC4;
				o_alu_op_type <= OP_JUMP;

                        -- B-Type: Branches
			WHEN "1100011" =>
				o_pc_src <= PC_SRC_BRANCH;
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_RS2;
				o_alu_op_type <= OP_BRANCH;

                        -- I-Type: Loads
			WHEN "0000011" =>
				o_reg_write <= '1';
				o_mem_read <= '1';
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_IMM;
				o_wb_src <= WB_SRC_MEM;
				o_alu_op_type <= OP_LOAD_STORE;

                        -- S-Type: Stores
			WHEN "0100011" =>
				o_mem_write <= '1';
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_IMM;
				o_alu_op_type <= OP_LOAD_STORE;

                        -- I-Type: Immediate arithmetic/logic
			WHEN "0010011" =>
				o_reg_write <= '1';
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_IMM;
				o_alu_op_type <= OP_I_TYPE;

                        -- R-Type: Register arithmetic/logic
			WHEN "0110011" =>
				o_reg_write <= '1';
				o_alu_src_a <= ALU_A_RS1;
				o_alu_src_b <= ALU_B_RS2;
				o_alu_op_type <= OP_R_TYPE;

                        -- System and CSR
                        WHEN "1110011" =>

                        -- FENCE, SYSTEM, and other unimplemented or invalid opcodes
			WHEN OTHERS =>
				-- All signals remain at their default '0' or "safe" state.
				NULL;

		END CASE;
	END PROCESS decode_process;

END ARCHITECTURE behavioral;

