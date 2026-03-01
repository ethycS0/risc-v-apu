LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_stage IS
	PORT (
                i_instruction_valid : IN STD_LOGIC;
		i_mem_wb_bus : IN  t_mem_wb_data;                  --! Input bus from Memory stage (control signals, ALU result)
		i_dmem_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory read data (raw 32-bit value)
                o_pipeline_flush : OUT STD_LOGIC;
		o_wb_id_fb : OUT t_rd_reg_data;                  --! Output bus to ID stage (register file write data)
		o_wb_ex_fb  : OUT t_wb_ex_fb

	);
END ENTITY writeback_stage;

ARCHITECTURE behavioral OF writeback_stage IS

	SIGNAL s_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Load data (after extraction and extension)
        SIGNAL s_fault_tag : t_fault_tag;

BEGIN
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

                -- ELSIF i_mem_wb_bus.fault_tag = ID_INVALID_INSTR THEN

                ELSIF i_mem_wb_bus.fault_tag = EX_REDIR_MISALIGNED THEN
                        o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(0, 32));
                        o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data; -- Make sure to pass EX stage errors mtval in rd_data
                        o_wb_ex_fb.mepc <= i_mem_wb_bus.pc;
                        o_wb_ex_fb.trap <= '1';

                ELSIF i_mem_wb_bus.fault_tag = MEM_L_MISALIGNED THEN
                        o_wb_ex_fb.mcause <= STD_LOGIC_VECTOR(to_unsigned(4, 32));
                        o_wb_ex_fb.mtval <= i_mem_wb_bus.rd_bus.rd_data; -- Make sure to pass EX stage errors mtval in rd_data
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


	P_LOAD : PROCESS (ALL)
		VARIABLE byte_val : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Extracted byte value (before extension)
		VARIABLE half_val : STD_LOGIC_VECTOR(15 DOWNTO 0); -- Extracted halfword value (before extension)

	BEGIN
		s_read_data <= (OTHERS => '0');

		-- Byte extraction based on address alignment
		CASE i_mem_wb_bus.rd_bus.rd_data(1 DOWNTO 0) IS
			WHEN "00" => byte_val := i_dmem_data(7 DOWNTO 0);    -- Byte 0
			WHEN "01" => byte_val := i_dmem_data(15 DOWNTO 8);   -- Byte 1
			WHEN "10" => byte_val := i_dmem_data(23 DOWNTO 16);  -- Byte 2
			WHEN "11" => byte_val := i_dmem_data(31 DOWNTO 24);  -- Byte 3
			WHEN OTHERS => byte_val := (OTHERS => 'X');
		END CASE;

		-- Halfword extraction based on address alignment
		IF i_mem_wb_bus.rd_bus.rd_data(1) = '0' THEN
			half_val := i_dmem_data(15 DOWNTO 0);   -- Lower halfword
		ELSE
			half_val := i_dmem_data(31 DOWNTO 16);  -- Upper halfword
		END IF;

		-- Extension and load type selection
		CASE i_mem_wb_bus.funct3 IS
			WHEN "010" =>  -- LW: Load Word (32-bit, no extension needed)
				s_read_data <= i_dmem_data;

			WHEN "001" =>  -- LH: Load Halfword (sign-extended)
				s_read_data <= STD_LOGIC_VECTOR(resize(signed(half_val), 32));

			WHEN "000" =>  -- LB: Load Byte (sign-extended)
				s_read_data <= STD_LOGIC_VECTOR(resize(signed(byte_val), 32));

			WHEN "101" =>  -- LHU: Load Halfword Unsigned (zero-extended)
				s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(half_val), 32));

			WHEN "100" =>  -- LBU: Load Byte Unsigned (zero-extended)
				s_read_data <= STD_LOGIC_VECTOR(resize(unsigned(byte_val), 32));

			WHEN OTHERS =>
				NULL;

		END CASE;
	END PROCESS P_LOAD;
        
	P_RD_WB_MUX : PROCESS (ALL)
	BEGIN
		CASE i_mem_wb_bus.wb_src IS
			WHEN WB_SRC_EX_RESULT =>  -- ALU result
				o_wb_id_fb.rd_data <= i_mem_wb_bus.rd_bus.rd_data;
				o_wb_ex_fb.fwd <= i_mem_wb_bus.rd_bus.rd_data;

			WHEN WB_SRC_MEM =>  -- Memory load data
				o_wb_id_fb.rd_data <= s_read_data;
				o_wb_ex_fb.fwd <= s_read_data;

			WHEN WB_SRC_PC4 =>  -- Return address (JAL/JALR)
				o_wb_id_fb.rd_data <= i_mem_wb_bus.pc4;
				o_wb_ex_fb.fwd <= i_mem_wb_bus.pc4;

			WHEN OTHERS =>  -- Invalid writeback source
				o_wb_id_fb.rd_data <= (OTHERS => 'X');
				o_wb_ex_fb.fwd <= (OTHERS => 'X');

		END CASE;
	END PROCESS P_RD_WB_MUX;

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
        END PROCESS;


        
        o_wb_ex_fb.csr_bus.csr_data <= i_mem_wb_bus.csr_bus.csr_data;
        o_wb_ex_fb.csr_bus.csr_addr <= i_mem_wb_bus.csr_bus.csr_addr;
        o_wb_ex_fb.csr_bus.csr_write_en <= i_mem_wb_bus.csr_bus.csr_write_en WHEN s_fault_tag = VALID ELSE '0';

        o_wb_ex_fb.pc4 <= i_mem_wb_bus.pc4;

	-- Control signals to ID stage for register file write
	o_wb_id_fb.rd_addr <= i_mem_wb_bus.rd_bus.rd_addr;
        o_wb_id_fb.reg_write_en <= i_mem_wb_bus.rd_bus.reg_write_en WHEN s_fault_tag = VALID ELSE '0';
	
	-- Instruction retirement signal for minstret CSR counter
        o_wb_ex_fb.minstret <= i_instruction_valid WHEN s_fault_tag = VALID ELSE '0';
        o_pipeline_flush <= '1' WHEN s_fault_tag /= VALID OR o_wb_ex_fb.crit_csr = '1' ELSE '0';

END ARCHITECTURE behavioral;

