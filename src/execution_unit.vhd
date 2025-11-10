LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.rv32i_pkg.ALL;

ENTITY execution_unit IS 
        PORT (
                clk : IN std_logic;
                rst : IN std_logic;

                opcode : IN exec_opcodes_t;
                input1 : IN std_logic_vector(31 DOWNTO 0);
                input2 : IN std_logic_vector(31 DOWNTO 0);

                jump_output : OUT std_logic_vector(31 DOWNTO 0);
                rd_output : OUT std_logic_vector(31 DOWNTO 0)
        );
END ENTITY execution_unit;

ARCHITECTURE behavioral of execution_unit IS 
        COMPONENT alu 
                PORT (
                        alu_opcode : IN alu_opcodes_t; 
                        alu_x : IN std_logic_vector(31 DOWNTO 0); 
                        alu_y : IN std_logic_vector(31 DOWNTO 0); 
                        result : OUT std_logic_vector(31 DOWNTO 0)
                );
        END COMPONENT;

        SIGNAL alu_opcode : alu_opcodes_t;
        SIGNAL alu_input1 : std_logic_vector(31 DOWNTO 0);
        SIGNAL alu_input2 : std_logic_vector(31 DOWNTO 0);
        SIGNAL alu_result : std_logic_vector(31 DOWNTO 0);
BEGIN

        alu_inst : alu
        PORT MAP (
            alu_opcode => alu_opcode, 
            alu_x  => alu_input1,
            alu_y  => alu_input2,
            result => alu_result
        );

        execute_operation : PROCESS (clk)
        BEGIN
                IF rising_edge(clk) THEN 
                        alu_input1 <= (OTHERS => '0');
                        alu_input2 <= (OTHERS => '0');
                        alu_opcode <= ALU_ADD;
                        CASE opcode IS
                                -- Load Upper Immediate
                                WHEN OP_LUI =>
                                        output <= input2;

                                -- Add Upper Immediate to PC
                                WHEN OP_AUIPC =>
                                        alu_input1 <= input1;       
                                        alu_input2 <= input2;
                                        alu_opcode <= ALU_ADD;

                                        output <= alu_result;

                                -- Jump and Link
                                WHEN OP_JAL =>
                                        alu_input1 <= input1;       
                                        alu_input2 <= input2;
                                        alu_opcode <= ALU_ADD;

                                        jump <= std_logic_vector(signed(input2) + B"100");
                                        output <= alu_result;

                                -- Jump and Link Register
                                WHEN OP_JALR =>
                                -- Branch If Equal
                                WHEN OP_BEQ =>
                                -- Branch If Not Equal
                                WHEN OP_BNE =>
                                -- Branch if Less Than
                                WHEN OP_BLT =>
                                -- Branch if Greater Than
                                WHEN OP_BGE =>
                                -- Branch if Less Than Unsigned
                                WHEN OP_BLTU =>
                                -- Branch if Greater Than Unsigned
                                WHEN OP_BGEU =>
                                -- Load Byte
                                WHEN OP_LB =>
                                -- Load Half Word
                                WHEN OP_LH =>
                                -- Load Word
                                WHEN OP_LW =>
                                -- Load Byte Unsigned
                                WHEN OP_LBU =>
                                -- Load Half Word Unsigned
                                WHEN OP_LHU =>
                                -- Store Byte
                                WHEN OP_SB =>
                                -- Store Half Word
                                WHEN OP_SH =>
                                -- Store Word
                                WHEN OP_SW =>
                                -- Add
                                WHEN OP_ADD =>
                                -- Set Less Than
                                WHEN OP_SLT =>
                                -- Set Less Than Unsigned
                                WHEN OP_SLTU =>
                                -- XOR
                                WHEN OP_XOR =>
                                -- OR
                                WHEN OP_OR =>
                                -- AND
                                WHEN OP_AND =>
                                -- Shift Left Logical
                                WHEN OP_SLL =>
                                -- Shift Right Logical
                                WHEN OP_SRL =>
                                -- Shift Right Arithmetic
                                WHEN OP_SRA =>
                                -- Subtract
                                WHEN OP_SUB =>
                                -- Fence
                                WHEN OP_FENCE =>
                                -- Fence TSO
                                WHEN OP_FENCE_TSO =>
                                -- Pause 
                                WHEN OP_PAUSE =>
                                -- Environment Call
                                WHEN OP_ECALL =>
                                -- Environment Break
                                WHEN OP_EBREAK =>
                                -- Invalid
                                WHEN OP_INVALID =>
                                WHEN OTHERS =>
                        END CASE;
                END IF;
        END PROCESS execute_operation;

END ARCHITECTURE behavioral;
