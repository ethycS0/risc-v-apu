LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;

ENTITY tb_core IS
    GENERIC (
        G_IMEM_FILENAME : STRING := "imem.hex";
        G_SIG_FILENAME : STRING := "signature.output";
        G_SIG_BEGIN_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000";
        G_SIG_END_ADDR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000"
    );
END ENTITY tb_core;

ARCHITECTURE behavioral OF tb_core IS

    CONSTANT MEM_DEPTH : INTEGER := 131072;
    TYPE t_memory IS ARRAY (0 TO MEM_DEPTH - 1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL r_memory : t_memory := (OTHERS => (OTHERS => '0'));

    SIGNAL s_clk : STD_LOGIC := '0';
    SIGNAL s_rst : STD_LOGIC := '1';
    SIGNAL s_instr_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_instr_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_read : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL s_data_write_en : STD_LOGIC;
    SIGNAL s_data_byte_en : STD_LOGIC_VECTOR(3 DOWNTO 0);

    CONSTANT C_CLK_PERIOD : TIME := 10 ns;
    SIGNAL s_sim_finished : BOOLEAN := FALSE;
    SIGNAL s_cycle_count : INTEGER := 0;
    CONSTANT C_MAX_CYCLES : INTEGER := 50000;
    SIGNAL s_instr_count : INTEGER := 0;

    -- Helper function: Convert hex character to 4-bit value
    FUNCTION char_to_hex(c : CHARACTER) RETURN STD_LOGIC_VECTOR IS
    BEGIN
        CASE c IS
            WHEN '0' => RETURN "0000";
            WHEN '1' => RETURN "0001";
            WHEN '2' => RETURN "0010";
            WHEN '3' => RETURN "0011";
            WHEN '4' => RETURN "0100";
            WHEN '5' => RETURN "0101";
            WHEN '6' => RETURN "0110";
            WHEN '7' => RETURN "0111";
            WHEN '8' => RETURN "1000";
            WHEN '9' => RETURN "1001";
            WHEN 'a' | 'A' => RETURN "1010";
            WHEN 'b' | 'B' => RETURN "1011";
            WHEN 'c' | 'C' => RETURN "1100";
            WHEN 'd' | 'D' => RETURN "1101";
            WHEN 'e' | 'E' => RETURN "1110";
            WHEN 'f' | 'F' => RETURN "1111";
            WHEN OTHERS => RETURN "0000";
        END CASE;
    END FUNCTION;

    -- Helper function: Convert 4-bit value to hex character
    FUNCTION hex_to_char(v : STD_LOGIC_VECTOR(3 DOWNTO 0)) RETURN CHARACTER IS
    BEGIN
        CASE v IS
            WHEN "0000" => RETURN '0';
            WHEN "0001" => RETURN '1';
            WHEN "0010" => RETURN '2';
            WHEN "0011" => RETURN '3';
            WHEN "0100" => RETURN '4';
            WHEN "0101" => RETURN '5';
            WHEN "0110" => RETURN '6';
            WHEN "0111" => RETURN '7';
            WHEN "1000" => RETURN '8';
            WHEN "1001" => RETURN '9';
            WHEN "1010" => RETURN 'a';
            WHEN "1011" => RETURN 'b';
            WHEN "1100" => RETURN 'c';
            WHEN "1101" => RETURN 'd';
            WHEN "1110" => RETURN 'e';
            WHEN "1111" => RETURN 'f';
            WHEN OTHERS => RETURN 'x';
        END CASE;
    END FUNCTION;

BEGIN

    U_CORE : ENTITY work.core
        PORT MAP(
            i_clk           => s_clk,
            i_rst           => s_rst,
            o_instr_addr    => s_instr_addr,
            i_instr_data    => s_instr_data,
            o_data_addr     => s_data_addr,
            i_data_read     => s_data_read,
            o_data_write    => s_data_write,
            o_data_write_en => s_data_write_en,
            o_data_byte_en  => s_data_byte_en
        );

    p_clk : PROCESS
    BEGIN
        WHILE NOT s_sim_finished LOOP
            s_clk <= '0';
            WAIT FOR C_CLK_PERIOD / 2;
            s_clk <= '1';
            WAIT FOR C_CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    p_load_memory : PROCESS
        FILE hex_file : text;
        VARIABLE l : line;
        VARIABLE v_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE v_addr_index : INTEGER := 0;
        VARIABLE v_file_status : file_open_status;
        VARIABLE v_char : CHARACTER;
        VARIABLE v_good : BOOLEAN;
    BEGIN
        s_rst <= '1';
        WAIT FOR C_CLK_PERIOD * 5;

        file_open(v_file_status, hex_file, G_IMEM_FILENAME, read_mode);
        
        IF v_file_status /= open_ok THEN
            REPORT "ERROR: Cannot open file: " & G_IMEM_FILENAME 
                   SEVERITY FAILURE;
        END IF;

        WHILE NOT endfile(hex_file) LOOP
            readline(hex_file, l);
            
            IF l'length >= 8 THEN
                -- Read 8 hex characters manually (32 bits)
                v_data := (OTHERS => '0');
                FOR i IN 0 TO 7 LOOP
                    read(l, v_char, v_good);
                    IF v_good THEN
                        v_data := v_data(27 DOWNTO 0) & char_to_hex(v_char);
                    END IF;
                END LOOP;
                
                IF v_addr_index < MEM_DEPTH THEN
                    r_memory(v_addr_index) <= v_data;
                    v_addr_index := v_addr_index + 1;
                END IF;
            END IF;
        END LOOP;
        
        file_close(hex_file);
        REPORT "Memory Loaded: " & INTEGER'image(v_addr_index) & " words";

        WAIT FOR C_CLK_PERIOD * 2;
        s_rst <= '0';
        REPORT "Reset released, starting execution...";
        WAIT;
    END PROCESS;

        p_debug : PROCESS(s_clk)
        BEGIN
            IF rising_edge(s_clk) THEN
                IF s_rst = '0' AND s_cycle_count < 20 THEN
                    REPORT "Cycle " & INTEGER'image(s_cycle_count) &
                           ": instr_addr=" & INTEGER'image(to_integer(unsigned(s_instr_addr(11 DOWNTO 0)))) &
                           " instr_data_zero=" & BOOLEAN'image(s_instr_data = x"00000000")
                           SEVERITY NOTE;
                END IF;
            END IF;
        END PROCESS;

    p_memory_access : PROCESS (s_clk)
        VARIABLE v_instr_idx : INTEGER;
        VARIABLE v_data_idx : INTEGER;
        VARIABLE v_prev_instr_addr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '1');
        CONSTANT C_MEM_BASE : UNSIGNED(31 DOWNTO 0) := x"80000000";
    BEGIN
        IF rising_edge(s_clk) THEN
            -- Instruction fetch with address translation
            IF unsigned(s_instr_addr) >= C_MEM_BASE THEN
                v_instr_idx := to_integer((unsigned(s_instr_addr) - C_MEM_BASE)) / 4;
            ELSE
                v_instr_idx := -1;
            END IF;
            
            IF v_instr_idx >= 0 AND v_instr_idx < MEM_DEPTH THEN
                s_instr_data <= r_memory(v_instr_idx);
                
                IF s_instr_addr /= v_prev_instr_addr AND s_rst = '0' THEN
                    s_instr_count <= s_instr_count + 1;
                    v_prev_instr_addr := s_instr_addr;
                END IF;
            ELSE
                s_instr_data <= (OTHERS => '0');
                IF s_rst = '0' AND v_instr_idx /= -1 THEN
                    REPORT "ERROR: Instruction fetch out of bounds, index=" & 
                           INTEGER'image(v_instr_idx) SEVERITY ERROR;
                END IF;
            END IF;

            -- Data access with address translation
            IF unsigned(s_data_addr) >= C_MEM_BASE THEN
                v_data_idx := to_integer((unsigned(s_data_addr) - C_MEM_BASE)) / 4;
            ELSE
                v_data_idx := -1;
            END IF;

            IF s_data_write_en = '1' THEN
                IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
                    IF s_data_byte_en(0) = '1' THEN
                        r_memory(v_data_idx)(7 DOWNTO 0) <= s_data_write(7 DOWNTO 0);
                    END IF;
                    IF s_data_byte_en(1) = '1' THEN
                        r_memory(v_data_idx)(15 DOWNTO 8) <= s_data_write(15 DOWNTO 8);
                    END IF;
                    IF s_data_byte_en(2) = '1' THEN
                        r_memory(v_data_idx)(23 DOWNTO 16) <= s_data_write(23 DOWNTO 16);
                    END IF;
                    IF s_data_byte_en(3) = '1' THEN
                        r_memory(v_data_idx)(31 DOWNTO 24) <= s_data_write(31 DOWNTO 24);
                    END IF;
                    
                    IF unsigned(s_data_addr) >= unsigned(G_SIG_BEGIN_ADDR) AND 
                       unsigned(s_data_addr) < unsigned(G_SIG_END_ADDR) THEN
                        REPORT "Signature write detected" SEVERITY NOTE;
                    END IF;
                END IF;
            END IF;

            IF v_data_idx >= 0 AND v_data_idx < MEM_DEPTH THEN
                s_data_read <= r_memory(v_data_idx);
            ELSE
                s_data_read <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;

    p_terminate : PROCESS (s_clk)
        FILE sig_file : text;
        VARIABLE l : line;
        VARIABLE v_start_idx : INTEGER;
        VARIABLE v_end_idx : INTEGER;
        VARIABLE v_temp_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE v_file_status : file_open_status;
        VARIABLE v_file_opened : BOOLEAN := FALSE;
    BEGIN
        IF rising_edge(s_clk) THEN
            IF s_rst = '0' THEN
                s_cycle_count <= s_cycle_count + 1;
                
                IF s_cycle_count MOD 1000 = 0 THEN
                    REPORT "Cycle " & INTEGER'image(s_cycle_count) & 
                           ", Instructions=" & INTEGER'image(s_instr_count);
                END IF;
                
                IF s_cycle_count >= C_MAX_CYCLES THEN
                    REPORT "TIMEOUT after " & INTEGER'image(s_cycle_count) & " cycles" 
                           SEVERITY FAILURE;
                    s_sim_finished <= TRUE;
                END IF;
            END IF;
            
            -- Check for termination signal
            IF s_data_write_en = '1' AND s_data_addr = x"80001000" AND NOT v_file_opened THEN
                REPORT "TERMINATION: Magic address write detected!";

                file_open(v_file_status, sig_file, G_SIG_FILENAME, write_mode);
                v_file_opened := TRUE;
                
                IF v_file_status /= open_ok THEN
                    REPORT "ERROR: Cannot create signature file" SEVERITY FAILURE;
                END IF;

                -- Calculate indices with offset
                v_start_idx := to_integer(unsigned(G_SIG_BEGIN_ADDR) - x"80000000") / 4;
                v_end_idx := to_integer(unsigned(G_SIG_END_ADDR) - x"80000000") / 4;
                
                REPORT "Dumping " & INTEGER'image(v_end_idx - v_start_idx + 1) & " words";

                -- Write signature manually as hex
                FOR i IN v_start_idx TO v_end_idx - 1 LOOP
                    v_temp_data := r_memory(i);
                    
                    -- Convert 32-bit word to 8 hex characters
                    FOR j IN 7 DOWNTO 0 LOOP
                        write(l, hex_to_char(v_temp_data(j*4+3 DOWNTO j*4)));
                    END LOOP;
                    
                    writeline(sig_file, l);
                END LOOP;

                file_close(sig_file);
                REPORT "Simulation finished after " & INTEGER'image(s_cycle_count) & " cycles";
                s_sim_finished <= TRUE;
                ASSERT FALSE REPORT "Test PASSED" SEVERITY FAILURE;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;

