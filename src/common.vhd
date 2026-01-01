LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

    CONSTANT RESET_ADDRESS : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000";

    TYPE t_OprType IS (
        OP_R_TYPE,
        OP_I_TYPE,
        OP_LUI,
        OP_AUIPC,
        OP_LOAD_STORE,
        OP_BRANCH,
        OP_JUMP,
        OP_SYSTEM,
        OP_ILLEGAL
    );

    TYPE t_OprUnit IS (
        UNIT_ALU,
        UNIT_CSR,
        UNIT_ILLEGAL
    );

    TYPE t_AluOpcodes IS (
        ALU_ADD,
        ALU_SUB,
        ALU_SLT,
        ALU_SLTU,
        ALU_XOR,
        ALU_OR,
        ALU_AND,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_COPY_B
    );

    TYPE t_AluFlags IS RECORD
        zero     : STD_LOGIC;
        negative : STD_LOGIC;
        carry    : STD_LOGIC;
        overflow : STD_LOGIC;
    END RECORD t_AluFlags;

    TYPE t_SrcA IS (
        SRC_A_RS1,
        SRC_A_PC,
        SRC_A_UIMM,
        SRC_A_ZERO
    );

    TYPE t_SrcB IS (
        SRC_B_RS2,
        SRC_B_IMM
    );

    TYPE t_WritebackSrc IS (
        WB_SRC_EX_RESULT,
        WB_SRC_MEM,
        WB_SRC_PC4
    );

    TYPE t_CsrOpcodes IS (
        CSR_RW,
        CSR_RS,
        CSR_RC,
        CSR_TRAP,
        CSR_ILLEGAL
    );

    TYPE t_TrapType IS (
        TRAP_NONE,
        TRAP_CALL,
        TRAP_BREAK,
        TRAP_MRET
    );

    TYPE t_Forward IS (
        FWD_NONE,
        FWD_FROM_EX_MEM,
        FWD_FROM_MEM_WB
    );

    TYPE t_rd_reg_data IS RECORD
        rd_addr      : STD_LOGIC_VECTOR(4 DOWNTO 0);
        rd_data      : STD_LOGIC_VECTOR(31 DOWNTO 0);
        reg_write_en : STD_LOGIC;
    END RECORD t_rd_reg_data;

    CONSTANT C_RD_BUS_RESET : t_rd_reg_data := (
        reg_write_en => '0',
        rd_addr      => (OTHERS => '0'),
        rd_data      => (OTHERS => '0')
    );

    TYPE t_if_id_data IS RECORD
        instruction : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc          : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc4         : STD_LOGIC_VECTOR(31 DOWNTO 0);
    END RECORD t_if_id_data;

    CONSTANT C_IF_ID_RESET : t_if_id_data := (
        instruction => x"00000013",
        pc          => (OTHERS => '0'),
        pc4         => (OTHERS => '0')
    );

    TYPE t_id_ex_data IS RECORD
        reg_write : STD_LOGIC;
        mem_read  : STD_LOGIC;
        mem_write : STD_LOGIC;
        wb_src    : t_WritebackSrc;
        src_a     : t_SrcA;
        src_b     : t_SrcB;
        opr_type  : t_OprType;
        opr_unit  : t_OprUnit;
        immediate : STD_LOGIC_VECTOR(31 DOWNTO 0);
        rs1_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
        rs2_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc        : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc4       : STD_LOGIC_VECTOR(31 DOWNTO 0);
        rd_addr   : STD_LOGIC_VECTOR(4 DOWNTO 0);
        rs1_addr  : STD_LOGIC_VECTOR(4 DOWNTO 0);
        rs2_addr  : STD_LOGIC_VECTOR(4 DOWNTO 0);
        uimm      : STD_LOGIC_VECTOR(4 DOWNTO 0);
        funct3    : STD_LOGIC_VECTOR(2 DOWNTO 0);
        funct12   : STD_LOGIC_VECTOR(11 DOWNTO 0);
    END RECORD t_id_ex_data;

    CONSTANT C_ID_EX_RESET : t_id_ex_data := (
        reg_write => '0',
        mem_read  => '0',
        mem_write => '0',
        wb_src    => WB_SRC_EX_RESULT,
        src_a     => SRC_A_RS1,
        src_b     => SRC_B_RS2,
        opr_type  => OP_R_TYPE,
        opr_unit  => UNIT_ALU,
        immediate => (OTHERS => '0'),
        rs1_data  => (OTHERS => '0'),
        rs2_data  => (OTHERS => '0'),
        pc        => (OTHERS => '0'),
        pc4       => (OTHERS => '0'),
        rd_addr   => (OTHERS => '0'),
        rs1_addr  => (OTHERS => '0'),
        rs2_addr  => (OTHERS => '0'),
        uimm      => (OTHERS => '0'),
        funct3    => (OTHERS => '0'),
        funct12   => (OTHERS => '0')
    );

    TYPE t_ex_mem_data IS RECORD
        rd_bus    : t_rd_reg_data;
        rs2_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc4       : STD_LOGIC_VECTOR(31 DOWNTO 0);
        funct3    : STD_LOGIC_VECTOR(2 DOWNTO 0);
        mem_read  : STD_LOGIC;
        mem_write : STD_LOGIC;
        wb_src    : t_WritebackSrc;
    END RECORD t_ex_mem_data;

    CONSTANT C_EX_MEM_RESET : t_ex_mem_data := (
        rd_bus    => C_RD_BUS_RESET,
        rs2_data  => (OTHERS => '0'),
        pc4       => (OTHERS => '0'),
        funct3    => (OTHERS => '0'),
        mem_read  => '0',
        mem_write => '0',
        wb_src    => WB_SRC_EX_RESULT
    );

    TYPE t_mem_wb_data IS RECORD
        rd_bus : t_rd_reg_data;
        raw_mem_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
        pc4    : STD_LOGIC_VECTOR(31 DOWNTO 0);
        funct3    : STD_LOGIC_VECTOR(2 DOWNTO 0);
        wb_src : t_WritebackSrc;
    END RECORD t_mem_wb_data;

    CONSTANT C_MEM_WB_RESET : t_mem_wb_data := (
        rd_bus => C_RD_BUS_RESET,
        raw_mem_data => (OTHERS => '0'),
        pc4    => (OTHERS => '0'),
        funct3    => (OTHERS => '0'),
        wb_src => WB_SRC_EX_RESULT
    );

    TYPE t_ex_if_data IS RECORD
        pc_redirect      : STD_LOGIC;
        redirect_address : STD_LOGIC_VECTOR(31 DOWNTO 0);
    END RECORD t_ex_if_data;

END PACKAGE rv32i_pkg;

