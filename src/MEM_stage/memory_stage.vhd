LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY memory_stage IS
	PORT (
		o_mem_addr       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory address output (to data memory)
		o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory write data output (aligned/replicated)
		o_mem_write_en   : OUT STD_LOGIC;                     --! Memory write enable signal
		o_mem_byte_en    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);  --! Byte enable mask (selects active bytes)

                o_mem_valid : OUT STD_LOGIC;

                i_pmp_fault  : IN STD_LOGIC;
		i_ex_mem_bus : IN  t_ex_mem_data; --! Input bus from Execute stage (ALU result, control signals)
		o_mem_wb_bus : OUT t_mem_wb_data  --! Output bus to Writeback stage 

	);
END ENTITY memory_stage;

ARCHITECTURE structural OF memory_stage IS
        SIGNAL s_fault_tag : t_fault_tag;
        SIGNAL s_misaligned_access : STD_LOGIC;
BEGIN

        o_mem_addr <= i_ex_mem_bus.rd_bus.rd_data;
        o_mem_valid <= (i_ex_mem_bus.mem_read OR i_ex_mem_bus.mem_write) WHEN (i_ex_mem_bus.fault_tag = VALID AND s_misaligned_access = '0') ELSE '0';

        P_FAULT_TAG : PROCESS (ALL)
        BEGIN
                s_fault_tag <= i_ex_mem_bus.fault_tag;
                s_misaligned_access <= '0';

                IF i_ex_mem_bus.fault_tag = VALID THEN
                        IF i_ex_mem_bus.mem_read = '1' OR i_ex_mem_bus.mem_write = '1' THEN 
                                CASE i_ex_mem_bus.funct3(1 DOWNTO 0) IS
                                        WHEN "10" =>  -- Word (32-bit)
                                                IF i_ex_mem_bus.rd_bus.rd_data(1 DOWNTO 0) /= "00" THEN
                                                        s_misaligned_access <= '1';
                                                END IF;

                                        WHEN "01" =>  -- Halfword (16-bit)
                                                IF i_ex_mem_bus.rd_bus.rd_data(0) /= '0' THEN
                                                        s_misaligned_access <= '1';
                                                END IF;

                                        WHEN OTHERS =>  -- Invalid or load operation
                                                s_misaligned_access <= '0';
                                END CASE;

                        END IF;

                        IF s_misaligned_access = '1' THEN 
                                IF i_ex_mem_bus.mem_read = '1' THEN
                                        s_fault_tag <= MEM_L_MISALIGNED;
                                ELSIF i_ex_mem_bus.mem_write = '1' THEN
                                        s_fault_tag <= MEM_S_MISALIGNED;
                                END IF;
                        ELSIF i_pmp_fault = '1' THEN
                                IF i_ex_mem_bus.mem_read = '1' THEN
                                        s_fault_tag <= MEM_L_ACCESS_FAULT;
                                ELSIF i_ex_mem_bus.mem_write = '1' THEN
                                        s_fault_tag <= MEM_S_ACCESS_FAULT;
                                END IF;
                        END IF;
                END IF;

        END PROCESS P_FAULT_TAG;


	P_STORE : PROCESS (i_ex_mem_bus.mem_write, i_ex_mem_bus.funct3, i_ex_mem_bus.rd_bus.rd_data, i_ex_mem_bus.rs2_data, s_fault_tag)
	BEGIN
		o_mem_byte_en <= "0000";
		o_mem_write_data <= i_ex_mem_bus.rs2_data;

		IF i_ex_mem_bus.mem_write = '1' AND s_fault_tag = VALID THEN
			CASE i_ex_mem_bus.funct3 IS
				WHEN "010" =>  -- SW: Store Word (32-bit)
					o_mem_byte_en <= "1111";
					o_mem_write_data <= i_ex_mem_bus.rs2_data;

				WHEN "001" =>  -- SH: Store Halfword (16-bit)
					o_mem_write_data <= i_ex_mem_bus.rs2_data(15 DOWNTO 0) & i_ex_mem_bus.rs2_data(15 DOWNTO 0);

					IF i_ex_mem_bus.rd_bus.rd_data(1) = '0' THEN
						o_mem_byte_en <= "0011";  -- Lower halfword (bytes 1:0)
					ELSE
						o_mem_byte_en <= "1100";  -- Upper halfword (bytes 3:2)
					END IF;

				WHEN "000" =>  -- SB: Store Byte (8-bit)
					o_mem_write_data <= i_ex_mem_bus.rs2_data(7 DOWNTO 0) & i_ex_mem_bus.rs2_data(7 DOWNTO 0) &
					                    i_ex_mem_bus.rs2_data(7 DOWNTO 0) & i_ex_mem_bus.rs2_data(7 DOWNTO 0);

					CASE i_ex_mem_bus.rd_bus.rd_data(1 DOWNTO 0) IS
						WHEN "00" => o_mem_byte_en <= "0001";  -- Byte 0
						WHEN "01" => o_mem_byte_en <= "0010";  -- Byte 1
						WHEN "10" => o_mem_byte_en <= "0100";  -- Byte 2
						WHEN "11" => o_mem_byte_en <= "1000";  -- Byte 3
						WHEN OTHERS => o_mem_byte_en <= "0000";
					END CASE;

				WHEN OTHERS =>  -- Invalid or load operation
					o_mem_byte_en <= "0000";
			END CASE;
		END IF;
	END PROCESS P_STORE;

        o_mem_write_en <= i_ex_mem_bus.mem_write WHEN (i_ex_mem_bus.fault_tag = VALID AND s_misaligned_access = '0') ELSE '0';

	-- Forward control signals to WB stage
	o_mem_wb_bus.pc4 <= i_ex_mem_bus.pc4;
	o_mem_wb_bus.wb_src <= i_ex_mem_bus.wb_src;
	o_mem_wb_bus.funct3 <= i_ex_mem_bus.funct3;

	o_mem_wb_bus.rd_bus.rd_addr <= i_ex_mem_bus.rd_bus.rd_addr;
	o_mem_wb_bus.rd_bus.rd_data <= i_ex_mem_bus.rd_bus.rd_data;
        o_mem_wb_bus.rd_bus.reg_write_en <= i_ex_mem_bus.rd_bus.reg_write_en WHEN s_fault_tag = VALID ELSE '0';

        o_mem_wb_bus.csr_bus.csr_addr <= i_ex_mem_bus.csr_bus.csr_addr;
        o_mem_wb_bus.csr_bus.csr_data <= i_ex_mem_bus.csr_bus.csr_data;
        o_mem_wb_bus.csr_bus.csr_write_en <= i_ex_mem_bus.csr_bus.csr_write_en WHEN s_fault_tag = VALID ELSE '0';

        o_mem_wb_bus.fault_tag <= s_fault_tag;
        o_mem_wb_bus.pc <= i_ex_mem_bus.pc;

END ARCHITECTURE structural;

