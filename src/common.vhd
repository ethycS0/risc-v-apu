--! @file common.vhd
--! @brief Global package defining types, constants, and pipeline records for the RISC-V SoC.
--! @author ethycS
--! @details This package serves as the central type definition for the RV32I Zicsr core.
--! It includes operation enums, ALU control flags, structured records for inter-stage
--! pipeline registers, and security structures supporting the Zicfilp (Landing Pads)
--! and Smcfiss (Shadow Stack) extensions, along with PMP and CSR forwarding features.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

        CONSTANT RESET_ADDRESS : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"80000000"; --! Reset address (where execution starts)
        CONSTANT C_NOP         : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000013"; --! NOP instruction (ADDI x0, x0, 0) used for pipeline flushes

        --! Decoded high-level operation types.
        TYPE t_OprType IS (
                OP_R_TYPE,      --! Register-Register instruction
                OP_I_TYPE,      --! Register-Immediate instruction
                OP_LUI,         --! Load Upper Immediate instruction
                OP_AUIPC,       --! Add Upper Immediate to PC instruction
                OP_LOAD_STORE,  --! Memory Load or Store instruction
                OP_BRANCH,      --! Conditional Branch instruction
                OP_JUMP,        --! Unconditional Jump instruction (JAL, JALR)
                OP_SYSTEM,      --! System instruction (CSR access, ECALL, EBREAK, MRET, Shadow Stack)
                OP_LPAD,        --! Landing Pad instruction (Zicfilp security extension)
                OP_ILLEGAL      --! Invalid or unsupported instruction
        );

        --! Selects which functional unit executes the instruction.
        TYPE t_OprUnit IS (
                UNIT_ALU,       --! Arithmetic Logic Unit
                UNIT_CSR,       --! Control and Status Register unit (includes shadow stack operations)
                UNIT_ILLEGAL    --! Illegal instruction unit (causes exception)
        );

        --! Specific operations executed by the ALU.
        TYPE t_AluOpcodes IS (
                ALU_ADD,        --! Addition
                ALU_SUB,        --! Subtraction
                ALU_SLT,        --! Set Less Than (signed)
                ALU_SLTU,       --! Set Less Than Unsigned
                ALU_XOR,        --! Bitwise XOR
                ALU_OR,         --! Bitwise OR
                ALU_AND,        --! Bitwise AND
                ALU_SLL,        --! Shift Left Logical
                ALU_SRL,        --! Shift Right Logical
                ALU_SRA,        --! Shift Right Arithmetic
                ALU_COPY_B      --! Copy Operand B directly to output (used for LUI)
        );

        --! Multiplexer selection for ALU Operand A.
        TYPE t_SrcA IS (
                SRC_A_RS1,      --! Source register 1 data
                SRC_A_PC,       --! Program Counter of the current instruction
                SRC_A_UIMM,     --! Zero-extended 5-bit unsigned immediate (for CSRI instructions)
                SRC_A_ZERO      --! Constant zero value
        );

        --! Multiplexer selection for ALU Operand B.
        TYPE t_SrcB IS (
                SRC_B_RS2,      --! Source register 2 data
                SRC_B_IMM       --! Sign-extended immediate value
        );

        --! Source of the data written back to the Register File and forwarded.
        TYPE t_WritebackSrc IS (
                WB_SRC_EX_RESULT, --! Execution stage result (ALU or CSR read data)
                WB_SRC_MEM,       --! Memory read data (from Data Memory / BRAM)
                WB_SRC_PC4        --! Next sequential instruction address (PC + 4, for jumps)
        );

        --! CSR atomic operation types (including shadow stack instructions).
        TYPE t_CsrOpcodes IS (
                CSR_RW,         --! CSR Read/Write (csrrw, csrrwi)
                CSR_RS,         --! CSR Read and Set bits (csrrs, csrrsi)
                CSR_RC,         --! CSR Read and Clear bits (csrrc, csrrci)
                CSR_SSW,        --! Shadow Stack Write/Push (Smcfiss extension)
                CSR_SSR,        --! Shadow Stack Read/Pop (Smcfiss extension)
                CSR_TRAP,       --! Internal CSR command for trap entry/exception handling
                CSR_ILLEGAL     --! Illegal CSR operation or address access
        );

        --! Forwarding Unit path selection to resolve data hazards.
        TYPE t_Forward IS (
                FWD_NONE,        --! No forwarding (use register file read values)
                FWD_FROM_EX_MEM, --! Forward from EX/MEM pipeline register
                FWD_FROM_MEM_WB  --! Forward from MEM/WB pipeline register
        );

        --! Pipeline exception and fault classification tags.
        TYPE t_fault_tag IS (
                VALID,                 --! No fault, instruction is valid
                TRAP_ECALL,            --! Environment Call exception (ecall)
                TRAP_EBREAK,           --! Environment Breakpoint exception (ebreak)
                TRAP_MRET,             --! Machine-mode Return from trap handler (mret)
                IF_ACCESS_FAULT,       --! Instruction Fetch access fault (PMP fetch violation)
                ID_INVALID_INSTR,      --! Instruction Decode invalid/illegal instruction
                EX_REDIR_MISALIGNED,   --! Execution stage branch/jump target address misaligned
                EX_LPAD_FAULT,         --! Landing pad exception (dynamic jump target is not an lpad, Zicfilp)
                MEM_L_MISALIGNED,      --! Memory Load address misaligned
                MEM_S_MISALIGNED,      --! Memory Store address misaligned
                MEM_L_ACCESS_FAULT,    --! Memory Load access fault (PMP read violation)
                MEM_S_ACCESS_FAULT,    --! Memory Store access fault (PMP write violation)
                WB_SHADOW_STACK_FAULT  --! Shadow stack mismatch on function return (Smcfiss)
        );

        --! ALU output status flags.
        TYPE t_AluFlags IS RECORD
                zero                    : STD_LOGIC; --! Result is exactly 0
                negative                : STD_LOGIC; --! Most Significant Bit of result is 1 (signed negative)
                carry                   : STD_LOGIC; --! Unsigned overflow / carry out
                overflow                : STD_LOGIC; --! Signed overflow (two's complement)
        END RECORD t_AluFlags;

        --! Register File write details passed along the pipeline.
        TYPE t_rd_reg_data IS RECORD
                rd_addr                 : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register Index (0-31)
                rd_data                 : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data to be written
                reg_write_en            : STD_LOGIC;                     --! Register File write enable strobe
        END RECORD t_rd_reg_data;

        --! Reset constant for t_rd_reg_data.
        CONSTANT C_RD_BUS_RESET : t_rd_reg_data := (
                reg_write_en            => '0',
                rd_addr                 => (OTHERS => '0'),
                rd_data                 => (OTHERS => '0')
        );

        --! CSR write details passed along the pipeline.
        TYPE t_csr_reg_data IS RECORD 
                csr_addr        : STD_LOGIC_VECTOR(11 DOWNTO 0); --! CSR register address
                csr_data        : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data to write to the CSR
                csr_write_en    : STD_LOGIC;                     --! CSR write enable strobe
        END RECORD t_csr_reg_data;

        --! Reset constant for t_csr_reg_data.
        CONSTANT C_CSR_BUS_RESET : t_csr_reg_data := (
                csr_write_en => '0',
                csr_addr     => x"301",
                csr_data     => x"40000100"
        );

        --! IF/ID Pipeline Register Record.
        TYPE t_if_id_data IS RECORD
                instruction             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Raw 32-bit instruction
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Program Counter of current instruction
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (Next sequential instruction address)
                elp_active              : STD_LOGIC;                     --! Expected Landing Pad active flag (Zicfilp state)
                fault_tag               : t_fault_tag;                   --! Instruction Fetch stage fault status
        END RECORD t_if_id_data;

        --! Reset constant for t_if_id_data.
        CONSTANT C_IF_ID_RESET : t_if_id_data := (
                instruction             => C_NOP,
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                elp_active              => '0',
                fault_tag               => VALID
        );

        --! ID/EX Pipeline Register Record.
        TYPE t_id_ex_data IS RECORD
                reg_write               : STD_LOGIC;                     --! WB: Write to Register File control signal
                wb_src                  : t_WritebackSrc;                --! WB: Data source selection for writeback
                mem_read                : STD_LOGIC;                     --! MEM: Memory read enable strobe
                mem_write               : STD_LOGIC;                     --! MEM: Memory write enable strobe
                src_a                   : t_SrcA;                        --! EX: ALU Operand A source select
                src_b                   : t_SrcB;                        --! EX: ALU Operand B source select
                opr_type                : t_OprType;                     --! EX: Decoded operation category
                opr_unit                : t_OprUnit;                     --! EX: Functional Execution Unit select
                fault_tag               : t_fault_tag;                   --! Fault status carried from previous stages
                elp_active              : STD_LOGIC;                     --! Expected Landing Pad active flag carried to EX stage
                
                immediate               : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Sign-Extended immediate value
                rs1_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read Data 1 from Register File
                rs2_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read Data 2 from Register File
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Program Counter of the instruction
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (Next sequential instruction address)
                rd_addr                 : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register address
                rs1_addr                : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 1 index (for hazard/forwarding)
                rs2_addr                : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 2 index (for hazard/forwarding)
                
                uimm                    : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Unsigned 5-bit immediate value (for CSRI instructions)
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! 3-bit instruction sub-opcode field
                funct12                 : STD_LOGIC_VECTOR(11 DOWNTO 0); --! 12-bit instruction sub-opcode field (CSR/System address)
        END RECORD t_id_ex_data;

        --! Reset constant for t_id_ex_data.
        CONSTANT C_ID_EX_RESET : t_id_ex_data := (
                reg_write               => '0',
                mem_read                => '0',
                mem_write               => '0',
                wb_src                  => WB_SRC_EX_RESULT,
                src_a                   => SRC_A_RS1,
                src_b                   => SRC_B_RS2,
                opr_type                => OP_R_TYPE,
                opr_unit                => UNIT_ALU,
                fault_tag               => VALID,
                elp_active              => '0',
                immediate               => (OTHERS => '0'),
                rs1_data                => (OTHERS => '0'),
                rs2_data                => (OTHERS => '0'),
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                rd_addr                 => (OTHERS => '0'),
                rs1_addr                => (OTHERS => '0'),
                rs2_addr                => (OTHERS => '0'),
                uimm                    => (OTHERS => '0'),
                funct3                  => (OTHERS => '0'),
                funct12                 => (OTHERS => '0')
        );

        --! EX/MEM Pipeline Register Record.
        TYPE t_ex_mem_data IS RECORD
                rd_bus                  : t_rd_reg_data;                 --! Destination Register File writeback bus
                csr_bus                 : t_csr_reg_data;                --! CSR writeback bus
                rs2_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data to be stored or shadow stack data
                fault_tag               : t_fault_tag;                   --! Fault status carried from previous stages
                ss_instr                : STD_LOGIC;                     --! Shadow stack instruction active flag (Smcfiss)
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Program Counter of the instruction
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (Next sequential instruction address)
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Data width/extension mode (Byte/Half/Word)
                mem_read                : STD_LOGIC;                     --! Memory read enable strobe
                mem_write               : STD_LOGIC;                     --! Memory write enable strobe
                wb_src                  : t_WritebackSrc;                --! Writeback data source selection
        END RECORD t_ex_mem_data;

        --! Reset constant for t_ex_mem_data.
        CONSTANT C_EX_MEM_RESET : t_ex_mem_data := (
                rd_bus                  => C_RD_BUS_RESET,
                csr_bus                 => C_CSR_BUS_RESET,
                rs2_data                => (OTHERS => '0'),
                fault_tag               => VALID,
                ss_instr                => '0',
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                funct3                  => (OTHERS => '0'),
                mem_read                => '0',
                mem_write               => '0',
                wb_src                  => WB_SRC_EX_RESULT
        );

        --! MEM/WB Pipeline Register Record.
        TYPE t_mem_wb_data IS RECORD
                rd_bus                  : t_rd_reg_data;                 --! Destination Register File writeback bus
                csr_bus                 : t_csr_reg_data;                --! CSR writeback bus
                fault_tag               : t_fault_tag;                   --! Fault status carried from previous stages
                ss_instr                : STD_LOGIC;                     --! Shadow stack instruction active flag (Smcfiss)
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Program Counter of the instruction
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (Next sequential instruction address)
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Load data extension format (signed/unsigned width)
                wb_src                  : t_WritebackSrc;                --! Writeback multiplexer selection
        END RECORD t_mem_wb_data;

        --! Reset constant for t_mem_wb_data.
        CONSTANT C_MEM_WB_RESET : t_mem_wb_data := (
                rd_bus                  => C_RD_BUS_RESET,
                csr_bus                 => C_CSR_BUS_RESET,
                fault_tag               => VALID,
                ss_instr                => '0',
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                funct3                  => (OTHERS => '0'),
                wb_src                  => WB_SRC_EX_RESULT
        );

        --! Feedback signals from Writeback stage to Execution stage (CSR Writeback and trap routing).
        TYPE t_wb_ex_fb IS RECORD
                csr_bus         : t_csr_reg_data;                --! CSR write details to commit to CSR register file
                trap            : STD_LOGIC;                     --! Global trap event trigger
                mret            : STD_LOGIC;                     --! Machine-mode return execution trigger
                mepc            : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Exception Program Counter (EPC) value
                mtval           : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap Value (faulting address or instruction)
                mcause          : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap Cause identifier
                minstret        : STD_LOGIC;                     --! Increment retired instructions counter signal
                fwd             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! CSR writeback forwarded value (resolves hazard)
                crit_csr        : STD_LOGIC;                     --! Critical CSR register update (requires pipeline flush)
                pc4             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (used for shadow stack return validation)
        END RECORD t_wb_ex_fb;

        --! Feedback signals from Execution stage to Instruction Fetch stage (Branching and security status).
        TYPE t_ex_if_data IS RECORD
                pc_redirect             : STD_LOGIC;                     --! Redirection request (branch/jump taken)
                next_elp                : STD_LOGIC;                     --! Sets next instruction as Expected Landing Pad (Zicfilp)
                redirect_address        : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Redirection target address
        END RECORD t_ex_if_data;

        --! PMP configuration data from Execution/CSR to PMP unit.
        TYPE t_ex_pmp_data IS RECORD
                pmpcfg0     : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! PMP Configuration Register 0 (entries 0-3 modes)
                pmpaddr0    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! PMP Address Register 0
                pmpaddr1    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! PMP Address Register 1
                pmpaddr2    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! PMP Address Register 2
                pmpaddr3    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! PMP Address Register 3
                pmp_e_bits  : STD_LOGIC_VECTOR(3 DOWNTO 0);   --! Region enable bits for the 4 PMP entries
        END RECORD t_ex_pmp_data;

END PACKAGE rv32i_pkg;
