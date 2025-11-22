LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_unit IS
	PORT (
                i_clk : IN STD_LOGIC;
                i_rst : IN STD_LOGIC;

		-- Data Inputs
		i_pc_id             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_pc4_id            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); -- Pass-through for JAL/JALR
		i_rs1_data_id       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rs2_data_id       : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_immediate_id      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_funct3_id         : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
		i_funct7_id         : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
                i_uimm_id           : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);

		-- Control Signals
		i_ex_op_type_id    : IN  t_ExecControl;
		i_src_a_id      : IN  t_SrcA;
		i_src_b_id      : IN  t_SrcB;
		i_pc_src_id         : IN  t_PcSrc;
                i_unit_en_id : IN t_OperationUnit;

		-- Pass-through Control Signals
		i_mem_read_id       : IN  STD_LOGIC;
		i_mem_write_id      : IN  STD_LOGIC;
		i_reg_write_id      : IN  STD_LOGIC;
		i_wb_src_id         : IN  t_WritebackSrc;

		i_rd_addr_id        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		i_rs1_addr_id       : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rs2_addr_id       : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);

		i_rd_addr_mem : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_addr_wb : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
		i_rd_data_mem      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_rd_data_wb      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs to Hazard Unit and PC Update Logic
		o_branch_taken   : OUT STD_LOGIC;
		o_pc_target_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs 
		o_ex_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_rs2_data       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_pc4            : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_funct3         : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		o_mem_read       : OUT STD_LOGIC;
		o_mem_write      : OUT STD_LOGIC;
		o_reg_write      : OUT STD_LOGIC;
		o_wb_src         : OUT t_WritebackSrc;

                o_trap : OUT STD_LOGIC;
		o_rd_addr        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END ENTITY execution_unit;

ARCHITECTURE structural OF execution_unit IS
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	COMPONENT ex_decode_unit IS
		PORT (
                        i_ex_op_type : IN t_ExecControl;
                        i_funct3     : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
                        i_funct7     : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
                        i_src_a_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        o_trap         : OUT STD_LOGIC;
                        o_csr_write_en : OUT STD_LOGIC;
                        o_alu_command : OUT t_AluOpcodes;
                        o_csr_command : OUT t_CsrOpcodes
		);
	END COMPONENT ex_decode_unit;

	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	COMPONENT branch_condition_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_condition_unit;

	COMPONENT forwarding_unit IS
		PORT (
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_mem : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			i_rd_addr_wb : IN  STD_LOGIC_VECTOR(REGFILE_ADDR_WIDTH - 1 DOWNTO 0);
			o_fwd_a_select   : OUT t_Forward;
			o_fwd_b_select   : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

        COMPONENT csr_unit IS
                PORT (
                        i_clk : IN STD_LOGIC;
                        i_rst : IN STD_LOGIC;
                        i_write_en : IN STD_LOGIC;
                        i_csr_op   : IN t_CsrOpcodes; 
                        i_csr_addr : IN STD_LOGIC_VECTOR(CSR_ADDR_WIDTH - 1 DOWNTO 0);
                        i_csr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        o_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
                );
        END COMPONENT csr_unit;

	-- Internal Signals
	SIGNAL s_input_a    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_alu_command    : t_AluOpcodes;
	SIGNAL s_alu_flags      : t_AluFlags;
	SIGNAL s_alu_result_raw : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_pc_plus_imm    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_is_branch      : STD_LOGIC;

	SIGNAL s_fwd_a_select   : t_Forward;
	SIGNAL s_fwd_b_select   : t_Forward;

	SIGNAL s_input_a_id : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_input_b : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_input_b_id   : STD_LOGIC_VECTOR(31 DOWNTO 0);

        SIGNAL s_csr_write_en : STD_LOGIC;
        SIGNAL s_csr_command : t_CsrOpcodes;

        SIGNAL s_csr_output : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN

        -- Forwarding MUX
	WITH i_src_a_id SELECT
		s_input_a_id <= i_rs1_data_id WHEN SRC_A_RS1,
		i_pc_id WHEN SRC_A_PC,
                ((31 DOWNTO 5 => '0') & i_uimm_id) WHEN SRC_A_UIMM,
		x"00000000" WHEN OTHERS; -- SRC_A_ZERO

        FORWARD_PROC_A : PROCESS (s_fwd_a_select, s_input_a_id, i_rd_data_mem, i_rd_data_wb, i_src_a_id)
        BEGIN
            s_input_a <= s_input_a_id;
            IF i_src_a_id = SRC_A_RS1 THEN
                CASE s_fwd_a_select IS
                    WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_data_mem;
                    WHEN FWD_FROM_MEM_WB => s_input_a <= i_rd_data_wb;
                    WHEN OTHERS          => NULL; 
                END CASE;
            END IF;
        END PROCESS;

	WITH i_src_b_id SELECT
		s_input_b <= s_input_b_id WHEN SRC_B_RS2,
		i_immediate_id WHEN OTHERS; -- SRC_B_IMM

	WITH s_fwd_b_select SELECT
		s_input_b_id <= i_rs2_data_id WHEN FWD_NONE,
		i_rd_data_mem WHEN FWD_FROM_EX_MEM,
		i_rd_data_wb WHEN FWD_FROM_MEM_WB;

        -- Stage 2 Decode Unit
        U_EX_DECODE_UNIT : ex_decode_unit
                 port map(
                    i_ex_op_type => i_ex_op_type_id,
                    i_funct3 => i_funct3_id,
                    i_funct7 => i_funct7_id,
                    i_src_a_data => s_input_a,
                    o_trap => o_trap,
                    o_csr_write_en => s_csr_write_en,
                    o_alu_command => s_alu_command,
                    o_csr_command => s_csr_command
                );

        -- Forwarding Unit
	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id    => i_rs1_addr_id,
		i_rs2_addr_id    => i_rs2_addr_id,

		i_rd_addr_mem => i_rd_addr_mem,
		i_rd_addr_wb => i_rd_addr_wb,

		o_fwd_a_select   => s_fwd_a_select,
		o_fwd_b_select   => s_fwd_b_select
	);

	-- Main ALU
	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_input_a,
		i_alu_y      => s_input_b,
		o_result     => s_alu_result_raw,
		o_flags      => s_alu_flags
	);


        -- CSR Unit
        U_CSR_UNIT : csr_unit 
        PORT MAP  (
            i_clk => i_clk,
            i_rst => i_rst,
            i_write_en => s_csr_write_en,
            i_csr_op => s_csr_command,
            i_csr_data => s_input_a,
            i_csr_addr => i_immediate_id(11 DOWNTO 0),
            o_read_data => s_csr_output
        );

	-- Branch Adder
	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_pc_id,
		i_imm            => i_immediate_id,
		o_branch_address => s_pc_plus_imm
	);

	-- Control signal to activate the branch condition check
	s_is_branch <= '1' WHEN i_pc_src_id = PC_SRC_BRANCH ELSE '0';

	-- Instantiate the Branch Condition checker
	U_BRANCH_CONDITION : branch_condition_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_funct3_id,
		i_branch_active => s_is_branch,
		o_branch_taken  => o_branch_taken
	);

	-- Mux for the final PC target address
	WITH i_ex_op_type_id SELECT
		o_pc_target_addr <= s_alu_result_raw WHEN OP_JUMP, -- Covers JALR
		s_pc_plus_imm WHEN OTHERS; -- Covers JAL and Branches

	-- Pass-through signals to the EX/MEM register
	o_rs2_data   <= s_input_b_id;
	o_pc4        <= i_pc4_id;
	o_mem_read   <= i_mem_read_id;
	o_mem_write  <= i_mem_write_id;
	o_reg_write  <= i_reg_write_id;
	o_wb_src     <= i_wb_src_id;
	o_rd_addr    <= i_rd_addr_id;
	o_funct3     <= i_funct3_id;

	-- Final ALU/CSR result to pass to the next stage
        WITH i_unit_en_id SELECT
        o_ex_result <= s_csr_output     WHEN UNIT_CSR,
                       s_alu_result_raw WHEN UNIT_ALU,
                       (OTHERS => '0')  WHEN OTHERS;


END ARCHITECTURE structural;

