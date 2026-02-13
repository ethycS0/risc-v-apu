--! @file execution_stage.vhd
--! Execution Stage
--! @author ethycS
--! @details This module implements the Execute (EX) stage of the RV32I pipeline.
--! It is responsible for performing arithmetic/logical operations, branch evaluation,
--! address calculation, CSR operations, and handling control flow changes.
--!
--! The EX stage integrates the following components:
--! - ALU: Performs arithmetic, logical, shift, and comparison operations
--! - Branch Control Unit: Evaluates branch conditions
--! - Branch Adder: Calculates branch/jump target addresses
--! - Forwarding Unit: Resolves data hazards via operand forwarding
--! - CSR Unit: Handles Control and Status Register operations
--! - EX Control Unit: Generates ALU/CSR commands and trap signals
--!
--! Key features:
--! - Operand forwarding from MEM and WB stages to resolve data hazards
--! - Branch/jump target calculation and redirect signaling to IF stage
--! - Trap entry (ECALL, EBREAK) and return (MRET) handling
--! - CSR read/write operations with proper operand selection
--! - Multiplexed operand sources (RS1, RS2, PC, immediate, UIMM)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_stage IS
	PORT (
		i_clk : IN STD_LOGIC;  --! Global clock
		i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

		i_minstret_increment_wb : IN STD_LOGIC;  --! Instruction retired signal from WB stage (for minstret counter)
                i_mem_ex_trap           : IN t_mem_ex_fb;

		i_id_ex_bus  : IN t_id_ex_data;                   --! Input bus from ID stage (decoded instruction and operands)
		i_rd_mem_bus : IN t_rd_reg_data;                  --! Writeback data from MEM stage (for forwarding)
		i_rd_wb_bus  : IN t_rd_reg_data;                  --! Writeback data from WB stage (for forwarding)
		i_rd_wb_fwd  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Writeback data forwarding path (Separate due to Load bypass)

                o_ex_trap    : OUT STD_LOGIC;     --| Kill Switch for Exceptions
		o_ex_if_bus  : OUT t_ex_if_data;  --! Feedback bus to IF stage (branch/jump redirect signals)
		o_ex_mem_bus : OUT t_ex_mem_data  --! Output bus to MEM stage (ALU result, control signals)

	);
END ENTITY execution_stage;

ARCHITECTURE structural OF execution_stage IS

	--! ALU component declaration
	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	--! Execute stage control unit component declaration
	COMPONENT ex_control_unit IS
		PORT (
			i_opr_type     : IN  t_OprType;
			i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_csr_write_en : OUT STD_LOGIC;
			o_trap_type    : OUT t_TrapType;
			o_alu_command  : OUT t_AluOpcodes;
			o_csr_command  : OUT t_CsrOpcodes
		);
	END COMPONENT ex_control_unit;

	--! Branch target adder component declaration
	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	--! Branch condition evaluator component declaration
	COMPONENT branch_control_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_control_unit;

	--! Data hazard forwarding unit component declaration
	COMPONENT forwarding_unit IS
		PORT (
			i_rs1_addr_id   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rd_addr_mem   : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_mem : IN  STD_LOGIC;
			i_rd_addr_wb    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_reg_write_wb  : IN  STD_LOGIC;
			o_fwd_a_select  : OUT t_Forward;
			o_fwd_b_select  : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	--! CSR unit component declaration
	COMPONENT csr_unit IS
		PORT (
			i_clk                : IN  STD_LOGIC;
			i_rst                : IN  STD_LOGIC;
			i_write_en           : IN  STD_LOGIC;
			i_minstret_increment : IN  STD_LOGIC;
			i_is_mret            : IN  STD_LOGIC;
			i_csr_op             : IN  t_CsrOpcodes;
			i_csr_addr           : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_csr_data           : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_triggered     : IN  STD_LOGIC;
			i_pc_at_trap         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_cause_code         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_trap_mtval         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
                        o_lpad_en            : OUT STD_LOGIC;
			o_mtvec              : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mepc               : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_read_data          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT csr_unit;

	SIGNAL s_alu_command   : t_AluOpcodes;                   --! ALU operation command from EX control unit
	SIGNAL s_alu_flags     : t_AluFlags;                     --! ALU status flags (carry, overflow, negative, zero)
	SIGNAL s_alu_result    : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! ALU computation result

	SIGNAL s_is_branch     : STD_LOGIC;                      --! Branch instruction active flag
	SIGNAL s_branch_taken  : STD_LOGIC;                      --! Branch condition satisfied signal
	SIGNAL s_branch_target : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Branch/jump target address (PC + immediate)

	SIGNAL s_fwd_a_select : t_Forward; --! Forwarding control for operand A 
	SIGNAL s_fwd_b_select : t_Forward; --! Forwarding control for operand B 

	SIGNAL s_input_a      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Final ALU input A (after forwarding and source mux)
	SIGNAL s_input_b      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Final ALU input B (after forwarding and source mux)
	SIGNAL s_rs2_data_fwd : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Forwarded RS2 data (for store instructions)

	SIGNAL s_csr_write_en : STD_LOGIC;                      --! CSR write enable signal
	SIGNAL s_csr_command  : t_CsrOpcodes;                   --! CSR operation command (RW, RS, RC)
	SIGNAL s_csr_addr_mux : STD_LOGIC_VECTOR(11 DOWNTO 0);  --! CSR address mux (funct12 or mepc for MRET)
	SIGNAL s_csr_output   : STD_LOGIC_VECTOR(31 DOWNTO 0);  --! CSR read data output

	SIGNAL s_trap_trigger : STD_LOGIC;  --! Trap entry signal (for ECALL/EBREAK)
	SIGNAL s_trap_type    : t_TrapType; --! Trap type (ECALL, EBREAK, MRET, or NONE)
	SIGNAL s_is_mret      : STD_LOGIC;  --! MRET instruction detected

	SIGNAL s_cause_code   : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap cause code for CSR
	SIGNAL s_trap_mtval   : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap value (bad address/instruction) for CSR
	SIGNAL s_mtvec_val    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Machine trap vector address
	SIGNAL s_mepc_val     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Machine exception PC (return address)

        SIGNAL s_trap_pc : STD_LOGIC_VECTOR(31 DOWNTO 0);
        SIGNAL s_target_misaligned : STD_LOGIC;

        SIGNAL s_lpad_trap : STD_LOGIC;
        SIGNAL s_lpad_en : STD_LOGIC;

BEGIN

	--! @brief Execute Control Unit Instance
	--! @details Decodes operation type and function fields to generate ALU/CSR commands
	--! and trap signals
	U_EX_DECODE_UNIT : ex_control_unit
	PORT MAP(
		i_opr_type     => i_id_ex_bus.opr_type,
		i_funct3       => i_id_ex_bus.funct3,
		i_funct12      => i_id_ex_bus.funct12,
		i_src_a_data   => s_input_a,
		o_trap_type    => s_trap_type,
		o_csr_write_en => s_csr_write_en,
		o_alu_command  => s_alu_command,
		o_csr_command  => s_csr_command
	);

	--! @brief Forwarding Unit Instance
	--! @details Detects data hazards and generates forwarding control signals to resolve
	--! dependencies with instructions in MEM and WB stages
	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id   => i_id_ex_bus.rs1_addr,
		i_rs2_addr_id   => i_id_ex_bus.rs2_addr,
		i_rd_addr_mem   => i_rd_mem_bus.rd_addr,
		i_reg_write_mem => i_rd_mem_bus.reg_write_en,
		i_rd_addr_wb    => i_rd_wb_bus.rd_addr,
		i_reg_write_wb  => i_rd_wb_bus.reg_write_en,
		o_fwd_a_select  => s_fwd_a_select,
		o_fwd_b_select  => s_fwd_b_select
	);

	--! @brief ALU Instance
	--! @details Performs arithmetic, logical, shift, and comparison operations based on
	--! the ALU command and forwarded operands
	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_input_a,
		i_alu_y      => s_input_b,
		o_result     => s_alu_result,
		o_flags      => s_alu_flags
	);

	--! @brief CSR Unit Instance
	--! @details Implements Control and Status Registers with trap handling support
	U_CSR_UNIT : csr_unit
	PORT MAP(
		i_clk                => i_clk,
		i_rst                => i_rst,
		i_write_en           => s_csr_write_en,
		i_minstret_increment => i_minstret_increment_wb,
		i_is_mret            => s_is_mret,
		i_csr_op             => s_csr_command,
		i_csr_data           => s_input_a,
		i_csr_addr           => s_csr_addr_mux,
		i_trap_triggered     => s_trap_trigger,
		i_pc_at_trap         => s_trap_pc,
		i_cause_code         => s_cause_code,
		i_trap_mtval         => s_trap_mtval,
                o_lpad_en            => s_lpad_en,
		o_mtvec              => s_mtvec_val,
		o_mepc               => s_mepc_val,
		o_read_data          => s_csr_output
	);

	--! @brief Branch Adder Instance
	--! @details Calculates branch/jump target address (PC + immediate offset)
	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_id_ex_bus.pc,
		i_imm            => i_id_ex_bus.immediate,
		o_branch_address => s_branch_target
	);

	--! @brief Branch Control Unit Instance
	--! @details Evaluates branch conditions based on ALU flags and funct3
	U_BRANCH_CONTROL : branch_control_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_id_ex_bus.funct3,
		i_branch_active => s_is_branch,
		o_branch_taken  => s_branch_taken
	);

        s_trap_pc <= (i_mem_ex_trap.pc)  WHEN (i_mem_ex_trap.trap /= VALID) ELSE i_id_ex_bus.pc;

	--! @brief Input Operand Selection and Forwarding Process
	--! @details Combinational process that selects ALU operands based on source control
	--! signals and applies data forwarding from MEM/WB stages. Operand A can come from
	--! RS1, PC, or UIMM (zero-extended 5-bit immediate for CSR instructions). Operand B
	--! can come from RS2 or sign-extended immediate. Forwarding logic resolves data
	--! hazards by bypassing results from later pipeline stages when register dependencies
	--! are detected.
	P_INPUT_SEL_FWD : PROCESS (ALL)
	BEGIN
		s_input_a <= x"00000000";
		s_input_b <= x"00000000";
		s_rs2_data_fwd <= x"00000000";

		-- Operand A selection with forwarding
		IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
			CASE s_fwd_a_select IS
				WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_mem_bus.rd_data;  -- Forward from MEM stage
				WHEN FWD_FROM_MEM_WB => s_input_a <= i_rd_wb_fwd;           -- Forward from WB stage
				WHEN OTHERS => s_input_a <= i_id_ex_bus.rs1_data;           -- Use ID rs1 value
			END CASE;
		ELSIF i_id_ex_bus.src_a = SRC_A_PC THEN
			s_input_a <= i_id_ex_bus.pc;                             -- Use PC for AUIPC, JAL
		ELSIF i_id_ex_bus.src_a = SRC_A_UIMM THEN
			s_input_a <= ((31 DOWNTO 5 => '0') & i_id_ex_bus.uimm);  -- Zero-extended UIMM for CSR immediate
		END IF;

		-- RS2 forwarding (used for both operand B and store data)
		CASE s_fwd_b_select IS
			WHEN FWD_FROM_EX_MEM => s_rs2_data_fwd <= i_rd_mem_bus.rd_data;  -- Forward from MEM stage
			WHEN FWD_FROM_MEM_WB => s_rs2_data_fwd <= i_rd_wb_fwd;           -- Forward from WB stage
			WHEN OTHERS => s_rs2_data_fwd <= i_id_ex_bus.rs2_data;           -- Use ID rs2 value
		END CASE;

		-- Operand B selection (RS2 or immediate)
		IF i_id_ex_bus.src_b = SRC_B_RS2 THEN
			s_input_b <= s_rs2_data_fwd;
		ELSIF i_id_ex_bus.src_b = SRC_B_IMM THEN
			s_input_b <= i_id_ex_bus.immediate;
		END IF;
	END PROCESS;

        P_CHECK_INSTR_ALIGN : PROCESS (ALL)
        BEGIN
                s_target_misaligned <= '0'; 

                IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_PC THEN
                        IF s_branch_target(1 DOWNTO 0) /= "00" THEN
                                s_target_misaligned <= '1';
                        END IF;

                ELSIF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
                        IF s_alu_result(1) = '1' THEN
                                s_target_misaligned <= '1';
                        END IF;

                ELSIF i_id_ex_bus.opr_type = OP_BRANCH AND s_branch_taken = '1' THEN
                        IF s_branch_target(1) = '1' THEN
                                s_target_misaligned <= '1';
                        END IF;
                END IF;
        END PROCESS;


	--! @brief Writeback Data Selection Process
	--! @details Combinational process that selects the appropriate result to write back
	--! to the register file. Sources include:
	--! - PC+4: For JAL/JALR instructions (return address)
	--! - CSR output: For CSR read instructions
	--! - ALU result: For arithmetic, logical, address calculation
	P_RD_SEL : PROCESS (i_id_ex_bus, s_alu_result, s_csr_output)
	BEGIN
		IF i_id_ex_bus.wb_src = WB_SRC_PC4 THEN
			o_ex_mem_bus.rd_bus.rd_data <= i_id_ex_bus.pc4;  -- Return address for jumps

		ELSIF i_id_ex_bus.opr_unit = UNIT_CSR THEN
			o_ex_mem_bus.rd_bus.rd_data <= s_csr_output;  -- CSR read value

		ELSE
			o_ex_mem_bus.rd_bus.rd_data <= s_alu_result;  -- ALU result
		END IF;
	END PROCESS;

        P_CHECK_LPAD : PROCESS (i_id_ex_bus, s_alu_flags, s_lpad_en)
        BEGIN
                s_lpad_trap <= '0';
                IF i_id_ex_bus.elp = '1' AND s_lpad_en = '1' THEN
                        IF i_id_ex_bus.opr_type /= OP_LPAD THEN 
                                s_lpad_trap <= '1';
                        ELSIF s_alu_flags.zero = '0' THEN 
                                s_lpad_trap <= '1';
                        END IF;
                END IF;
        END PROCESS P_CHECK_LPAD;


	-- Trap type decoding
	s_is_mret <= '1' WHEN s_trap_type = TRAP_MRET ELSE '0';
	s_trap_trigger <= '1' WHEN (s_target_misaligned ='1' OR s_trap_type = TRAP_CALL OR s_trap_type = TRAP_BREAK OR s_lpad_trap = '1' OR i_mem_ex_trap.trap /= VALID) ELSE '0';
	
	-- CSR address mux (use mepc address for MRET, otherwise funct12)
	s_csr_addr_mux <= x"341" WHEN s_trap_type = TRAP_MRET ELSE i_id_ex_bus.funct12;

	-- Trap cause code assignment
        P_CSR_CAUSE : PROCESS (s_lpad_trap, s_trap_type, i_mem_ex_trap, s_target_misaligned)
        BEGIN
                IF i_mem_ex_trap.trap /= VALID THEN
                        CASE i_mem_ex_trap.trap IS 
                                WHEN L_MISALIGNED =>
                                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(4, 32));
                                WHEN L_ACCESS_FAULT =>
                                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(5, 32));
                                WHEN S_MISALIGNED =>
                                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(6, 32));
                                WHEN S_ACCESS_FAULT =>
                                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(7, 32));
                                WHEN VALID => 
                                        s_cause_code <= (OTHERS => '0');
                        END CASE;

                ELSIF s_target_misaligned = '1' THEN
                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(0, 32));

                ELSIF s_lpad_trap = '1' THEN
                        s_cause_code <= STD_LOGIC_VECTOR(to_unsigned(18, 32));

                ELSIF s_trap_type = TRAP_CALL THEN
                        s_cause_code <= x"0000000B";

                ELSIF s_trap_type = TRAP_BREAK THEN
                        s_cause_code <= x"00000003"; 

                ELSE
                        s_cause_code <= (OTHERS => '0');
                END IF;
        END PROCESS P_CSR_CAUSE;

	-- Trap mtval assignment
        P_CSR_VAL : PROCESS (ALL)
        BEGIN
                IF i_mem_ex_trap.trap /= VALID THEN
                        s_trap_mtval <= i_rd_mem_bus.rd_data;

                ELSIF s_target_misaligned = '1' THEN
                        IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
                                s_trap_mtval <= s_alu_result(31 DOWNTO 1) & '0';
                        ELSE
                                s_trap_mtval <= s_branch_target;
                        END IF;

                ELSIF s_lpad_trap = '1' THEN
                        s_trap_mtval <= (OTHERS => '0');

                ELSIF s_trap_type = TRAP_BREAK THEN
                        s_trap_mtval <= i_id_ex_bus.pc;

                ELSE
                        s_trap_mtval <= (OTHERS => '0');
                END IF;
        END PROCESS P_CSR_VAL;

	-- Branch instruction detection
	s_is_branch <= '1' WHEN i_id_ex_bus.opr_type = OP_BRANCH ELSE '0';

	--! @brief PC Redirect Control Process
	--! @details Combinational process that determines if PC redirection is needed and
	--! calculates the redirect target address. Priority order (highest to lowest):
	--! 1. Trap entry (ECALL/EBREAK): Redirect to mtvec
	--! 2. MRET: Redirect to mepc (return from trap)
	--! 3. Jump (JAL/JALR): Redirect to calculated target
	--! 4. Conditional branch: Redirect if branch condition is satisfied.
        --! 
        --! For JALR, the target address LSB is cleared to ensure alignment. ELP is also set here.
	P_PC_REDR : PROCESS (ALL)
	BEGIN
		o_ex_if_bus.pc_redirect <= '0';
                o_ex_if_bus.next_elp <= '0';
		o_ex_if_bus.redirect_address <= s_branch_target;

		IF s_trap_trigger = '1' THEN  -- Trap entry
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mtvec_val;

		ELSIF s_is_mret = '1' THEN  -- Return from trap
			o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mepc_val;

		ELSIF i_id_ex_bus.opr_type = OP_JUMP THEN  -- JAL/JALR
			o_ex_if_bus.pc_redirect <= '1';
			IF i_id_ex_bus.src_a = SRC_A_RS1 THEN  -- JALR: target = (RS1 + offset) & ~1
				o_ex_if_bus.redirect_address <= s_alu_result(31 DOWNTO 1) & '0';
                                IF i_id_ex_bus.rs1_addr /= "00001" AND i_id_ex_bus.rs1_addr /= "00101" AND s_lpad_en = '1' THEN
                                        o_ex_if_bus.next_elp <= '1';
                                END IF;

			ELSE  -- JAL: target = PC + offset
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;

		ELSIF i_id_ex_bus.opr_type = OP_BRANCH THEN  -- Conditional branch
			IF s_branch_taken = '1' THEN
				o_ex_if_bus.pc_redirect <= '1';
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;
		END IF;
	END PROCESS;

        o_ex_trap <= '1' WHEN (s_lpad_trap = '1' OR s_target_misaligned = '1' OR s_trap_type = TRAP_CALL OR s_trap_type = TRAP_BREAK) ELSE '0';

	-- Output bus assignments to MEM stage
	o_ex_mem_bus.rs2_data <= s_rs2_data_fwd;
	o_ex_mem_bus.pc4 <= i_id_ex_bus.pc4;
	o_ex_mem_bus.mem_read <= i_id_ex_bus.mem_read;
	o_ex_mem_bus.mem_write <= i_id_ex_bus.mem_write;
	o_ex_mem_bus.rd_bus.reg_write_en <= i_id_ex_bus.reg_write;
	o_ex_mem_bus.wb_src <= i_id_ex_bus.wb_src;
	o_ex_mem_bus.rd_bus.rd_addr <= i_id_ex_bus.rd_addr;
	o_ex_mem_bus.funct3 <= i_id_ex_bus.funct3;
	o_ex_mem_bus.pc <= i_id_ex_bus.pc;

END ARCHITECTURE structural;

