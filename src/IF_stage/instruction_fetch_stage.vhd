--! @file instruction_fetch_stage.vhd
--! Instruction Fetch Stage
--! @author ethycS
--! @details This module handles the generation of the Program Counter (PC),
--! interfaces with the instruction memory, and manages pipeline stalls
--! and branch redirection.
--! 
--! It includes a Skid Buffer to handle the latency mismatch between
--! the 1-cycle memory read and instantaneous pipeline stalls.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY instruction_fetch_stage IS
        PORT (
                i_clk           : IN    STD_LOGIC;      --! Global Clock
                i_rst           : IN    STD_LOGIC;      --! Synchronous Reset (Active High)
                i_stall         : IN    STD_LOGIC;      --! Stall input from Hazard Detection Unit (freezes PC)
                o_instr_addr    : OUT   STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Address bus to Instruction Memory (BRAM)
                i_instr_data    : IN    STD_LOGIC_VECTOR(31 DOWNTO 0);  --! Data coming back from Instruction Memory (1-cycle latency)
                i_ex_if_bus     : IN    t_ex_if_data;   --! Feedback from Execution Stage (Branch/Jump targets)
                o_if_id_bus     : OUT   t_if_id_data    --! Output bus to Instruction Decode Stage
        );
END ENTITY instruction_fetch_stage;

ARCHITECTURE behavioral OF instruction_fetch_stage IS

        SIGNAL s_pc                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Current Program Counter register
        SIGNAL s_pc_plus_4              : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Combinational logic for PC + 4
        SIGNAL s_next_pc                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Next PC value (Mux between PC+4 and Branch Target)
        SIGNAL s_pc_latency_match       : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Delayed PC to match BRAM read latency.
        SIGNAL s_skid_buffer_instr      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Buffer to store instruction during a stall
        SIGNAL s_skid_buffer_pc         : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Buffer to store PC during a stall
        SIGNAL s_skid_valid             : STD_LOGIC; --! Flag indicating the skid buffer contains valid data
        SIGNAL s_flush_pending          : STD_LOGIC; --! Delayed flush signal to handle control hazard timing

BEGIN

        s_pc_plus_4 <= STD_LOGIC_VECTOR(unsigned(s_pc) + 4); -- Calculate next sequential PC
        o_instr_addr <= s_pc; -- Output current PC to memory

        -- Selects between the branch target (from EX stage) and sequential PC.
        WITH i_ex_if_bus.pc_redirect SELECT
                s_next_pc <= i_ex_if_bus.redirect_address WHEN '1',
                             s_pc_plus_4 WHEN OTHERS;

        --! @brief PC Register Process
        --! @details Updates the Program Counter on rising clock edge unless stalled.
        P_PC_UPDATE : PROCESS (i_clk, i_rst)
        BEGIN
                IF i_rst = '1' THEN
                        s_pc <= RESET_ADDRESS;
                ELSIF rising_edge(i_clk) THEN
                        IF i_stall = '0' THEN
                                s_pc <= s_next_pc;
                        END IF;
                END IF;
        END PROCESS;

        --! @brief Latency Matching Process
        --! @details Delays the PC signal by one cycle to match the synchronous RAM read latency.
        P_PC_ALIGNMENT : PROCESS (i_clk, i_rst)
        BEGIN
                IF i_rst = '1' THEN
                        s_pc_latency_match <= RESET_ADDRESS;
                ELSIF rising_edge(i_clk) THEN
                        IF i_stall = '0' THEN
                                s_pc_latency_match <= s_pc;
                        END IF;
                END IF;
        END PROCESS;

        --! @brief Skid Buffer Logic
        --! @details If the pipeline stalls (i_stall=1), the memory keeps outputting data.
        --! We must capture that data ("skid") into a buffer so it isn't lost.
        --! When the stall lifts, we feed the buffered data first.
        P_SKID_BUFFER : PROCESS (i_clk, i_rst)
        BEGIN
                IF i_rst = '1' THEN
                        s_skid_valid        <= '0';
                        s_skid_buffer_instr <= (OTHERS => '0');
                        s_skid_buffer_pc    <= (OTHERS => '0');
                ELSIF rising_edge(i_clk) THEN
                        IF i_stall = '1' AND s_skid_valid = '0' THEN
                                s_skid_buffer_instr <= i_instr_data;
                                s_skid_buffer_pc    <= s_pc_latency_match;
                                s_skid_valid        <= '1';
                        ELSIF i_stall = '0' THEN
                                s_skid_valid        <= '0';
                        END IF;
                END IF;
        END PROCESS;

        --! @brief Flush Handling
        --! @details Registers the redirect signal to invalidate the instruction currently
        --! being fetched from memory (which is now the wrong path).
        P_FLUSH_LOGIC : PROCESS (i_clk, i_rst)
        BEGIN
                IF i_rst = '1' THEN
                        s_flush_pending <= '0';
                ELSIF rising_edge(i_clk) THEN
                        IF i_stall = '0' THEN
                                s_flush_pending <= i_ex_if_bus.pc_redirect;
                        END IF;
                END IF;
        END PROCESS;

        --! @brief Output Mux Process
        --! @details Determines the final IF/ID bus values based on priority:
        --! 1. Flush (branch taken) -> Insert NOP
        --! 2. Returning from stall -> Use buffered data
        --! 3. Normal Operation -> Use data direct from memory
        P_OUTPUT : PROCESS (ALL)
        BEGIN
                o_if_id_bus.pc  <= s_pc_latency_match;
                o_if_id_bus.pc4 <= STD_LOGIC_VECTOR(unsigned(s_pc_latency_match) + 4);

                IF s_flush_pending = '1' THEN
                        o_if_id_bus.instruction <= C_NOP;

                ELSIF s_skid_valid = '1' THEN
                        o_if_id_bus.instruction <= s_skid_buffer_instr;
                        o_if_id_bus.pc          <= s_skid_buffer_pc;
                        o_if_id_bus.pc4         <= STD_LOGIC_VECTOR(unsigned(s_skid_buffer_pc) + 4);

                ELSE
                        o_if_id_bus.instruction <= i_instr_data;
                END IF;
        END PROCESS;

END ARCHITECTURE behavioral;
