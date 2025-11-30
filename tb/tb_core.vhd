LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
USE std.env.ALL;

ENTITY tb_core IS
    GENERIC (
        G_IMEM_FILENAME : STRING := "code.hex";
        G_SIG_FILENAME : STRING := "signature.output";
        G_MAX_CYCLES : INTEGER := 200000; -- Increased max cycles
        
        -- CHANGED: All addresses are now INTEGERs to prevent GHDL CLI parsing errors
        G_TERMINATION_OFFSET : INTEGER := 0; 
        G_SIG_START_OFFSET   : INTEGER := 0;
        G_SIG_END_OFFSET     : INTEGER := 0
    );
END ENTITY tb_core;

ARCHITECTURE behavioral OF tb_core IS
    CONSTANT MEM_DEPTH : INTEGER := 2097152;
    CONSTANT MEM_BASE : UNSIGNED(31 DOWNTO 0) := x"80000000";
    CONSTANT CLK_PERIOD : TIME := 10 ns;

    -- Internal conversion of the termination address
    CONSTANT C_TERM_ADDR_SLV : STD_LOGIC_VECTOR(31 DOWNTO 0) := 
        std_logic_vector(MEM_BASE + to_unsigned(G_TERMINATION_OFFSET, 32));

    TYPE t_memory IS ARRAY (0 TO MEM_DEPTH - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SHARED VARIABLE main_memory : t_memory := (OTHERS => (OTHERS => '0'));

    SIGNAL s_clk : STD_LOGIC := '0';
    SIGNAL s_rst : STD_LOGIC := '1';
    SIGNAL s_instr_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_instr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_read : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write_en : STD_LOGIC;
    SIGNAL s_data_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_sim_finished : BOOLEAN := FALSE;

BEGIN
    U_CORE : ENTITY work.core
        PORT MAP(
            i_clk            => s_clk,
            i_rst            => s_rst,
            o_instr_addr     => s_instr_addr,
            i_instr_data     => s_instr_data,
            o_data_addr      => s_data_addr,
            i_data_read      => s_data_read,
            o_data_write     => s_data_write,
            o_data_write_en  => s_data_write_en,
            o_data_byte_en   => s_data_byte_en
        );

    -- Clock Generation
    p_clk : PROCESS
        VARIABLE v_cycles : INTEGER := 0;
    BEGIN
        WHILE NOT s_sim_finished LOOP
            s_clk <= '0';
            WAIT FOR CLK_PERIOD / 2;
            s_clk <= '1';
            WAIT FOR CLK_PERIOD / 2;

            v_cycles := v_cycles + 1;
            IF v_cycles > G_MAX_CYCLES THEN
                REPORT "TIMEOUT: Simulation ran too long." SEVERITY FAILURE;
            END IF;
        END LOOP;
        WAIT;
    END PROCESS;

    p_load_memory : PROCESS
        FILE hex_file : text;
        VARIABLE l : line;
        VARIABLE v_data_read : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE v_addr_index : INTEGER := 0;
        VARIABLE v_file_status : file_open_status;
    BEGIN
        s_rst <= '1';
        
        file_open(v_file_status, hex_file, G_IMEM_FILENAME, read_mode);
        IF v_file_status /= open_ok THEN
            REPORT "ERROR: Cannot open file: " & G_IMEM_FILENAME SEVERITY FAILURE;
        END IF;

        WHILE NOT endfile(hex_file) LOOP
            readline(hex_file, l);
            IF l'length > 0 THEN
                hread(l, v_data_read);
                IF v_addr_index < MEM_DEPTH THEN
                    main_memory(v_addr_index) := v_data_read;
                    v_addr_index := v_addr_index + 1;
                END IF;
            END IF;
        END LOOP;
        file_close(hex_file);

        REPORT "Memory Loaded: " & INTEGER'image(v_addr_index) & " words." SEVERITY NOTE;
        
        WAIT FOR CLK_PERIOD * 50;
        s_rst <= '0';
        WAIT;
    END PROCESS;

    -- Memory Read
    p_memory_read : PROCESS (s_instr_addr, s_data_addr, s_clk)
        VARIABLE v_instr_idx : INTEGER;
        VARIABLE v_data_idx : INTEGER;
    BEGIN
        -- Instruction Fetch
        IF unsigned(s_instr_addr) >= MEM_BASE THEN
            v_instr_idx := to_integer((unsigned(s_instr_addr) - MEM_BASE)) / 4;
        ELSE
            v_instr_idx := - 1;
        END IF;

        IF v_instr_idx >= 0 AND v_instr_idx < MEM_DEPTH THEN
            s_instr_data <= main_memory(v_instr_idx);
        ELSE
            s_instr_data <= (OTHERS => '0');
        END IF;

        -- Data Read
        IF unsigned(s_data_addr) >= MEM_BASE THEN
            v_data_idx := to_integer((unsigned(s_data_addr) - MEM_BASE)) / 4;
        ELSE
            v_data_idx := - 1;
        END IF;

        IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
            s_data_read <= main_memory(v_data_idx);
        ELSE
            s_data_read <= (OTHERS => '0');
        END IF;
    END PROCESS;

    -- Memory Write
    p_memory_write : PROCESS (s_clk)
        VARIABLE v_data_idx : INTEGER;
        FILE sig_file : TEXT;
        VARIABLE l : LINE;
        VARIABLE v_sig_start_idx : INTEGER;
        VARIABLE v_sig_end_idx : INTEGER;
        VARIABLE v_dump_val : STD_LOGIC_VECTOR(31 DOWNTO 0);

-- Inside the IF block:
    BEGIN
        IF rising_edge(s_clk) THEN
            IF s_data_write_en = '1' THEN
                IF s_data_addr = C_TERM_ADDR_SLV THEN
                    REPORT "TERMINATION: Magic address write detected!";

                    file_open(sig_file, G_SIG_FILENAME, write_mode);
                    v_sig_start_idx := G_SIG_START_OFFSET / 4;
                v_sig_end_idx   := G_SIG_END_OFFSET / 4;

                -- Safety Clamp
                IF v_sig_start_idx < 0 THEN v_sig_start_idx := 0; END IF;
                IF v_sig_end_idx >= MEM_DEPTH THEN v_sig_end_idx := MEM_DEPTH - 1; END IF;

                    -- Safety clamp
                    IF v_sig_start_idx < 0 THEN v_sig_start_idx := 0; END IF;
                    IF v_sig_end_idx >= MEM_DEPTH THEN v_sig_end_idx := MEM_DEPTH - 1; END IF;

                    FOR i IN v_sig_start_idx TO v_sig_end_idx LOOP
                        v_dump_val := main_memory(i);
                        hwrite(l, v_dump_val);
                        writeline(sig_file, l);
                    END LOOP;

                    file_close(sig_file);
                    s_sim_finished <= TRUE;
                    REPORT "Signature Dumped. Simulation Finished.";
                    stop;
                END IF;

                -- Normal Write
                IF unsigned(s_data_addr) >= MEM_BASE THEN
                    v_data_idx := to_integer((unsigned(s_data_addr) - MEM_BASE)) / 4;
                    IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
                        IF s_data_byte_en(0) = '1' THEN main_memory(v_data_idx)(7 DOWNTO 0) := s_data_write(7 DOWNTO 0); END IF;
                        IF s_data_byte_en(1) = '1' THEN main_memory(v_data_idx)(15 DOWNTO 8) := s_data_write(15 DOWNTO 8); END IF;
                        IF s_data_byte_en(2) = '1' THEN main_memory(v_data_idx)(23 DOWNTO 16) := s_data_write(23 DOWNTO 16); END IF;
                        IF s_data_byte_en(3) = '1' THEN main_memory(v_data_idx)(31 DOWNTO 24) := s_data_write(31 DOWNTO 24); END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
