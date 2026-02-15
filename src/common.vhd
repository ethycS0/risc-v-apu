--! @file common.vhd
--! Global package defining types, constants, and pipeline records for the RISC-V SoC.
--! @author ethycS
--! @details This package serves as the central type definition for the RV32I Zicsr core. 
--! It includes operation enums, ALU control flags, and the structured records used 
--! for the inter-stage pipeline registers.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE rv32i_pkg IS

        CONSTANT RESET_ADDRESS : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000";
        CONSTANT C_NOP : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000013"; --! NOP instruction (ADDI x0, x0, 0) used for flushing

        --! Decoded high-level operation types.
        TYPE t_OprType IS (
                OP_R_TYPE,              
                OP_I_TYPE,              
                OP_LUI,                 
                OP_AUIPC,               
                OP_LOAD_STORE,          
                OP_BRANCH,              
                OP_JUMP,                
                OP_SYSTEM,              
                OP_LPAD,
                OP_ILLEGAL              
        );

        --! Selects which functional unit executes the instruction.
        TYPE t_OprUnit IS (
                UNIT_ALU,              
                UNIT_CSR,              
                UNIT_ILLEGAL           
        );

        --! Specific operations required by the ALU.
        TYPE t_AluOpcodes IS (
                ALU_ADD, ALU_SUB, 
                ALU_SLT,              
                ALU_SLTU,             
                ALU_XOR, ALU_OR, ALU_AND, 
                ALU_SLL,             
                ALU_SRL,             
                ALU_SRA,             
                ALU_COPY_B           
        );

        --! Mux selection for ALU Operand A.
        TYPE t_SrcA IS (
                SRC_A_RS1,              
                SRC_A_PC,               
                SRC_A_UIMM,             
                SRC_A_ZERO              
        );

        --! Mux selection for ALU Operand B.
        TYPE t_SrcB IS (
                SRC_B_RS2,             
                SRC_B_IMM              
        );

        --! Source for the data written back to the Register File and Forwarding from writeback stage.
        TYPE t_WritebackSrc IS (
                WB_SRC_EX_RESULT,     
                WB_SRC_MEM,           
                WB_SRC_PC4            
        );

        --! CSR atomic operation types.
        TYPE t_CsrOpcodes IS (
                CSR_RW,              
                CSR_RS,              
                CSR_RC,              
                CSR_TRAP,            
                CSR_ILLEGAL          
        );

        --! Internal Trap classification.
        TYPE t_TrapType IS (
                TRAP_NONE,
                TRAP_CALL,          
                TRAP_BREAK,         
                TRAP_MRET           
        );

        TYPE t_if_trap IS (
                VALID,
                ELP,
                PMP_FAULT
        );

        --! Forwarding Unit data path selection.
        TYPE t_Forward IS (
                FWD_NONE,          
                FWD_FROM_EX_MEM,   
                FWD_FROM_MEM_WB    
        );

        TYPE t_mem_trap IS (
                VALID,
                L_MISALIGNED,
                S_MISALIGNED,
                L_ACCESS_FAULT,
                S_ACCESS_FAULT
        );

        --! ALU output status flags.
        TYPE t_AluFlags IS RECORD
                zero                    : STD_LOGIC; --! Result is exactly 0
                negative                : STD_LOGIC; --! MSB of result is 1
                carry                   : STD_LOGIC; --! Unsigned overflow/carry out
                overflow                : STD_LOGIC; --! Signed overflow (2's complement)
        END RECORD t_AluFlags;


        --! Useful abtraction bus for pipeline registers after EX stage. 
        TYPE t_rd_reg_data IS RECORD
                rd_addr                 : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register Index
                rd_data                 : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data to write
                reg_write_en            : STD_LOGIC;                     --! Write Enable Strobe
        END RECORD t_rd_reg_data;

        CONSTANT C_RD_BUS_RESET : t_rd_reg_data := (
                reg_write_en            => '0',
                rd_addr                 => (OTHERS => '0'),
                rd_data                 => (OTHERS => '0')
        );

        --! IF/ID Pipeline Register Record.
        TYPE t_if_id_data IS RECORD
                instruction             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Raw 32-bit instruction
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC of current instruction
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC + 4 (Next Seq PC)
                instr_tag               : t_if_trap;                     --| EX: Landing Pad
        END RECORD t_if_id_data;

        CONSTANT C_IF_ID_RESET : t_if_id_data := (
                instruction             => C_NOP,
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                instr_tag               => VALID
        );

        --! ID/EX Pipeline Register Record.
        TYPE t_id_ex_data IS RECORD
                reg_write               : STD_LOGIC;                     --! WB: Write to Register File
                wb_src                  : t_WritebackSrc;                --! WB: Data source selection
                mem_read                : STD_LOGIC;                     --! MEM: Read from Data Memory
                mem_write               : STD_LOGIC;                     --! MEM: Write to Data Memory
                src_a                   : t_SrcA;                        --! EX: ALU Operand A select
                src_b                   : t_SrcB;                        --! EX: ALU Operand B select
                opr_type                : t_OprType;                     --! EX: Operation Category
                opr_unit                : t_OprUnit;                     --! EX: Functional Unit Select
                instr_tag               : t_if_trap;                     --| EX: Landing Pad
                
                immediate               : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Sign-Extended Immediate
                rs1_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read Data 1 from RegFile
                rs2_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read Data 2 from RegFile
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Current PC
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Next PC
                rd_addr                 : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register Address
                rs1_addr                : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 1 Address (for Forwarding)
                rs2_addr                : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 2 Address (for Forwarding)
                
                uimm                    : STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Unsigned Immediate (CSR)
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Function 3 bits
                funct12                 : STD_LOGIC_VECTOR(11 DOWNTO 0); --! Function 12 bits (System/CSR)
        END RECORD t_id_ex_data;

        CONSTANT C_ID_EX_RESET : t_id_ex_data := (
                reg_write               => '0',
                mem_read                => '0',
                mem_write               => '0',
                wb_src                  => WB_SRC_EX_RESULT,
                src_a                   => SRC_A_RS1,
                src_b                   => SRC_B_RS2,
                opr_type                => OP_R_TYPE,
                opr_unit                => UNIT_ALU,
                instr_tag               => VALID,
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
                rd_bus                  : t_rd_reg_data;                 --! Register file write details
                rs2_data                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Data to be stored (STORE instructions)
                pc                      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Next PC
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Data width (Byte/Half/Word)
                mem_read                : STD_LOGIC;                     --! Read Enable
                mem_write               : STD_LOGIC;                     --! Write Enable
                wb_src                  : t_WritebackSrc;                --! Writeback source
        END RECORD t_ex_mem_data;

        CONSTANT C_EX_MEM_RESET : t_ex_mem_data := (
                rd_bus                  => C_RD_BUS_RESET,
                rs2_data                => (OTHERS => '0'),
                pc                      => (OTHERS => '0'),
                pc4                     => (OTHERS => '0'),
                funct3                  => (OTHERS => '0'),
                mem_read                => '0',
                mem_write               => '0',
                wb_src                  => WB_SRC_EX_RESULT
        );

        --! MEM/WB Pipeline Register Record.
        TYPE t_mem_wb_data IS RECORD
                rd_bus                  : t_rd_reg_data;                 --! Register file write details
                pc4                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC+4
                funct3                  : STD_LOGIC_VECTOR(2 DOWNTO 0);  --! Load extension mode
                wb_src                  : t_WritebackSrc;                --! Writeback Mux selection
        END RECORD t_mem_wb_data;

        CONSTANT C_MEM_WB_RESET : t_mem_wb_data := (
                rd_bus                  => C_RD_BUS_RESET,
                pc4                     => (OTHERS => '0'),
                funct3                  => (OTHERS => '0'),
                wb_src                  => WB_SRC_EX_RESULT
        );

        TYPE t_mem_ex_fb IS RECORD
                pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
                trap : t_mem_trap;
        END RECORD t_mem_ex_fb;


        --! Feedback signals from Execution to Fetch (Branching).
        TYPE t_ex_if_data IS RECORD
                pc_redirect             : STD_LOGIC;                     --! Branch taken
                next_elp                : STD_LOGIC;                     --| ELP status
                redirect_address        : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Target Address
        END RECORD t_ex_if_data;

        TYPE t_ex_pmp_data IS RECORD
                priv_mode   : STD_LOGIC;
                pmpcfg0     : STD_LOGIC_VECTOR(31 DOWNTO 0);
                pmpaddr0    : STD_LOGIC_VECTOR(31 DOWNTO 0);
                pmpaddr1    : STD_LOGIC_VECTOR(31 DOWNTO 0);
                pmpaddr2    : STD_LOGIC_VECTOR(31 DOWNTO 0);
                pmpaddr3    : STD_LOGIC_VECTOR(31 DOWNTO 0);
        END RECORD t_ex_pmp_data;


END PACKAGE rv32i_pkg;
