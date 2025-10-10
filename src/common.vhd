LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

	TYPE exec_opcodes_t IS (
                -- AGU
                OP_LUI, OP_AUIPC, 
                -- JUMP
                OP_JAL, OP_JALR, 
                -- BRANCH
                OP_BEQ, OP_BNE, OP_BLT, OP_BGE, OP_BLTU, OP_BGEU, 
                -- LOAD
                OP_LB, OP_LH, OP_LW, OP_LBU, OP_LHU, 
                -- STORE
                OP_SB, OP_SH, OP_SW, 
                -- ALU
                OP_ADD, OP_SLT, OP_SLTU, OP_XOR, OP_OR, OP_AND, OP_SLL, OP_SRL, OP_SRA, OP_SUB, 
                -- Memory Ordering (Single Core hence ignored)
                OP_FENCE, OP_FENCE_TSO, OP_PAUSE,
                -- ENV Call
                OP_ECALL, OP_EBREAK, 
                -- Errors
                OP_INVALID
	);

        TYPE exec_unit_t IS (
                UNIT_AGU, UNIT_JMP, UNIT_BR, UNIT_LD, UNIT_STR, UNIT_ALU, UNIT_MO, UNIT_ENVC
        );

END PACKAGE rv32i_pkg;
