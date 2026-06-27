--! @file writeback_stage.vhd
--! @brief Writeback (WB) pipeline stage and exception controller for the RISC-V processor.
--! @author ethycS
--! @details This module manages the final pipeline writebacks (GPR and CSR updates) and serves
--! as the central trap/exception handler. It parses all pipeline faults, checks security constraints,
--! and formats exception variables (mcause, mtval, mepc) for CSR commitments.
--!
--! Key features and security integrations:
--! - **Smcfiss (Shadow Stack Verification)**: If a shadow stack instruction (`ss_instr`) is active in WB,
--!   it compares the actual return address popped from memory (`s_read_data`) with the expected return address
--!   (`rd_bus.rd_data`). On mismatch, it triggers `WB_SHADOW_STACK_FAULT` and issues a trap (mcause = 18).
--! - **Zicfilp (Landing Pad exceptions)**: Receives landing pad faults (`EX_LPAD_FAULT`), routing them
--!   as trap exceptions with cause = 18.
--! - **Central Exception Controller**: Decodes all execution and memory faults into standard RISC-V mcause
--!   and mtval registers (e.g., fetch access fault = 1, load address misaligned = 4, store access fault = 7, etc.).
--! - **Load Data Alignment**: Extracts bytes and halfwords from the raw 32-bit data memory bus (`i_dmem_data`)
--!   and applies sign/zero extension. Shadow stack instructions bypass alignment and read full 32-bit words.
--! - **Writeback Routing & Bypassing**: Selects writeback data source (ALU result, memory load, or PC+4)
--!   and forwards it to the GPR writeback ports (`o_wb_id_fb`) and the forwarding bypass lines (`o_wb_ex_fb.fwd`).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_stage IS
	PORT (
		i_instruction_valid : IN  STD_LOGIC;                     --! Instruction retired valid indicator flag
		i_mem_wb_bus        : IN  t_mem_wb_data;                 --! Input bus from Memory stage (control signals and data)
		i_dmem_data         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Raw 32-bit data read from Memory/BRAM
		o_pipeline_flush    : OUT STD_LOGIC;                     --! Pipeline flush request (clears instruction buffer on traps)
		o_wb_id_fb          : OUT t_rd_reg_data;                 --! Writeback feedback bus to GPR Register File in ID stage
		o_wb_ex_fb          : OUT t_wb_ex_fb                     --! Trap, MRET, CSR writeback and forwarding feedback to EX stage
	);
END ENTITY writeback_stage;

ARCHITECTURE behavioral OF writeback_stage IS

	SIGNAL s_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Formatted load data (after extraction and extension)
	SIGNAL s_fault_tag : t_fault_tag;                                      --! Internal updated fault status tag

BEGIN

	--! @brief Central Trap and Exception Controller
	--! @details Combinational process that maps all pipeline exceptions to machine-mode CSRs.
	--! Generates trap causes (`mcause`), trap values (`mtval`), trap PCs (`mepc`), and sets
	--! trap enable strobes.
	--!
	--! Supported exceptions:
	--! - **Smcfiss Return Address Mismatch**: Compares expected return PC with popped memory PC.
	--!   Triggers cause 18 (Shadow Stack Fault) on mismatch.
	--! - **Zicfilp LPAD Violation**: Triggers cause 18 (Landing Pad Fault).
	--! - **IF Access Fault**: Triggers cause 1.
	--! - **Unaligned branch/jump targets**: Triggers cause 0.
	--! - **Memory Address Misalignments**: Load (cause 4) / Store (cause 6).
	--! - **PMP violations**: Load (cause 5) / Store (cause 7).
	--! - **Software breakpoints / syscalls**: EBREAK (cause 3) / ECALL (cause 11).
	P_FAULT_CHECK : PROCESS (ALL)
	BEGIN
		s_fault_tag <= i_mem_wb_bus.fault_tag;
		o_wb_ex_fb.mcause <= (OTHERS => '0');
		o_wb_ex_fb.mtval <= (OTHERS => '0');
		o_wb_ex_fb.mepc <= (OTHERS => '0');
		o_wb_ex_fb.trap <= '0';
		o_wb_ex_fb.mret <= '0';

		IF i_mem_wb_bus.fault_tag = VALID AND i_mem_wb_bus.ss_instr = '1' THEN
			IF s_read_data /= i_mem_wb_bus.rd_bus.rd_data THEN
				o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(18, 32));
				o_wb_ex_fb.mtval  <= (OTHERS => '0');
				o_wb_ex_fb.mepc   <= i_mem_wb_bus.pc;
				o_wb_ex_fb.trap   <= '1';
				s_fault_tag       <= WB_SHADOW_STACK_FAULT;
			END IF;

		ELSIF i_mem_wb_bus.fault_tag = IF_ACCESS_FAULT THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(1, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.pc;
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = EX_LPAD_FAULT THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(18, 32));
			o_wb_ex_fb.mtval <= (OTHERS => '0');
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = EX_REDIR_MISALIGNED THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(0, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data;
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = MEM_L_MISALIGNED THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(4, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data;
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = MEM_S_MISALIGNED THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(6, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data; 
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = MEM_L_ACCESS_FAULT THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(5, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data; 
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = MEM_S_ACCESS_FAULT THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(7, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data; 
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = TRAP_EBREAK THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(3, 32));
			o_wb_ex_fb.mtval <= i_mem_wb_bus.pc; 
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = TRAP_ECALL THEN
			o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(11, 32));
			o_wb_ex_fb.mtval <= (OTHERS => '0');
			o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
			o_wb_ex_fb.trap <= '1';

		ELSIF i_mem_wb_bus.fault_tag = TRAP_MRET THEN
			o_wb_ex_fb.mret <= '1';

		END IF;

	END PROCESS P_FAULT_CHECK;

	--! @brief Load Data Alignment and Extension Process
	--! @details Extracts sub-word sizes (bytes, halfwords) from the raw 32-bit memory read data
	--! based on address offset alignment and applies sign extension (LB, LH) or zero extension (LBU, LHU).
	--! Shadow stack pop instructions bypass alignment checks and read the full 32-bit word.
	P_LOAD : PROCESS (ALL)
		VARIABLE byte_val : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Extracted byte value (before extension)
		VARIABLE half_val : STD_LOGIC_VECTOR(15 DOWNTO 0); -- Extracted halfword value (before extension)
	BEGIN
		s_read_data <= (OTHERS => '0');

		-- Byte extraction based on address alignment
		CASE i_mem_wb_bus.rd_bus.rd_data(1 DOWNTO 0) IS
			WHEN "00" => byte_val := i_dmem_data(7 DOWNTO 0);
			WHEN "01" => byte_val := i_dmem_data(15 DOWNTO 8);
			WHEN "10" => byte_val := i_dmem_data(23 DOWNTO 16);
			WHEN "11" => byte_val := i_dmem_data(31 DOWNTO 24);
			WHEN OTHERS => byte_val := (OTHERS => 'X');
		END CASE;

		-- Halfword extraction based on address alignment
		IF i_mem_wb_bus.rd_bus.rd_data(1) = '0' THEN
			half_val := i_dmem_data(15 DOWNTO 0);
		ELSE
			half_val := i_dmem_data(31 DOWNTO 16);
		END IF;

		IF i_mem_wb_bus.ss_instr = '1' THEN
			s_read_data <= i_dmem_data;
		ELSE
			CASE i_mem_wb_bus.funct3 IS
				WHEN "010" =>  -- LW
					s_read_data <= i_dmem_data;
				WHEN "001" =>  -- LH
					s_read_data <= STD_LOGIC_VECTOR(resize(signed(half_val), 32));
				WHEN "000" =>  -- LB
					s_read_data <= STD_LOGIC_VECTOR(resize(signed(byte_val), 32));
				WHEN "101" =>  -- LHU
					s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(half_val), 32));
				WHEN "100" =>  -- LBU
					s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(byte_val), 32));
				WHEN OTHERS =>
					NULL;
			END CASE;
		END IF;
	END PROCESS P_LOAD;
        
	--! @brief Writeback Destination MUX Process
	--! @details Selects the final writeback value (ALU result, read memory data, or JAL/JALR return address PC+4)
	--! and routes it to the register file feedback (`o_wb_id_fb.rd_data`) and execution forwarding feedback (`o_wb_ex_fb.fwd`).
	P_RD_WB_MUX : PROCESS (ALL)
	BEGIN
		CASE i_mem_wb_bus.wb_src IS
			WHEN WB_SRC_EX_RESULT =>
				o_wb_id_fb.rd_data <= i_mem_wb_bus.rd_bus.rd_data;
				o_wb_ex_fb.fwd <= i_mem_wb_bus.rd_bus.rd_data;
			WHEN WB_SRC_MEM =>
				o_wb_id_fb.rd_data <= s_read_data;
				o_wb_ex_fb.fwd <= s_read_data;
			WHEN WB_SRC_PC4 =>
				o_wb_id_fb.rd_data <= i_mem_wb_bus.pc4;
				o_wb_ex_fb.fwd <= i_mem_wb_bus.pc4;
			WHEN OTHERS =>
				o_wb_id_fb.rd_data <= (OTHERS => 'X');
				o_wb_ex_fb.fwd <= (OTHERS => 'X');
		END CASE;
	END PROCESS P_RD_WB_MUX;

	--! @brief Process to detect critical CSR updates in WB stage.
	--! @details Triggers critical flush feedback if PMP configuration registers are written.
	P_CSR_CRITICAL : PROCESS (ALL)
	BEGIN
		o_wb_ex_fb.crit_csr <= '0';
		IF i_mem_wb_bus.csr_bus.csr_write_en = '1' THEN
			CASE i_mem_wb_bus.csr_bus.csr_addr IS
				WHEN x"3A0" | x"3B0" | x"3B1" | x"3B2" | x"3B3" | x"351" | x"352" =>
					o_wb_ex_fb.crit_csr <= '1';
				WHEN OTHERS =>
					o_wb_ex_fb.crit_csr <= '0';
			END CASE;
		END IF;
	END PROCESS P_CSR_CRITICAL;
        
	o_wb_ex_fb.csr_bus.csr_data <= i_mem_wb_bus.csr_bus.csr_data;
	o_wb_ex_fb.csr_bus.csr_addr <= i_mem_wb_bus.csr_bus.csr_addr;
	o_wb_ex_fb.csr_bus.csr_write_en <= i_mem_wb_bus.csr_bus.csr_write_en WHEN s_fault_tag = VALID ELSE '0';

	o_wb_ex_fb.pc4 <= i_mem_wb_bus.pc4;

	o_wb_id_fb.rd_addr <= i_mem_wb_bus.rd_bus.rd_addr;
	o_wb_id_fb.reg_write_en <= i_mem_wb_bus.rd_bus.reg_write_en WHEN s_fault_tag = VALID ELSE '0';
	
	o_wb_ex_fb.minstret <= i_instruction_valid WHEN s_fault_tag = VALID ELSE '0';
	o_pipeline_flush <= '1' WHEN s_fault_tag /= VALID OR o_wb_ex_fb.crit_csr = '1' ELSE '0';

END ARCHITECTURE behavioral;
