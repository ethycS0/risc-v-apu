--! @file forwarding_unit.vhd
--! Data Forwarding Unit
--! @author ethycS
--! @details This module implements data hazard detection and forwarding logic for
--! the Execute stage. It compares source register addresses (rs1, rs2) in the EX
--! stage with destination register addresses (rd) in the MEM and WB stages to
--! detect RAW (Read-After-Write) hazards.
--!
--! When a hazard is detected, the unit generates forwarding control signals to
--! bypass the result from later pipeline stages instead of reading stale data
--! from the register file. This eliminates the need for pipeline stalls on
--! back-to-back data dependencies.
--!
--! Forwarding priority (highest to lowest):
--! 1. MEM stage (EX-MEM pipeline register): Most recent result
--! 2. WB stage (MEM-WB pipeline register): Older result
--! 3. No forwarding: Use register file value
--!
--! Register x0 is excluded from forwarding as it is hardwired to zero and cannot
--! be a valid forwarding source.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY forwarding_unit IS
	PORT (
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Source register 1 address (EX stage)
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Source register 2 address (EX stage)

		i_rd_addr_mem   : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Destination register address (MEM stage)
		i_reg_write_mem : IN STD_LOGIC;                    --! Register write enable (MEM stage)

		i_rd_addr_wb   : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Destination register address (WB stage)
		i_reg_write_wb : IN STD_LOGIC;                    --! Register write enable (WB stage)

		o_fwd_a_select : OUT t_Forward; --! Forwarding result for operand A 
		o_fwd_b_select : OUT t_Forward  --! Forwarding result for operand B 
	);
END ENTITY forwarding_unit;

ARCHITECTURE behavioral OF forwarding_unit IS
BEGIN

	--! @brief Forwarding Logic Process
	--! @details Combinational process that detects data hazards and generates forwarding
	--! control signals for both operands (A and B). For each operand, it checks:
	--! 1. MEM stage hazard: rd_mem == rs (EX) AND reg_write_mem == 1 AND rd_mem != x0
	--! 2. WB stage hazard: rd_wb == rs (EX) AND reg_write_wb == 1 AND rd_wb != x0
	--!
	--! MEM stage forwarding has higher priority than WB stage forwarding, as it provides
	--! the most recent result. This handles the case where both stages produce results
	--! for the same register (though rare, the MEM result should be used).
	--!
	--! The x0 exclusion check ensures that reads from the hardwired zero register are
	--! never forwarded, maintaining architectural correctness.
	forwarding_logic_proc : PROCESS (i_rs1_addr_id, i_rs2_addr_id, i_rd_addr_mem, i_rd_addr_wb, i_reg_write_mem, i_reg_write_wb)

	BEGIN
		-- Default: no forwarding (use register file value)
		o_fwd_a_select <= FWD_NONE;
		o_fwd_b_select <= FWD_NONE;

		-- Operand A (rs1) forwarding logic
		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_EX_MEM;  -- Forward from MEM stage (highest priority)
		ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_MEM_WB;  -- Forward from WB stage
		END IF;

		-- Operand B (rs2) forwarding logic
		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_EX_MEM;  -- Forward from MEM stage (highest priority)
		ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_MEM_WB;  -- Forward from WB stage
		END IF;

	END PROCESS forwarding_logic_proc;

END ARCHITECTURE behavioral;

