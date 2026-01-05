--! @file writeback_stage.vhd
--! Writeback Stage
--! @author ethycS
--! @details This module implements the Writeback (WB) stage of the RV32I pipeline,
--! the final stage responsible for writing results back to the register file.
--! It handles bypassed load data reconstruction for sub-word accesses and multiplexes between
--! different writeback data sources.
--!
--! Key functions:
--! - Load data extraction: Selects correct byte/halfword from memory data based on
--!   address alignment (bits [1:0])
--! - Sign/zero extension: Extends sub-word loads to 32 bits based on load type
--! - Writeback multiplexing: Selects between ALU result, memory data, or PC+4
--! - Instruction retirement tracking: Signals completion for minstret CSR counter
--!
--! Load instruction handling (decoded via funct3):
--! - LW (010): Load Word - full 32-bit value
--! - LH (001): Load Halfword - sign-extended 16-bit value
--! - LB (000): Load Byte - sign-extended 8-bit value
--! - LHU (101): Load Halfword Unsigned - zero-extended 16-bit value
--! - LBU (100): Load Byte Unsigned - zero-extended 8-bit value
--!
--! The stage provides outputs to the ID stage for register file writes
--! and to the EX stage for data forwarding.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY writeback_stage IS
	PORT (
		i_instruction_valid    : IN  STD_LOGIC;  --! Valid instruction in WB stage (used for minstret counter)
		o_instructions_retired : OUT STD_LOGIC;  --! Instruction retirement signal (for CSR minstret increment)

		i_mem_wb_bus : IN  t_mem_wb_data;                  --! Input bus from Memory stage (control signals, ALU result)
		i_dmem_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory read data (raw 32-bit value)
		o_wb_id_data : OUT t_rd_reg_data;                  --! Output bus to ID stage (register file write data)
		o_wb_ex_fwd  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)   --! Forwarding path to EX stage 

	);
END ENTITY writeback_stage;

ARCHITECTURE behavioral OF writeback_stage IS

	SIGNAL s_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Load data (after extraction and extension)

BEGIN

	--! @brief Load Data and Reconstruction Process
	--! @details Combinational process that extracts and extends load data based on the
	--! access size (funct3) and memory address alignment (rd_data[1:0]).
	--!
	--! Byte extraction (for LB/LBU):
	--! - Address[1:0]="00": Extract bits [7:0]   (byte 0)
	--! - Address[1:0]="01": Extract bits [15:8]  (byte 1)
	--! - Address[1:0]="10": Extract bits [23:16] (byte 2)
	--! - Address[1:0]="11": Extract bits [31:24] (byte 3)
	--!
	--! Halfword extraction (for LH/LHU):
	--! - Address[1]='0': Extract bits [15:0]  (lower halfword)
	--! - Address[1]='1': Extract bits [31:16] (upper halfword)
	--!
	--! Extension:
	--! - Signed loads (LB, LH): Sign-extend to 32 bits
	--! - Unsigned loads (LBU, LHU): Zero-extend to 32 bits
	--! - Word loads (LW): Pass through unchanged
	P_LOAD : PROCESS (i_mem_wb_bus.funct3, i_dmem_data, i_mem_wb_bus.rd_bus.rd_data)
		VARIABLE byte_val : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Extracted byte value (before extension)
		VARIABLE half_val : STD_LOGIC_VECTOR(15 DOWNTO 0); -- Extracted halfword value (before extension)

	BEGIN
		s_read_data <= (OTHERS => 'X');

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

	--! @brief Writeback Data Source Multiplexer Process
	--! @details Combinational process that selects the final writeback value based on
	--! the writeback source control signal. The selected data is output to both the
	--! ID stage (for register file writes) and the EX stage (for forwarding).
	--!
	--! Writeback sources:
	--! - WB_SRC_EX_RESULT: ALU result or address calculation (arithmetic, logical, etc.)
	--! - WB_SRC_MEM: Reconstructed memory load data (from P_LOAD process)
	--! - WB_SRC_PC4: Return address for JAL/JALR instructions
	P_WB_MUX : PROCESS (i_mem_wb_bus.wb_src, i_mem_wb_bus.rd_bus.rd_data, i_mem_wb_bus.pc4, i_dmem_data, s_read_data)
	BEGIN
		CASE i_mem_wb_bus.wb_src IS
			WHEN WB_SRC_EX_RESULT =>  -- ALU result
				o_wb_id_data.rd_data <= i_mem_wb_bus.rd_bus.rd_data;
				o_wb_ex_fwd <= i_mem_wb_bus.rd_bus.rd_data;

			WHEN WB_SRC_MEM =>  -- Memory load data
				o_wb_id_data.rd_data <= s_read_data;
				o_wb_ex_fwd <= s_read_data;

			WHEN WB_SRC_PC4 =>  -- Return address (JAL/JALR)
				o_wb_id_data.rd_data <= i_mem_wb_bus.pc4;
				o_wb_ex_fwd <= i_mem_wb_bus.pc4;

			WHEN OTHERS =>  -- Invalid writeback source
				o_wb_id_data.rd_data <= (OTHERS => 'X');
				o_wb_ex_fwd <= (OTHERS => 'X');

		END CASE;
	END PROCESS P_WB_MUX;

	-- Control signals to ID stage for register file write
	o_wb_id_data.rd_addr <= i_mem_wb_bus.rd_bus.rd_addr;
	o_wb_id_data.reg_write_en <= i_mem_wb_bus.rd_bus.reg_write_en;
	
	-- Instruction retirement signal for minstret CSR counter
	o_instructions_retired <= i_instruction_valid;

END ARCHITECTURE behavioral;

