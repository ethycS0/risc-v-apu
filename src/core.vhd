--! @file core.vhd
--! @brief RISC-V 32-bit (RV32I) processor core with security extensions.
--! @author ethycS
--! @details This is the top-level structural file for the eSC-V processor core.
--! It instantiates and interconnects the five pipeline stages (Instruction Fetch, Instruction Decode,
--! Execution, Memory, and Writeback), the Hazard Detection Unit, and the Physical Memory Protection (PMP) unit.
--!
--! Key features and security architectures:
--! - **5-Stage Pipeline**: Registers data flow between IF, ID, EX, MEM, and WB stages using synchronized pipeline registers.
--! - **PMP Integration**: The PMP checker is positioned at the boundary of the core. It monitors all instruction
--!   addresses (`s_fetch_addr`) and data memory addresses (`s_mem_addr`) combinationally. Any access violation is mapped
--!   to fault signals (`s_pmp_fetch_fault` / `s_pmp_mem_fault`) and the outgoing memory interfaces are scrambled/masked.
--! - **Pipeline Hazard Control**:
--!   - **Stalls**: A load-use data hazard detected in ID/EX blocks the front end (IF/ID stage) using `pipeline_stall`.
--!   - **Front-End Flushes**: EX-stage redirects (branches, jumps, landing pad faults) trigger `front_pipeline_flush` clearing `r_if_id_reg` and `r_id_ex_reg`.
--!   - **Back-End Flushes**: WB-stage exceptions (traps, shadow stack mismatches, or retiring critical CSR configurations) trigger
--!     `back_pipeline_flush` clearing in-flight instructions in `r_ex_mem_reg` and `r_mem_wb_reg` to reset core execution.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY core IS
	PORT (
		i_clk           : IN  STD_LOGIC;                     --! System clock (rising-edge active)
		i_rst           : IN  STD_LOGIC;                     --! Global asynchronous reset (active-high)

		o_instr_addr    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Output instruction address to memory controller
		i_instr_data    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input raw instruction word read from memory

		o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Output data memory address to memory controller
		i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input data read from memory controller
		o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Output data to be written to memory
		o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);  --! Output byte lane enable mask for writes
		o_data_write_en : OUT STD_LOGIC                      --! Output data memory write strobe
	);
END ENTITY core;

ARCHITECTURE structural OF core IS

	--! Instruction Fetch stage component declaration
	COMPONENT instruction_fetch_stage IS
		PORT (
			i_clk        : IN  STD_LOGIC;
			i_rst        : IN  STD_LOGIC;
			i_stall      : IN  STD_LOGIC;
			o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_pmp_fault  : IN  STD_LOGIC;
			i_ex_if_bus  : IN  t_ex_if_data;
			o_if_id_bus  : OUT t_if_id_data
		);
	END COMPONENT instruction_fetch_stage;

	--! Instruction Decode stage component declaration
	COMPONENT instruction_decode_stage IS
		PORT (
			i_clk       : IN  STD_LOGIC;
			i_rst       : IN  STD_LOGIC;
			i_wb_id_bus : IN  t_rd_reg_data;
			i_if_id_bus : IN  t_if_id_data;
			o_id_ex_bus : OUT t_id_ex_data
		);
	END COMPONENT instruction_decode_stage;

	--! Execution stage component declaration
	COMPONENT execution_stage IS
		PORT (
			i_clk            : IN  STD_LOGIC;
			i_rst            : IN  STD_LOGIC;
			i_id_ex_bus      : IN  t_id_ex_data;
			i_wb_ex_bus      : IN  t_wb_ex_fb;
			i_rd_mem_bus     : IN  t_rd_reg_data;
			i_rd_wb_bus      : IN  t_rd_reg_data;
			i_csr_mem_bus    : IN  t_csr_reg_data;
			i_csr_wb_bus     : IN  t_csr_reg_data;
			o_pipeline_flush : OUT STD_LOGIC;
			o_ex_pmp_csr     : OUT t_ex_pmp_data;
			o_ex_if_bus      : OUT t_ex_if_data;
			o_ex_mem_bus     : OUT t_ex_mem_data
		);
	END COMPONENT execution_stage;

	--! Memory Access stage component declaration
	COMPONENT memory_stage IS
		PORT (
			o_mem_addr       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_write_en   : OUT STD_LOGIC;
			o_mem_byte_en    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			o_mem_valid      : OUT STD_LOGIC;
			o_ss_instr       : OUT STD_LOGIC;
			i_pmp_fault      : IN  STD_LOGIC;
			i_ex_mem_bus     : IN  t_ex_mem_data;
			o_mem_wb_bus     : OUT t_mem_wb_data
		);
	END COMPONENT memory_stage;

	--! Writeback stage component declaration
	COMPONENT writeback_stage IS
		PORT (
			i_instruction_valid : IN  STD_LOGIC;
			i_mem_wb_bus        : IN  t_mem_wb_data;
			i_dmem_data         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_pipeline_flush    : OUT STD_LOGIC;
			o_wb_id_fb          : OUT t_rd_reg_data;
			o_wb_ex_fb          : OUT t_wb_ex_fb
		);
	END COMPONENT writeback_stage;

	--! Hazard detection unit component declaration
	COMPONENT hazard_detection_unit IS
		PORT (
			i_rs1_addr_id    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id    : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rd_addr_ex     : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_mem_read_ex    : IN  STD_LOGIC;
			o_pipeline_stall : OUT STD_LOGIC
		);
	END COMPONENT hazard_detection_unit;

	--! Physical Memory Protection unit component declaration
	COMPONENT pmp_unit IS
		PORT (
			i_pmp_csr     : IN  t_ex_pmp_data;
			i_mem_valid   : IN  STD_LOGIC;
			i_fetch_addr  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_fetch_addr  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_mem_addr    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			o_mem_addr    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			i_mem_write   : IN  STD_LOGIC;
			o_mem_write   : OUT STD_LOGIC;
			i_ss_instr    : IN  STD_LOGIC;
			o_fetch_fault : OUT STD_LOGIC;
			o_mem_fault   : OUT STD_LOGIC
		);
	END COMPONENT pmp_unit;

	SIGNAL s_if_id_bus  : t_if_id_data;   --! Bus output from IF stage
	SIGNAL s_id_ex_bus  : t_id_ex_data;   --! Bus output from ID stage
	SIGNAL s_ex_mem_bus : t_ex_mem_data;  --! Bus output from EX stage
	SIGNAL s_mem_wb_bus : t_mem_wb_data;  --! Bus output from MEM stage

	SIGNAL s_ex_if_bus  : t_ex_if_data;   --! Program flow redirection bus from EX to IF
	SIGNAL s_wb_id_bus  : t_rd_reg_data;  --! Writeback feedback bus from WB to ID stage GPRs
	SIGNAL s_wb_ex_bus  : t_wb_ex_fb;     --! Writeback exception and forwarding feedback to EX stage

	SIGNAL r_if_id_reg  : t_if_id_data;   --! IF/ID pipeline register record
	SIGNAL r_id_ex_reg  : t_id_ex_data;   --! ID/EX pipeline register record
	SIGNAL r_ex_mem_reg : t_ex_mem_data;  --! EX/MEM pipeline register record
	SIGNAL r_mem_wb_reg : t_mem_wb_data;  --! MEM/WB pipeline register record

	SIGNAL pipeline_stall        : STD_LOGIC; --! High if a load-use hazard is stalling the pipeline
	SIGNAL front_pipeline_flush  : STD_LOGIC; --! High if EX stage requests a branch/jump/trap redirection flush
	SIGNAL back_pipeline_flush   : STD_LOGIC; --! High if WB stage requests a trap or critical flush
	SIGNAL instruction_valid     : STD_LOGIC; --! High if current WB cycle instruction is valid

	SIGNAL s_pmp_csr             : t_ex_pmp_data;                 --! Current PMP settings configured by the CSR unit
	SIGNAL s_mem_valid           : STD_LOGIC := '0';              --! Asserted on valid memory transactions
	SIGNAL s_mem_write           : STD_LOGIC := '1';              --! Intermediate memory write request flag
	SIGNAL s_fetch_addr          : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Fetch stage target instruction address before PMP check
	SIGNAL s_mem_addr            : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory stage target data address before PMP check
	SIGNAL s_pmp_fetch_fault     : STD_LOGIC;                     --! High if fetch address triggers a PMP violation
	SIGNAL s_pmp_mem_fault       : STD_LOGIC;                     --! High if data access address triggers a PMP violation
	SIGNAL s_ss_instr            : STD_LOGIC;                     --! High if active instruction is a shadow stack operation

BEGIN
	-- Valid instruction retires if there are no stalls
	instruction_valid <= '1' WHEN pipeline_stall = '0' ELSE '0';

	U_PMP_UNIT : pmp_unit
	PORT MAP(
		i_pmp_csr     => s_pmp_csr,
		i_mem_valid   => s_mem_valid,
		i_fetch_addr  => s_fetch_addr,
		o_fetch_addr  => o_instr_addr,
		i_mem_addr    => s_mem_addr,
		o_mem_addr    => o_data_addr,
		i_mem_write   => s_mem_write,
		o_mem_write   => o_data_write_en,
		i_ss_instr    => s_ss_instr,
		o_fetch_fault => s_pmp_fetch_fault,
		o_mem_fault   => s_pmp_mem_fault
	);

	--! @brief Instruction Fetch Stage Instance
	U_IF_STAGE : instruction_fetch_stage
	PORT MAP(
		i_clk        => i_clk,
		i_rst        => i_rst,
		i_stall      => pipeline_stall,
		o_instr_addr => s_fetch_addr,
		i_instr_data => i_instr_data,
		i_pmp_fault  => s_pmp_fetch_fault,
		i_ex_if_bus  => s_ex_if_bus,
		o_if_id_bus  => s_if_id_bus
	);

	--! @brief Instruction Decode Stage Instance
	U_ID_STAGE : instruction_decode_stage
	PORT MAP(
		i_clk       => i_clk,
		i_rst       => i_rst,
		i_wb_id_bus => s_wb_id_bus,
		i_if_id_bus => r_if_id_reg,
		o_id_ex_bus => s_id_ex_bus
	);

	--! @brief Execution Stage Instance
	U_EX_STAGE : execution_stage
	PORT MAP(
		i_clk            => i_clk,
		i_rst            => i_rst,
		i_id_ex_bus      => r_id_ex_reg,
		i_wb_ex_bus      => s_wb_ex_bus,
		i_rd_mem_bus     => r_ex_mem_reg.rd_bus,
		i_rd_wb_bus      => r_mem_wb_reg.rd_bus,
		i_csr_mem_bus    => r_ex_mem_reg.csr_bus,
		i_csr_wb_bus     => r_mem_wb_reg.csr_bus,
		o_pipeline_flush => front_pipeline_flush,
		o_ex_pmp_csr     => s_pmp_csr,
		o_ex_if_bus      => s_ex_if_bus,
		o_ex_mem_bus     => s_ex_mem_bus
	);

	--! @brief Memory Access Stage Instance
	U_MEM_STAGE : memory_stage
	PORT MAP(
		o_mem_addr       => s_mem_addr,
		o_mem_write_data => o_data_write,
		o_mem_write_en   => s_mem_write,
		o_mem_byte_en    => o_data_byte_en,
		o_mem_valid      => s_mem_valid,
		o_ss_instr       => s_ss_instr,
		i_pmp_fault      => s_pmp_mem_fault,
		i_ex_mem_bus     => r_ex_mem_reg,
		o_mem_wb_bus     => s_mem_wb_bus
	);

	--! @brief Writeback Stage Instance
	U_WB_STAGE : writeback_stage
	PORT MAP(
		i_instruction_valid => instruction_valid,
		i_mem_wb_bus        => r_mem_wb_reg,
		i_dmem_data         => i_data_read,
		o_pipeline_flush    => back_pipeline_flush,
		o_wb_ex_fb          => s_wb_ex_bus,
		o_wb_id_fb          => s_wb_id_bus
	);

	--! @brief Hazard Detection Unit Instance
	U_HZD_DET : hazard_detection_unit
	PORT MAP(
		i_rs1_addr_id    => s_id_ex_bus.rs1_addr,
		i_rs2_addr_id    => s_id_ex_bus.rs2_addr,
		i_rd_addr_ex     => r_id_ex_reg.rd_addr,
		i_mem_read_ex    => r_id_ex_reg.mem_read,
		o_pipeline_stall => pipeline_stall
	);

	--! @brief IF/ID Pipeline Register Process
	--! @details Registers output from Instruction Fetch stage to Instruction Decode stage.
	--! Cleared on front-end flushes (control hazard) and stalled on load-use data hazards.
	P_IF_ID_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_if_id_reg <= C_IF_ID_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF front_pipeline_flush = '1' THEN
				r_if_id_reg <= C_IF_ID_RESET;  -- Clear register (NOP) on control redirection
			ELSIF pipeline_stall = '0' THEN
				r_if_id_reg <= s_if_id_bus;    -- Load next instruction if not stalled
			END IF;
		END IF;
	END PROCESS;

	--! @brief ID/EX Pipeline Register Process
	--! @details Registers decoded signals and registers operands into the Execution stage.
	--! Flushed to block executions on control redirections or stalls (bubble insertion).
	P_ID_EX_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_id_ex_reg <= C_ID_EX_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF front_pipeline_flush = '1' OR pipeline_stall = '1' THEN
				r_id_ex_reg <= C_ID_EX_RESET;  -- Clear register (bubble)
			ELSE
				r_id_ex_reg <= s_id_ex_bus;    -- Normal propagation
			END IF;
		END IF;
	END PROCESS;

	--! @brief EX/MEM Pipeline Register Process
	--! @details Registers execution results into the Memory stage.
	--! Cleared on back-end flushes (traps or retiring critical CSR configuration writes).
	P_EX_MEM_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_ex_mem_reg <= C_EX_MEM_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF back_pipeline_flush = '1' THEN
				r_ex_mem_reg <= C_EX_MEM_RESET; -- Clear register on trap
			ELSE 
				r_ex_mem_reg <= s_ex_mem_bus;   -- Normal propagation
			END IF;
		END IF;
	END PROCESS;

	--! @brief MEM/WB Pipeline Register Process
	--! @details Registers memory read results and target destinations into the Writeback stage.
	--! Cleared on back-end flushes (traps or retiring critical CSR configuration writes).
	P_MEM_WB_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_mem_wb_reg <= C_MEM_WB_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF back_pipeline_flush = '1' THEN
				r_mem_wb_reg <= C_MEM_WB_RESET; -- Clear register on trap
			ELSE 
				r_mem_wb_reg <= s_mem_wb_bus;   -- Normal propagation
			END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE structural;
