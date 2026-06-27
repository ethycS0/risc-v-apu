--! @file forwarding_unit.vhd
--! @brief Forwarding Unit to resolve data hazards in the pipeline.
--! @author ethycS
--! @details This module detects data hazards for general-purpose registers (rs1, rs2)
--! and Control and Status Registers (CSRs). It generates bypass selection control signals
--! to route execution results directly from the EX/MEM or MEM/WB pipeline registers
--! back to the Execution stage, avoiding pipeline stalls.
--!
--! Forwarding paths:
--! - **Operand A / B (GPR)**: Bypasses register file values if a preceding instruction
--!   writes to the same register and is currently in the MEM or WB stages.
--! - **CSR Data**: Bypasses CSR read values if a preceding CSR write instruction targets
--!   the same CSR address and is in flight in the EX/MEM or MEM/WB registers.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY forwarding_unit IS
	PORT (
		i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 1 address from ID stage
		i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Source Register 2 address from ID stage
		i_csr_addr_id : IN STD_LOGIC_VECTOR(11 DOWNTO 0); --! CSR register address from ID stage

		i_rd_addr_mem   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register address in MEM stage
		i_reg_write_mem : IN STD_LOGIC;                     --! Register write enable flag in MEM stage

		i_csr_addr_mem  : IN STD_LOGIC_VECTOR(11 DOWNTO 0); --! CSR write address in MEM stage
		i_csr_write_mem : IN STD_LOGIC;                     --! CSR write enable flag in MEM stage

		i_rd_addr_wb   : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  --! Destination Register address in WB stage
		i_reg_write_wb : IN STD_LOGIC;                     --! Register write enable flag in WB stage

		i_csr_addr_wb  : IN STD_LOGIC_VECTOR(11 DOWNTO 0); --! CSR write address in WB stage
		i_csr_write_wb : IN STD_LOGIC;                     --! CSR write enable flag in WB stage

		o_csr_fwd_select : OUT t_Forward;                   --! Forward selection for CSR read data
		o_fwd_a_select   : OUT t_Forward;                   --! Forward selection for ALU Operand A
		o_fwd_b_select   : OUT t_Forward                    --! Forward selection for ALU Operand B
	);
END ENTITY forwarding_unit;

ARCHITECTURE behavioral OF forwarding_unit IS
BEGIN

	--! @brief Data Forwarding Selection Process
	--! @details Evaluates active destination register addresses and write enables in subsequent
	--! stages, comparing them with the source registers needed by the current instruction.
	--! Priority is given to the EX/MEM stage (most recent result) over the MEM/WB stage.
	--! Writes to register x0 are never forwarded as it is hardwired to zero.
	forwarding_logic_proc : PROCESS (ALL)
	BEGIN
		o_fwd_a_select   <= FWD_NONE;
		o_fwd_b_select   <= FWD_NONE;
		o_csr_fwd_select <= FWD_NONE;

		-- Forwarding for Operand A (rs1)
		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_EX_MEM;
		ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs1_addr_id) THEN
			o_fwd_a_select <= FWD_FROM_MEM_WB;
		END IF;

		-- Forwarding for Operand B (rs2)
		IF (i_reg_write_mem = '1') AND (to_integer(unsigned(i_rd_addr_mem)) /= 0) AND (i_rd_addr_mem = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_EX_MEM;
		ELSIF (i_reg_write_wb = '1') AND (to_integer(unsigned(i_rd_addr_wb)) /= 0) AND (i_rd_addr_wb = i_rs2_addr_id) THEN
			o_fwd_b_select <= FWD_FROM_MEM_WB;
		END IF;

		-- Forwarding for CSR Reads
		IF (i_csr_write_mem = '1') AND (i_csr_addr_mem = i_csr_addr_id) THEN
			o_csr_fwd_select <= FWD_FROM_EX_MEM;
		ELSIF (i_csr_write_wb = '1') AND (i_csr_addr_wb = i_csr_addr_id) THEN
			o_csr_fwd_select <= FWD_FROM_MEM_WB;
		END IF;

	END PROCESS forwarding_logic_proc;

END ARCHITECTURE behavioral;

