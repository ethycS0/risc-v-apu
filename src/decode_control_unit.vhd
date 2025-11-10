LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY decode_control_unit IS
    PORT (
        i_instruction     : IN  std_logic_vector(31 DOWNTO 0);

        -- Primary control signals for EX, MEM, WB stages
        o_reg_write     : OUT std_logic;
        o_mem_read      : OUT std_logic;
        o_mem_write     : OUT std_logic;
        o_branch        : OUT std_logic;
        o_jump          : OUT std_logic;

        -- Mux select signals
        o_alu_src       : OUT t_AluSrc;       -- Assuming type from previous answer
        o_wb_src        : OUT t_WritebackSrc; -- Assuming type from previous answer

        -- Intermediate ALUOp type for the ALU Control unit in the next stage
        o_alu_op_type   : OUT t_ExecControl
    );
END ENTITY decode_control_unit;

ARCHITECTURE behavioral OF decode_control_unit IS
BEGIN
    decode_process : PROCESS (i_instruction)
    BEGIN
        -- Default assignments (safer design)
        o_reg_write     <= '0';
        o_mem_read      <= '0';
        o_mem_write     <= '0';
        o_branch        <= '0';
        o_jump          <= '0';
        o_alu_src       <= ALU_SRC_REG; -- Default to register source
        o_wb_src        <= WB_SRC_ALU;  -- Default to ALU result
        o_alu_op_type   <= OP_R_TYPE; -- Default to a safe type

        CASE i_instruction(6 DOWNTO 2) IS

            -- U-Type: LUI
            WHEN "01101" =>
                o_reg_write     <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_alu_op_type   <= OP_LUI;

            -- U-Type: AUIPC
            WHEN "00101" =>
                o_reg_write     <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_alu_op_type   <= OP_AUIPC;

            -- J-Type: JAL
            WHEN "11011" =>
                o_reg_write     <= '1';
                o_jump          <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_wb_src        <= WB_SRC_PC4; -- Special case for JAL
                o_alu_op_type   <= OP_JUMP;

            -- I-Type: JALR
            WHEN "11001" =>
                o_reg_write     <= '1';
                o_jump          <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_wb_src        <= WB_SRC_PC4; -- Special case for JALR
                o_alu_op_type   <= OP_JUMP;

            -- B-Type: Branches
            WHEN "11000" =>
                o_branch        <= '1';
                o_alu_src       <= ALU_SRC_REG;
                o_alu_op_type   <= OP_BRANCH;

            -- I-Type: Loads
            WHEN "00000" =>
                o_reg_write     <= '1';
                o_mem_read      <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_wb_src        <= WB_SRC_MEM;
                o_alu_op_type   <= OP_LOAD_STORE;

            -- S-Type: Stores
            WHEN "01000" =>
                o_mem_write     <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_alu_op_type   <= OP_LOAD_STORE;

            -- I-Type: Immediate arithmetic/logic
            WHEN "00100" =>
                o_reg_write     <= '1';
                o_alu_src       <= ALU_SRC_IMM;
                o_alu_op_type   <= OP_I_TYPE;

            -- R-Type: Register arithmetic/logic
            WHEN "01100" =>
                o_reg_write     <= '1';
                o_alu_src       <= ALU_SRC_REG;
                o_alu_op_type   <= OP_R_TYPE;

            -- FENCE
            WHEN "00011" =>
                -- Handle FENCE, usually a NOP in simple pipelines
                NULL;

            -- SYSTEM (ECALL/EBREAK)
            WHEN "11100" =>
                -- Handle system calls/exceptions
                NULL;

            -- OTHERS (Invalid opcode)
            WHEN OTHERS =>
                -- All signals remain at their default '0' state
                NULL;

        END CASE;
    END PROCESS decode_process;

END ARCHITECTURE behavioral;


