LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY core IS
	PORT (
		i_clk : IN STD_LOGIC;  --! System clock
		i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

		o_instr_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Instruction memory address
		i_instr_data : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Instruction memory read data

		o_data_addr     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory address
		i_data_read     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory read data
		o_data_write    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory write data
		o_data_byte_en  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);   --! Data memory byte enable mask
		o_data_write_en : OUT STD_LOGIC                       --! Data memory write enable
	);
END ENTITY core;

ARCHITECTURE structural OF core IS

	--! Instruction Fetch stage component declaration
	COMPONENT instruction_fetch_stage IS
		PORT (
                        i_clk            : IN    STD_LOGIC;
                        i_rst            : IN    STD_LOGIC;
                        i_stall          : IN    STD_LOGIC;
                        o_instr_addr    : OUT   STD_LOGIC_VECTOR(31 DOWNTO 0);
                        i_instr_data    : IN    STD_LOGIC_VECTOR(31 DOWNTO 0);
                        i_pmp_fault      : IN    STD_LOGIC;
                        i_ex_if_bus      : IN    t_ex_if_data;
                        o_if_id_bus      : OUT   t_if_id_data
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
                        i_clk : IN STD_LOGIC;
                        i_rst : IN STD_LOGIC;

                        i_id_ex_bus  : IN t_id_ex_data;
                        i_wb_ex_bus   : IN t_wb_ex_fb;

                        i_rd_mem_bus : IN t_rd_reg_data;
                        i_rd_wb_bus  : IN t_rd_reg_data;

                        i_csr_mem_bus : IN t_csr_reg_data;
                        i_csr_wb_bus  : IN t_csr_reg_data;

                        o_pipeline_flush : OUT STD_LOGIC;
                        o_ex_pmp_csr : OUT t_ex_pmp_data;
                        o_ex_if_bus  : OUT t_ex_if_data;
                        o_ex_mem_bus : OUT t_ex_mem_data
		);
	END COMPONENT execution_stage;

	--! Memory Access stage component declaration
	COMPONENT memory_stage IS
		PORT (
                        o_mem_addr       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory address output (to data memory)
                        o_mem_write_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Memory write data output (aligned/replicated)
                        o_mem_write_en   : OUT STD_LOGIC;                     --! Memory write enable signal
                        o_mem_byte_en    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);  --! Byte enable mask (selects active bytes)

                        o_mem_valid : OUT STD_LOGIC;
                        o_ss_instr : OUT STD_LOGIC;

                        i_pmp_fault  : IN STD_LOGIC;
                        i_ex_mem_bus : IN  t_ex_mem_data; --! Input bus from Execute stage (ALU result, control signals)
                        o_mem_wb_bus : OUT t_mem_wb_data  --! Output bus to Writeback stage 
		);
	END COMPONENT memory_stage;

	--! Writeback stage component declaration
	COMPONENT writeback_stage IS
		PORT (
                        i_instruction_valid : IN STD_LOGIC;
                        i_mem_wb_bus : IN  t_mem_wb_data;                  --! Input bus from Memory stage (control signals, ALU result)
                        i_dmem_data  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data memory read data (raw 32-bit value)
                        o_pipeline_flush : OUT STD_LOGIC;
                        o_wb_id_fb : OUT t_rd_reg_data;                  --! Output bus to ID stage (register file write data)
                        o_wb_ex_fb  : OUT t_wb_ex_fb
		);
	END COMPONENT writeback_stage;

	--! Hazard detection unit component declaration
	COMPONENT hazard_detection_unit IS
		PORT (
			i_rs1_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_rs2_addr_id : IN STD_LOGIC_VECTOR(4 DOWNTO 0);

			i_rd_addr_ex  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
			i_mem_read_ex : IN STD_LOGIC;

			o_pipeline_stall : OUT STD_LOGIC
		);
	END COMPONENT hazard_detection_unit;

        COMPONENT pmp_unit IS
                PORT (
                        i_pmp_csr   : IN t_ex_pmp_data;
                        i_mem_valid : IN STD_LOGIC;

                        i_fetch_addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                        o_fetch_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

                        i_mem_addr : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
                        o_mem_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

                        i_mem_write : IN  STD_LOGIC;
                        o_mem_write : OUT STD_LOGIC;

                        i_ss_instr : IN STD_LOGIC;

                        o_fetch_fault : OUT STD_LOGIC;
                        o_mem_fault   : OUT STD_LOGIC

                );
        END COMPONENT pmp_unit;

	SIGNAL s_if_id_bus  : t_if_id_data;   --! IF stage output (to IF/ID pipeline register)
	SIGNAL s_id_ex_bus  : t_id_ex_data;   --! ID stage output (to ID/EX pipeline register)
	SIGNAL s_ex_mem_bus : t_ex_mem_data;  --! EX stage output (to EX/MEM pipeline register)
	SIGNAL s_mem_wb_bus : t_mem_wb_data;  --! MEM stage output (to MEM/WB pipeline register)


	SIGNAL s_ex_if_bus  : t_ex_if_data;   --! Feedback bus from EX to IF (branch/jump redirect)
	SIGNAL s_wb_id_bus  : t_rd_reg_data;  --! Feedback bus from WB to ID (register write)
	SIGNAL s_wb_ex_bus  : t_wb_ex_fb; 

	SIGNAL r_if_id_reg  : t_if_id_data;   --! IF/ID pipeline register
	SIGNAL r_id_ex_reg  : t_id_ex_data;   --! ID/EX pipeline register
	SIGNAL r_ex_mem_reg : t_ex_mem_data;  --! EX/MEM pipeline register
	SIGNAL r_mem_wb_reg : t_mem_wb_data;  --! MEM/WB pipeline register

	SIGNAL pipeline_stall : STD_LOGIC;  --! Pipeline stall signal (freezes IF and ID stages)
	SIGNAL front_pipeline_flush : STD_LOGIC;  --! Pipeline flush signal (inserts bubbles on control hazard)
	SIGNAL back_pipeline_flush : STD_LOGIC;  --! Pipeline flush signal (inserts bubbles on control hazard)

	SIGNAL instruction_valid  : STD_LOGIC;  --! Valid instruction in WB stage (not stalled)

        SIGNAL s_pmp_csr : t_ex_pmp_data;
        SIGNAL s_mem_valid : STD_LOGIC := '0';
        SIGNAL s_mem_write : STD_LOGIC := '1';

        SIGNAL s_fetch_addr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERs => '0');
        SIGNAL s_mem_addr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERs => '0');

        SIGNAL s_pmp_fetch_fault : STD_LOGIC;
        SIGNAL s_pmp_mem_fault : STD_LOGIC;

        SIGNAL s_ss_instr : STD_LOGIC;

BEGIN
	-- Pipeline control signals
	instruction_valid <= '1' WHEN pipeline_stall = '0' ELSE '0';

        U_PMP_UNIT : pmp_unit
        PORT MAP(
                i_pmp_csr => s_pmp_csr,
                i_mem_valid => s_mem_valid,
                i_fetch_addr => s_fetch_addr,
                o_fetch_addr => o_instr_addr,
                i_mem_addr => s_mem_addr,
                o_mem_addr => o_data_addr,
                i_mem_write => s_mem_write,
                o_mem_write => o_data_write_en,
                i_ss_instr => s_ss_instr,
                o_fetch_fault => s_pmp_fetch_fault,
                o_mem_fault => s_pmp_mem_fault
        );


	--! @brief Instruction Fetch Stage Instance
	--! @details Fetches instructions from memory, manages PC updates, and handles
	--! branch/jump redirects from the EX stage. Stalls when pipeline_stall is asserted.
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
	--! @details Decodes instructions, reads register file, generates control signals,
	--! and extracts immediate values. Receives writeback data from WB stage.
	U_ID_STAGE : instruction_decode_stage
	PORT MAP(
		i_clk       => i_clk,
		i_rst       => i_rst,
		i_wb_id_bus => s_wb_id_bus,
		i_if_id_bus => r_if_id_reg,
		o_id_ex_bus => s_id_ex_bus
	);

	--! @brief Execution Stage Instance
	--! @details Performs ALU operations, evaluates branches, handles CSR access and
	--! traps, and implements data forwarding to resolve hazards. Generates PC redirect
	--! signals for control flow changes.
	U_EX_STAGE : execution_stage
	PORT MAP(
		i_clk                   => i_clk,
		i_rst                   => i_rst,
		i_id_ex_bus             => r_id_ex_reg,
                i_wb_ex_bus             => s_wb_ex_bus,
		i_rd_mem_bus            => r_ex_mem_reg.rd_bus,
		i_rd_wb_bus             => r_mem_wb_reg.rd_bus,
                i_csr_mem_bus           => r_ex_mem_reg.csr_bus,
                i_csr_wb_bus            => r_mem_wb_reg.csr_bus,
                o_pipeline_flush        => front_pipeline_flush,
                o_ex_pmp_csr            => s_pmp_csr,
		o_ex_if_bus             => s_ex_if_bus,
		o_ex_mem_bus            => s_ex_mem_bus
	);

	--! @brief Memory Access Stage Instance
	--! @details Handles data memory access for load/store instructions. Generates
	--! memory address, write data, byte enables, and control signals.
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
	--! @details Reconstructs load data, multiplexes writeback sources, and writes
	--! results to the register file. Signals instruction retirement for minstret counter.
	U_WB_STAGE : writeback_stage
	PORT MAP(
                i_instruction_valid    => instruction_valid,
		i_mem_wb_bus           => r_mem_wb_reg,
		i_dmem_data            => i_data_read,
                o_pipeline_flush       => back_pipeline_flush,
		o_wb_ex_fb             => s_wb_ex_bus,
		o_wb_id_fb             => s_wb_id_bus
	);

	--! @brief Hazard Detection Unit Instance
	--! @details Detects load-use data hazards and generates pipeline stall signals
	--! to insert bubbles when necessary.
	U_HZD_DET : hazard_detection_unit
	PORT MAP(
		i_rs1_addr_id    => s_id_ex_bus.rs1_addr,
		i_rs2_addr_id    => s_id_ex_bus.rs2_addr,
		i_rd_addr_ex     => r_id_ex_reg.rd_addr,
		i_mem_read_ex    => r_id_ex_reg.mem_read,
		o_pipeline_stall => pipeline_stall
	);

	--! @brief IF/ID Pipeline Register Process
	--! @details Synchronous process that updates the IF/ID pipeline register on each
	--! clock cycle. The register is flushed (reset to NOP) on branches/jumps/traps,
	--! and held (stalled) when a load-use hazard is detected. This register isolates
	--! the IF and ID stages, allowing independent operation.
	P_IF_ID_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_if_id_reg <= C_IF_ID_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF front_pipeline_flush = '1' THEN
				r_if_id_reg <= C_IF_ID_RESET;  -- Flush on control hazard
			ELSIF pipeline_stall = '0' THEN
				r_if_id_reg <= s_if_id_bus;  -- Normal operation (no stall)
			END IF;

		END IF;
	END PROCESS;

	--! @brief ID/EX Pipeline Register Process
	--! @details Synchronous process that updates the ID/EX pipeline register. This
	--! register is flushed on control hazards (branches/jumps) or when a load-use
	--! stall occurs (inserting a bubble). Flushing converts the instruction to a NOP,
	--! preventing incorrect operations from executing after a control flow change.
	P_ID_EX_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_id_ex_reg <= C_ID_EX_RESET;
		ELSIF rising_edge(i_clk) THEN
			IF front_pipeline_flush = '1' OR pipeline_stall = '1' THEN
				r_id_ex_reg <= C_ID_EX_RESET;  -- Flush on control hazard or stall
			ELSE
				r_id_ex_reg <= s_id_ex_bus;  -- Normal operation
			END IF;
		END IF;
	END PROCESS;

	--! @brief EX/MEM Pipeline Register Process
	--! @details Synchronous process that updates the EX/MEM pipeline register. This
	--! register always updates on each clock cycle (no stall/flush control) as hazards
	--! are resolved before reaching this stage. It isolates the EX and MEM stages.
	P_EX_MEM_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_ex_mem_reg <= C_EX_MEM_RESET;
		ELSIF rising_edge(i_clk) THEN
                        IF back_pipeline_flush = '1' THEN -- WB flush logic here
                                r_ex_mem_reg <= C_EX_MEM_RESET;
                        ELSE 
                                r_ex_mem_reg <= s_ex_mem_bus;  
                        END IF;
		END IF;
	END PROCESS;

	--! @brief MEM/WB Pipeline Register Process
	--! @details Synchronous process that updates the MEM/WB pipeline register. Like
	--! EX/MEM, this register always updates as hazards are fully resolved. It isolates
	--! the MEM and WB stages, holding data until it can be written to the register file.
	P_MEM_WB_REG : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_mem_wb_reg <= C_MEM_WB_RESET;
		ELSIF rising_edge(i_clk) THEN
                        IF back_pipeline_flush = '1' THEN --WB flush logic here
                                r_mem_wb_reg <= C_MEM_WB_RESET;
                        ELSE 
                                r_mem_wb_reg <= s_mem_wb_bus;  -- Always update (no hazard control needed)
                        END IF;
		END IF;
	END PROCESS;

END ARCHITECTURE structural;

