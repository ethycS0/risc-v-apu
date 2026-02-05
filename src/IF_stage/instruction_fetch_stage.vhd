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

        SIGNAL s_instr_addr             : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Address to fetch Instruction from
        SIGNAL s_pc                     : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Current Program Counter register
        SIGNAL s_pc_plus                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Combinational logic for PC + 2/4
        SIGNAL s_next_pc                : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Next PC value (Mux between PC+2/4 and Branch Target)
        SIGNAL s_pc_latency_match       : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Delayed PC to match BRAM read latency.
        SIGNAL s_skid_buffer_instr      : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Buffer to store instruction during a stall
        SIGNAL s_skid_buffer_pc         : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Buffer to store PC during a stall
        SIGNAL s_skid_valid             : STD_LOGIC; --! Flag indicating the skid buffer contains valid data
        SIGNAL s_flush_pending          : STD_LOGIC; --! Delayed flush signal to handle control hazard timing
BEGIN

        P_PC_UPDATE : PROCESS
        BEGIN
        END PROCESS;

        P_REDIRECT : PROCESS (i_ex_if_bus.pc_redirect)
        BEGIN
                IF i_ex_if_bus.pc_redirect = '1' THEN
                        s_pc <= i_ex_if_bus.redirect_address & b"10";
                ELSE 
                        s_pc <=s_next_pc;
                END IF;

        END PROCESS;

        P_FETCH : PROCESS
        BEGIN
        END PROCESS;
        
        P_INSTR : PROCESS
        BEGIN
        END PROCESS;
        
        P_OUTPUT : PROCESS
        BEGIN
        END PROCESS;
        
END ARCHITECTURE behavioral;
