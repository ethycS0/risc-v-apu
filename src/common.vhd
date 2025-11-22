LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS
	CONSTANT REGFILE_DATA_WIDTH : INTEGER := 32;
	CONSTANT REGFILE_ADDR_WIDTH : INTEGER := 5;

        CONSTANT CSR_ADDR_WIDTH : INTEGER := 12;

	CONSTANT MEMORY_ADDR_WIDTH : INTEGER := 32;
	CONSTANT INSTRUCTION_WIDTH : INTEGER := 32;
	CONSTANT RESET_ADDRESS : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"80000000";

	-- Control Signals for ALU Control
	TYPE t_ExecControl IS (
		OP_R_TYPE, OP_I_TYPE, OP_LUI, OP_AUIPC,
		OP_LOAD_STORE, OP_BRANCH, OP_JUMP, OP_ILLEGAL
	);

	-- Final Opcode for ALU
	TYPE t_AluOpcodes IS (
		ALU_ADD, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_OR,
		ALU_AND, ALU_SLL, ALU_SRL, ALU_SRA, ALU_SUB, ALU_COPY_B
	);

	-- Selects the operand for the ALU.
	TYPE t_AluSrc_A IS (
		ALU_A_RS1,
		ALU_A_PC,
		ALU_A_ZERO
	);

	TYPE t_AluSrc_B IS (
		ALU_B_RS2,
		ALU_B_IMM
	);

	-- Selects the data source for the register file write-back.
	TYPE t_WritebackSrc IS (
		WB_SRC_ALU,
		WB_SRC_MEM,
		WB_SRC_PC4
	);

	-- Output Result Flags for ALU
	TYPE t_AluFlags IS RECORD
		zero : STD_LOGIC;
		negative : STD_LOGIC;
		carry : STD_LOGIC;
		overflow : STD_LOGIC;
	END RECORD t_AluFlags;

	TYPE t_PcSrc IS (PC_SRC_PC4, PC_SRC_BRANCH, PC_SRC_JUMP);
	TYPE t_Forward IS (FWD_NONE, FWD_FROM_EX_MEM, FWD_FROM_MEM_WB);

	TYPE t_CsrOpcodes IS ( RW, RS, RC );

END PACKAGE rv32i_pkg;

