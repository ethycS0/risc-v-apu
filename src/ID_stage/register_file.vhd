--! @file register_file.vhd
--! @brief 32-entry Integer Register File (x0-x31) for the RISC-V processor.
--! @author ethycS
--! @details This module implements the general-purpose integer registers.
--! It features dual asynchronous read ports and a single synchronous write port.
--!
--! Key features:
--! - Register x0 is hardwired to zero (writes to x0 are ignored).
--! - Synchronous write on rising clock edge.
--! - Asynchronous combinational reads.
--! - Asynchronous reset (Active High) clearing all registers.
--! - Internal forwarding logic to handle write-during-read hazards.
--!
--! The internal forwarding logic allows reading the new value being written in the same
--! cycle, preventing pipeline stalls for back-to-back register dependencies.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY register_file IS
	PORT (
		i_clk      : IN  STD_LOGIC;                     --! Global clock (rising-edge active)
		i_rst      : IN  STD_LOGIC;                     --! Asynchronous reset (Active High)
		i_wr_en    : IN  STD_LOGIC;                     --! Write enable signal
		i_wr_addr  : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Write address (destination register rd)
		i_wr_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Write data (value to be written to rd)
		i_rd1_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Read port 1 address (source register rs1)
		o_rd1_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Read port 1 data output
		i_rd2_addr : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Read port 2 address (source register rs2)
		o_rd2_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)  --! Read port 2 data output
	);
END ENTITY register_file;

ARCHITECTURE behavioral OF register_file IS

	TYPE t_reg_array IS ARRAY(0 TO 31) OF STD_LOGIC_VECTOR(31 DOWNTO 0); --! Array type for 32 registers
	SIGNAL s_registers : t_reg_array := (OTHERS => (OTHERS => '0')); --! Register file storage array

BEGIN

	--! @brief Synchronous Write Process
	--! @details Handles register writes on the rising clock edge. Writes are only
	--! performed when write enable is asserted and the target address is not x0.
	--! Register x0 is hardwired to zero in RISC-V and cannot be modified.
	--! On reset, all registers are cleared to zero.
	write_process : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			s_registers <= (OTHERS => (OTHERS => '0'));
		ELSIF rising_edge(i_clk) THEN
			IF i_wr_en = '1' AND to_integer(unsigned(i_wr_addr)) /= 0 THEN  -- Protect x0 from writes
				s_registers(to_integer(unsigned(i_wr_addr))) <= i_wr_data;
			END IF;
		END IF;
	END PROCESS write_process;

	--! @brief Asynchronous Read Process with Internal Forwarding
	--! @details Provides combinational reads for both read ports. Implements internal
	--! forwarding (bypass) logic to forward write data directly to the read output
	--! when a read and write target the same register in the same cycle. This prevents
	--! stale data from being read and eliminates the need for pipeline stalls on
	--! read-after-write hazards. Forwarding is bypassed for register x0, which always
	--! reads as zero regardless of write operations.
        read_proc : PROCESS (ALL)
	BEGIN
		IF (i_wr_en = '1') AND (i_wr_addr = i_rd1_addr) AND (to_integer(unsigned(i_wr_addr)) /= 0) THEN
			o_rd1_data <= i_wr_data; 
		ELSE
			o_rd1_data <= s_registers(to_integer(unsigned(i_rd1_addr)));  
		END IF;

		IF (i_wr_en = '1') AND (i_wr_addr = i_rd2_addr) AND (to_integer(unsigned(i_wr_addr)) /= 0) THEN
			o_rd2_data <= i_wr_data;  
		ELSE
			o_rd2_data <= s_registers(to_integer(unsigned(i_rd2_addr)));  
		END IF;
	END PROCESS read_proc;

END ARCHITECTURE behavioral;

