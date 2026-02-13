--! @file memory_stage.vhd
--! Memory Access Stage
--! @author ethycS
--! @details This module implements the Memory (MEM) stage of the RV32I pipeline.
--! It handles data memory access for load and store instructions, including
--! byte/halfword/word size selection and address alignment.
--!
--! For store operations, this stage:
--! - Generates memory address from ALU result
--! - Produces byte enable signals based on access size and alignment
--! - Replicates and aligns store data for sub-word writes
--!
--! Store instruction handling:
--! - SW (Store Word): Writes full 32-bit word with all bytes enabled
--! - SH (Store Halfword): Writes 16-bit value to lower or upper halfword
--! - SB (Store Byte): Writes 8-bit value to one of four byte positions
--!
--! For load operations, the memory read is initiated and data bypass paths
--! are established. Load data reconstruction occurs in the Writeback stage.
--!
--! The stage also forwards control signals (register write enable, writeback source,
--! PC+4) to the WB stage via the MEM/WB pipeline register bus.

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

                o_mem_trap : OUT t_mem_trap;

		i_ex_mem_bus : IN  t_ex_mem_data; --! Input bus from Execute stage (ALU result, control signals)
		o_mem_wb_bus : OUT t_mem_wb_data  --! Output bus to Writeback stage 

	);
END ENTITY memory_stage;

ARCHITECTURE structural OF memory_stage IS
        SIGNAL s_misaligned_access : STD_LOGIC;
BEGIN

        o_mem_addr <= i_ex_mem_bus.rd_bus.rd_data;

        P_CHECK_ACCESS : PROCESS (i_ex_mem_bus.mem_write, i_ex_mem_bus.mem_read, i_ex_mem_bus.rd_bus.rd_data, i_ex_mem_bus.funct3)
        BEGIN
                s_misaligned_access <= '0';
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
                                        s_misaligned_access <='0';
                        END CASE;
                END IF;
        END PROCESS P_CHECK_ACCESS;

        o_mem_write_en <= i_ex_mem_bus.mem_write AND (NOT s_misaligned_access);

        P_TRAP_SEL : PROCESS (s_misaligned_access, i_ex_mem_bus.mem_write, i_ex_mem_bus.mem_read)
        BEGIN
                o_mem_trap <= VALID;
                IF s_misaligned_access = '1' THEN
                        IF i_ex_mem_bus.mem_read = '1' THEN
                                o_mem_trap <= L_MISALIGNED;
                        ELSIF i_ex_mem_bus.mem_write = '1' THEN
                                o_mem_trap <= S_MISALIGNED;
                        END IF;
                END IF;
        END PROCESS P_TRAP_SEL;
	

	--! @brief Store Data Alignment and Byte Enable Logic
	--! @details Combinational process that generates byte enable signals and aligns
	--! store data based on the access size (funct3) and memory address alignment.
	--! 
	--! For word stores (SW, funct3="010"):
	--! - All 4 bytes are enabled
	--! - Data passes through unchanged
	--!
	--! For halfword stores (SH, funct3="001"):
	--! - Lower halfword is replicated to both positions
	--! - Address bit [1] selects which halfword is enabled
	--! - addr[1]=0: Enable bytes [1:0] (lower halfword)
	--! - addr[1]=1: Enable bytes [3:2] (upper halfword)
	--!
	--! For byte stores (SB, funct3="000"):
	--! - Lowest byte is replicated to all 4 positions
	--! - Address bits [1:0] select which byte position is enabled
	--! - "00": Enable byte 0, "01": Enable byte 1, "10": Enable byte 2, "11": Enable byte 3
	--!
	--! This replication and masking approach simplifies memory controller design by
	--! presenting correctly aligned data on all byte lanes.
	P_STORE : PROCESS (i_ex_mem_bus.mem_write, i_ex_mem_bus.funct3, i_ex_mem_bus.rd_bus.rd_data, i_ex_mem_bus.rs2_data, s_misaligned_access)
	BEGIN
		o_mem_byte_en <= "0000";
		o_mem_write_data <= i_ex_mem_bus.rs2_data;

		IF i_ex_mem_bus.mem_write = '1' AND s_misaligned_access = '0' THEN
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

	-- Forward control signals to WB stage
	o_mem_wb_bus.pc4 <= i_ex_mem_bus.pc4;
	o_mem_wb_bus.rd_bus <= i_ex_mem_bus.rd_bus;
	o_mem_wb_bus.wb_src <= i_ex_mem_bus.wb_src;
	o_mem_wb_bus.funct3 <= i_ex_mem_bus.funct3;

END ARCHITECTURE structural;

