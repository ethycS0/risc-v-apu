--! @file hazard_detection_unit.vhd
--! Hazard Detection Unit
--! @author ethycS
--! @details This module detects load-use data hazards in the pipeline and generates
--! a stall signal to resolve them. A load-use hazard occurs when an instruction in
--! the ID stage needs data from a load instruction currently in the EX stage.
--!
--! Unlike other data hazards that can be resolved through forwarding, load-use hazards
--! require a pipeline stall because the load data is not available until after the
--! MEM stage completes. Forwarding alone cannot eliminate this one-cycle delay.
--!
--! Stall condition:
--! A pipeline stall is triggered when ALL of the following are true:
--! 1. A load instruction is in the EX stage (i_mem_read_ex = '1')
--! 2. The load destination register is not x0 (rd_ex != 0)
--! 3. The load destination matches either source register in ID stage
--!    (rd_ex == rs1_id OR rd_ex == rs2_id)
--!
--! When o_pipeline_stall is asserted:
--! - IF stage: PC freeze (no new instruction fetch)
--! - ID stage: Bubble insertion (convert current instruction to NOP)
--! - EX stage: Load proceeds normally
--!
--! This introduces a one-cycle stall, after which the load result can be forwarded
--! from the MEM stage to the EX stage, allowing the dependent instruction to proceed.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY hazard_detection_unit IS
	PORT (
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Source register 1 address (ID stage)
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Source register 2 address (ID stage)

		i_rd_addr_ex  : IN STD_LOGIC_VECTOR(4 DOWNTO 0); --! Destination register address (EX stage)
		i_mem_read_ex : IN STD_LOGIC;                    --! Memory read flag (1 = load instruction in EX)

		o_pipeline_stall : OUT STD_LOGIC --! Pipeline stall signal (1 = stall IF and ID stages)
	);
END ENTITY hazard_detection_unit;

ARCHITECTURE behavioral OF hazard_detection_unit IS

	SIGNAL s_stall_condition : STD_LOGIC; --! Internal stall condition flag

BEGIN

	-- Detect load-use hazard: load in EX stage writing to register needed by instruction in ID stage
	s_stall_condition <= '1' WHEN (i_mem_read_ex = '1') AND
		(to_integer(unsigned(i_rd_addr_ex)) /= 0) AND
		((i_rd_addr_ex = i_rs1_addr_id) OR
		(i_rd_addr_ex = i_rs2_addr_id))
		ELSE '0';

	-- Output stall signal to pipeline control
	o_pipeline_stall <= s_stall_condition;

END ARCHITECTURE behavioral;

