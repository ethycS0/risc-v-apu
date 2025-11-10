LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

        -- Control Signals for ALU Control
	TYPE t_ExecControl IS (
                OP_R_TYPE, OP_I_TYPE, OP_LUI, OP_AUIPC,
                OP_LOAD_STORE, OP_BRANCH, OP_JUMP
	);

        -- Final Opcode for ALU
	TYPE t_AluOpcodes IS (
                ALU_ADD, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_OR, 
                ALU_AND, ALU_SLL, ALU_SRL, ALU_SRA, ALU_SUB, ALU_COPY_B
	);

	-- Selects the second operand for the ALU.
	TYPE t_AluSrc IS (
                ALU_SRC_REG,
                ALU_SRC_IMM 
	);

	-- Selects the data source for the register file write-back.
	TYPE t_WritebackSrc IS (
                WB_SRC_ALU,
                WB_SRC_MEM,
                WB_SRC_PC4 
	);

        -- Output Result Flags for ALU
        TYPE t_AluFlags IS RECORD
                zero     : std_logic;
                negative : std_logic;
                carry    : std_logic;
                overflow : std_logic;
        END RECORD t_AluFlags;

END PACKAGE rv32i_pkg;
