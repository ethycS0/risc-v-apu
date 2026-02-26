LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY execution_stage IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		o_msse       : OUT STD_LOGIC;
                o_pipeline_flush : OUT STD_LOGIC;

		i_id_ex_bus  : IN t_id_ex_data;
		i_wb_ex_bus  : IN t_wb_ex_fb;
        
		i_rd_mem_bus : IN t_rd_reg_data;
		i_rd_wb_bus  : IN t_rd_reg_data;

		i_csr_mem_bus : IN t_csr_reg_data;
		i_csr_wb_bus  : IN t_csr_reg_data;

		o_ex_pmp_csr : OUT t_ex_pmp_data;
		o_ex_if_bus  : OUT t_ex_if_data;
		o_ex_mem_bus : OUT t_ex_mem_data

	);
END ENTITY execution_stage;

ARCHITECTURE structural OF execution_stage IS

	COMPONENT alu IS
		PORT (
			i_alu_opcode : IN  t_AluOpcodes;
			i_alu_x      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_alu_y      : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_result     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_flags      : OUT t_AluFlags
		);
	END COMPONENT alu;

	COMPONENT ex_control_unit IS
		PORT (
			i_opr_type     : IN  t_OprType;
			i_funct3       : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_funct12      : IN  STD_LOGIC_VECTOR(11 DOWNTO 0);
			i_src_a_data   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_csr_write_en : OUT STD_LOGIC;
			o_trap_type    : OUT t_fault_tag;
			o_alu_command  : OUT t_AluOpcodes;
			o_csr_command  : OUT t_CsrOpcodes
		);
	END COMPONENT ex_control_unit;

	COMPONENT branch_adder IS
		PORT (
			i_pc             : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_imm            : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_branch_address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
		);
	END COMPONENT branch_adder;

	COMPONENT branch_control_unit IS
		PORT (
			i_flags         : IN  t_AluFlags;
			i_funct3        : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			i_branch_active : IN  STD_LOGIC;
			o_branch_taken  : OUT STD_LOGIC
		);
	END COMPONENT branch_control_unit;

	COMPONENT forwarding_unit IS
		PORT (
                        i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
                        i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
                        i_csr_addr_id : IN STD_LOGIC_VECTOR(11 DOWNTO 0);

                        i_rd_addr_mem   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
                        i_reg_write_mem : IN STD_LOGIC;

                        i_csr_addr_mem  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
                        i_csr_write_mem : IN STD_LOGIC;

                        i_rd_addr_wb   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
                        i_reg_write_wb : IN STD_LOGIC;

                        i_csr_addr_wb  : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
                        i_csr_write_wb : IN STD_LOGIC;

                        o_csr_fwd_select : OUT t_Forward;
                        o_fwd_a_select   : OUT t_Forward;
                        o_fwd_b_select   : OUT t_Forward
		);
	END COMPONENT forwarding_unit;

	COMPONENT csr_unit IS
		PORT (
                        i_clk : IN STD_LOGIC;  --! Global clock
                        i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

                        i_csr_raddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
                        o_csr_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

                        i_csr_wbus        : IN t_csr_reg_data;
                        i_trap            : IN STD_LOGIC;
                        i_trap_pc         : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        i_trap_mtval      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        i_trap_mcause     : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        i_minstret        : IN STD_LOGIC;
                        i_mret            : IN STD_LOGIC;

                        o_pmp_csr       : OUT t_ex_pmp_data;
                        o_pmp_changed   : OUT STD_LOGIC;
                        o_lpad_en       : OUT STD_LOGIC;                     
                        o_mtvec         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); 
                        o_mepc          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); 
                        o_msse          : OUT STD_LOGIC
		);
	END COMPONENT csr_unit;

	SIGNAL s_alu_command : t_AluOpcodes;
	SIGNAL s_alu_flags   : t_AluFlags;
	SIGNAL s_alu_result  : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_is_branch     : STD_LOGIC;
	SIGNAL s_branch_taken  : STD_LOGIC;
	SIGNAL s_branch_target : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_fwd_a_select   : t_Forward;
	SIGNAL s_fwd_b_select   : t_Forward;
	SIGNAL s_csr_fwd_select : t_Forward;

	SIGNAL s_input_a              : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_input_b              : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_rs2_data_fwd         : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_actual_csr_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_new_csr_value        : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_csr_write_en : STD_LOGIC;
	SIGNAL s_csr_command  : t_CsrOpcodes;
	SIGNAL s_csr_addr_mux : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL s_csr_output   : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL s_trap_type    : t_fault_tag;
        SIGNAL s_cause_code   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_trap_mtval   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mtvec_val    : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_mepc_val     : STD_LOGIC_VECTOR(31 DOWNTO 0);
        SIGNAL s_lpad_en : STD_LOGIC;
        SIGNAL s_pmp_changed : STD_LOGIC;
        SIGNAL s_fault_tag : t_fault_tag;

BEGIN
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

	U_FORWARDING : forwarding_unit
	PORT MAP(
		i_rs1_addr_id   => i_id_ex_bus.rs1_addr,
		i_rs2_addr_id   => i_id_ex_bus.rs2_addr,
		i_csr_addr_id   => s_csr_addr_mux,
		i_rd_addr_mem   => i_rd_mem_bus.rd_addr,
		i_reg_write_mem => i_rd_mem_bus.reg_write_en,
		i_rd_addr_wb    => i_rd_wb_bus.rd_addr,
		i_reg_write_wb  => i_rd_wb_bus.reg_write_en,
		i_csr_addr_mem  => i_csr_mem_bus.csr_addr,
		i_csr_addr_wb   => i_csr_wb_bus.csr_addr,
		i_csr_write_mem => i_csr_mem_bus.csr_write_en,
		i_csr_write_wb  => i_csr_wb_bus.csr_write_en,
                o_csr_fwd_select => s_csr_fwd_select,
		o_fwd_a_select  => s_fwd_a_select,
		o_fwd_b_select  => s_fwd_b_select
	);

	U_MAIN_ALU : alu
	PORT MAP(
		i_alu_opcode => s_alu_command,
		i_alu_x      => s_input_a,
		i_alu_y      => s_input_b,
		o_result     => s_alu_result,
		o_flags      => s_alu_flags
	);

	U_CSR_UNIT : csr_unit
	PORT MAP(
		i_clk => i_clk,
		i_rst => i_rst,

		i_csr_raddr => s_csr_addr_mux,
		o_csr_rdata => s_csr_output,

		i_csr_wbus    => i_wb_ex_bus.csr_bus,
		i_trap        => i_wb_ex_bus.trap,
		i_trap_pc     => i_wb_ex_bus.mepc,
		i_trap_mtval  => i_wb_ex_bus.mtval,
		i_trap_mcause => i_wb_ex_bus.mcause,
		i_minstret    => i_wb_ex_bus.minstret,
                i_mret        => i_wb_ex_bus.mret,

		o_pmp_csr     => o_ex_pmp_csr,
		o_pmp_changed => s_pmp_changed,
		o_lpad_en     => s_lpad_en,
		o_mtvec       => s_mtvec_val,
		o_mepc        => s_mepc_val
	);

	U_BRANCH_ADDER : branch_adder
	PORT MAP(
		i_pc             => i_id_ex_bus.pc,
		i_imm            => i_id_ex_bus.immediate,
		o_branch_address => s_branch_target
	);


	U_BRANCH_CONTROL : branch_control_unit
	PORT MAP(
		i_flags         => s_alu_flags,
		i_funct3        => i_id_ex_bus.funct3,
		i_branch_active => s_is_branch,
		o_branch_taken  => s_branch_taken
	);

        -- Forwarding
	P_INPUT_SEL_FWD : PROCESS (ALL)
	BEGIN
		s_input_a      <= x"00000000";
		s_input_b      <= x"00000000";
		s_rs2_data_fwd <= x"00000000";

		IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
			CASE s_fwd_a_select IS
				WHEN FWD_FROM_EX_MEM => s_input_a <= i_rd_mem_bus.rd_data;
				WHEN FWD_FROM_MEM_WB => s_input_a <= i_wb_ex_bus.fwd;
				WHEN OTHERS => s_input_a <= i_id_ex_bus.rs1_data;
			END CASE;
		ELSIF i_id_ex_bus.src_a = SRC_A_PC THEN
			s_input_a <= i_id_ex_bus.pc;
		ELSIF i_id_ex_bus.src_a = SRC_A_UIMM THEN
			s_input_a <= ((31 DOWNTO 5 => '0') & i_id_ex_bus.uimm);
		END IF;

		CASE s_fwd_b_select IS
			WHEN FWD_FROM_EX_MEM => s_rs2_data_fwd <= i_rd_mem_bus.rd_data;
			WHEN FWD_FROM_MEM_WB => s_rs2_data_fwd <= i_wb_ex_bus.fwd;
			WHEN OTHERS  => s_rs2_data_fwd <= i_id_ex_bus.rs2_data;
		END CASE;

		IF i_id_ex_bus.src_b = SRC_B_RS2 THEN
			s_input_b <= s_rs2_data_fwd;
		ELSIF i_id_ex_bus.src_b = SRC_B_IMM THEN
			s_input_b <= i_id_ex_bus.immediate;
		END IF;

	END PROCESS;

	s_csr_addr_mux <= x"341" WHEN s_trap_type = TRAP_MRET ELSE i_id_ex_bus.funct12;
	P_CSR_FWD_MUX : PROCESS (ALL)
	BEGIN
		CASE s_csr_fwd_select IS
			WHEN FWD_FROM_EX_MEM => s_actual_csr_read_data <= i_csr_mem_bus.csr_data;
			WHEN FWD_FROM_MEM_WB => s_actual_csr_read_data <= i_csr_wb_bus.csr_data;
			WHEN OTHERS => s_actual_csr_read_data <= s_csr_output;
		END CASE;
	END PROCESS;

        -- Calculation
	P_CSR_ALU : PROCESS (ALL)
	BEGIN
		CASE s_csr_command IS
			WHEN CSR_RW =>
				s_new_csr_value <= s_input_a;

			WHEN CSR_RS =>
				s_new_csr_value <= s_actual_csr_read_data OR s_input_a;

			WHEN CSR_RC =>
				s_new_csr_value <= s_actual_csr_read_data AND (NOT s_input_a);

			WHEN CSR_SSW =>
				s_new_csr_value <= STD_LOGIC_VECTOR(unsigned(s_actual_csr_read_data) - 4);

			WHEN CSR_SSR =>
				s_new_csr_value <= STD_LOGIC_VECTOR(unsigned(s_actual_csr_read_data) + 4);

			WHEN OTHERS =>
				s_new_csr_value <= s_actual_csr_read_data;
		END CASE;
	END PROCESS;

        -- Output Selection
	P_RD_SEL : PROCESS (ALL)
	BEGIN
                IF s_fault_tag = EX_REDIR_MISALIGNED THEN
                        IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
                                o_ex_mem_bus.rd_bus.rd_data <= s_alu_result(31 DOWNTO 1) & '0';
                        ELSE
                                o_ex_mem_bus.rd_bus.rd_data <= s_branch_target; 
                        END IF;

		ELSIF i_id_ex_bus.wb_src = WB_SRC_PC4 THEN
			o_ex_mem_bus.rd_bus.rd_data <= i_id_ex_bus.pc4;

		ELSIF i_id_ex_bus.opr_unit = UNIT_CSR THEN
			o_ex_mem_bus.rd_bus.rd_data <= s_actual_csr_read_data;

		ELSE
			o_ex_mem_bus.rd_bus.rd_data <= s_alu_result;
		END IF;
	END PROCESS;


        -- Trap and Redirection
        P_FAULT_TAG : PROCESS (ALL)
        BEGIN
                s_fault_tag <= i_id_ex_bus.fault_tag;
                IF i_id_ex_bus.elp_active = '1' AND s_lpad_en = '1' THEN
                        IF i_id_ex_bus.opr_type /= OP_LPAD THEN
                                s_fault_tag <= EX_LPAD_FAULT;
                        ELSIF s_alu_flags.zero = '0' THEN
                                s_fault_tag <= EX_LPAD_FAULT;
                        END IF;
                ELSIF i_id_ex_bus.fault_tag = VALID THEN 
                        IF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_PC THEN
                                IF s_branch_target(1 DOWNTO 0) /= "00" THEN
                                        s_fault_tag <= EX_REDIR_MISALIGNED;
                                END IF;

                        ELSIF i_id_ex_bus.opr_type = OP_JUMP AND i_id_ex_bus.src_a = SRC_A_RS1 THEN
                                IF s_alu_result(1) = '1' THEN
                                        s_fault_tag <= EX_REDIR_MISALIGNED;
                                END IF;

                        ELSIF i_id_ex_bus.opr_type = OP_BRANCH AND s_branch_taken = '1' THEN
                                IF s_branch_target(1) = '1' THEN
                                        s_fault_tag <= EX_REDIR_MISALIGNED;
                                END IF;
                        ELSE
                                IF s_trap_type = TRAP_ECALL OR s_trap_type = TRAP_EBREAK or s_trap_type = TRAP_MRET THEN
                                        s_fault_tag <= s_trap_type;
                                END IF;
                        END IF;
                END IF;
        END PROCESS P_FAULT_TAG;

	s_is_branch <= '1' WHEN i_id_ex_bus.opr_type = OP_BRANCH ELSE '0';
	P_PC_REDR : PROCESS (ALL)
	BEGIN
		o_ex_if_bus.pc_redirect      <= '0';
		o_ex_if_bus.next_elp         <= '0';
		o_ex_if_bus.redirect_address <= s_branch_target;

                IF i_wb_ex_bus.trap = '1' THEN
                        o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mtvec_val;

                ELSIF i_wb_ex_bus.mret = '1' THEN
                        o_ex_if_bus.pc_redirect <= '1';
			o_ex_if_bus.redirect_address <= s_mepc_val;

		ELSIF i_id_ex_bus.opr_type = OP_JUMP THEN
                        o_ex_if_bus.pc_redirect <= '1' WHEN s_fault_tag = VALID ELSE '0';
			IF i_id_ex_bus.src_a = SRC_A_RS1 THEN
				o_ex_if_bus.redirect_address <= s_alu_result(31 DOWNTO 1) & '0';
				IF i_id_ex_bus.rs1_addr /= "00001" AND i_id_ex_bus.rs1_addr /= "00101" AND s_lpad_en = '1' THEN
					o_ex_if_bus.next_elp <= '1';
				END IF;

			ELSE
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;

		ELSIF i_id_ex_bus.opr_type = OP_BRANCH THEN
			IF s_branch_taken = '1' THEN
                                o_ex_if_bus.pc_redirect <= '1' WHEN s_fault_tag = VALID ELSE '0';
				o_ex_if_bus.redirect_address <= s_branch_target;
			END IF;

		END IF;
	END PROCESS;

        o_ex_mem_bus.mem_read             <= i_id_ex_bus.mem_read WHEN s_fault_tag = VALID ELSE '0';
	o_ex_mem_bus.mem_write            <= i_id_ex_bus.mem_write WHEN s_fault_tag = VALID ELSE '0';
	o_ex_mem_bus.rd_bus.reg_write_en  <= i_id_ex_bus.reg_write WHEN s_fault_tag = VALID ELSE '0';
	o_ex_mem_bus.csr_bus.csr_write_en <= s_csr_write_en WHEN s_fault_tag = VALID ELSE '0';

	o_ex_mem_bus.rs2_data             <= s_rs2_data_fwd;
	o_ex_mem_bus.pc4                  <= i_id_ex_bus.pc4;
	o_ex_mem_bus.wb_src               <= i_id_ex_bus.wb_src;
	o_ex_mem_bus.rd_bus.rd_addr       <= i_id_ex_bus.rd_addr;
	o_ex_mem_bus.funct3               <= i_id_ex_bus.funct3;
	o_ex_mem_bus.pc                   <= i_id_ex_bus.pc;

	o_ex_mem_bus.csr_bus.csr_data     <= s_new_csr_value;
	o_ex_mem_bus.csr_bus.csr_addr     <= s_csr_addr_mux;
        o_ex_mem_bus.fault_tag <=s_fault_tag;

        o_pipeline_flush <= '1' WHEN (s_fault_tag /= VALID OR o_ex_if_bus.pc_redirect = '1') ELSE '0';

END ARCHITECTURE structural;

