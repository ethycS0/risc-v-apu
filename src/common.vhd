LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

	TYPE exec_op_t IS (
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

END PACKAGE rv32i_pkg;
