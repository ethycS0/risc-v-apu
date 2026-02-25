LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY pmp_unit IS
	PORT (
		i_pmp_csr   : IN t_ex_pmp_data;
		i_mem_valid : IN STD_LOGIC;

		i_fetch_addr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_fetch_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_mem_addr : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_mem_addr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_mem_write : IN  STD_LOGIC;
		o_mem_write : OUT STD_LOGIC;

                i_msse : IN STD_LOGIC;
                i_ss_write : IN STD_LOGIC;

		o_fetch_fault : OUT STD_LOGIC;
		o_mem_fault   : OUT STD_LOGIC

	);
END ENTITY pmp_unit;

ARCHITECTURE behavioral OF pmp_unit IS
        FUNCTION check_access (
                addr : STD_LOGIC_VECTOR(31 DOWNTO 0);
                access_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
                pmp_csr : t_ex_pmp_data;
                msse : STD_LOGIC;
                ss_write : STD_LOGIC
        ) RETURN STD_LOGIC IS

                VARIABLE v_fault : STD_LOGIC := '0';
                VARIABLE v_match_found : BOOLEAN := FALSE;
                VARIABLE v_cfg_byte : STD_LOGIC_VECTOR(7 DOWNTO 0);
                VARIABLE v_mode : STD_LOGIC_VECTOR(1 DOWNTO 0);

                VARIABLE v_addr_u : UNSIGNED(31 DOWNTO 0);
                VARIABLE v_lower_bound : UNSIGNED(31 DOWNTO 0);
                VARIABLE v_upper_bound : UNSIGNED(31 DOWNTO 0);
                VARIABLE v_pmp_val : UNSIGNED(31 DOWNTO 0);

                VARIABLE v_napot_mask : UNSIGNED(29 DOWNTO 0);
                VARIABLE v_pmp_bits : UNSIGNED(29 DOWNTO 0);
                VARIABLE v_addr_bits : UNSIGNED(31 DOWNTO 2);
                VARIABLE v_is_ss_region : BOOLEAN;

                TYPE t_addr_array IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
                VARIABLE v_addrs : t_addr_array;
                TYPE t_cfg_array IS ARRAY (0 TO 3) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
                VARIABLE v_cfgs : t_cfg_array;

        BEGIN
                v_addrs(0) := pmp_csr.pmpaddr0;
                v_cfgs(0) := pmp_csr.pmpcfg0(7 DOWNTO 0);
                v_addrs(1) := pmp_csr.pmpaddr1;
                v_cfgs(1) := pmp_csr.pmpcfg0(15 DOWNTO 8);
                v_addrs(2) := pmp_csr.pmpaddr2;
                v_cfgs(2) := pmp_csr.pmpcfg0(23 DOWNTO 16);
                v_addrs(3) := pmp_csr.pmpaddr3;
                v_cfgs(3) := pmp_csr.pmpcfg0(31 DOWNTO 24);

                v_match_found := FALSE;
                v_fault := '0';
                v_addr_u := unsigned(addr);
                FOR i IN 0 TO 3 LOOP
                        IF NOT v_match_found THEN
                                v_cfg_byte := v_cfgs(i);
                                v_mode := v_cfg_byte(4 DOWNTO 3);
                                v_pmp_val := unsigned(v_addrs(i));

                                CASE v_mode IS
                                        WHEN "00" =>
                                                v_match_found := FALSE;
                                        WHEN "01" =>
                                                v_upper_bound := shift_left(v_pmp_val, 2);

                                                IF i = 0 THEN
                                                        v_lower_bound := (OTHERS => '0');
                                                ELSE
                                                        v_lower_bound := shift_left(unsigned(v_addrs(i - 1)), 2);
                                                END IF;

                                                IF (v_addr_u >= v_lower_bound) AND (v_addr_u < v_upper_bound) THEN
                                                        v_match_found := TRUE;
                                                END IF;
                                        WHEN "10" =>
                                                IF v_addr_u(31 DOWNTO 2) = v_pmp_val(29 DOWNTO 0) THEN
                                                        v_match_found := TRUE;
                                                END IF;

                                        WHEN "11" =>

                                                v_pmp_bits := v_pmp_val(29 DOWNTO 0);
                                                v_addr_bits := v_addr_u(31 DOWNTO 2);

                                                IF v_pmp_bits(0) = '0' THEN
                                                        v_napot_mask := (OTHERS => '1');
                                                        v_napot_mask(0) := '0';
                                                ELSIF v_pmp_bits(1 DOWNTO 0) = "01" THEN
                                                        v_napot_mask := (OTHERS => '1');
                                                        v_napot_mask(1 DOWNTO 0) := "00";
                                                ELSIF v_pmp_bits(2 DOWNTO 0) = "011" THEN
                                                        v_napot_mask := (OTHERS => '1');
                                                        v_napot_mask(2 DOWNTO 0) := "000";
                                                ELSIF v_pmp_bits(3 DOWNTO 0) = "0111" THEN
                                                        v_napot_mask := (OTHERS => '1');
                                                        v_napot_mask(3 DOWNTO 0) := "0000";
                                                ELSIF v_pmp_bits(4 DOWNTO 0) = "01111" THEN
                                                        v_napot_mask := (OTHERS => '1');
                                                        v_napot_mask(4 DOWNTO 0) := "00000";
                                                ELSE
                                                        v_napot_mask := (OTHERS => '0');
                                                END IF;

                                                IF (v_addr_bits AND v_napot_mask) = (v_pmp_bits AND v_napot_mask) THEN
                                                        v_match_found := TRUE;
                                                END IF;

                                        WHEN OTHERS => NULL;
                                END CASE;

                                IF v_match_found THEN
                                        v_is_ss_region := (pmp_csr.pmp_e_bits(i) = '1') AND 
                                                (v_cfg_byte(2 DOWNTO 0) = "010") AND 
                                                (msse = '1');
                                        IF v_is_ss_region THEN
                                                IF access_type(2) = '1' THEN
                                                        v_fault := '1'; 
                                                ELSIF access_type(1) = '1' THEN
                                                        IF ss_write = '1' THEN
                                                                v_fault := '0'; 
                                                        ELSE
                                                                v_fault := '1'; 
                                                        END IF;
                                                ELSIF access_type(0) = '1' THEN
                                                        v_fault := '0';
                                                END IF;
                                        ELSE
                                                IF (v_cfg_byte(7) = '0') THEN
                                                        v_fault := '0';
                                                ELSE
                                                        IF (access_type(2) = '1' AND v_cfg_byte(2) = '0') OR
                                                                (access_type(1) = '1' AND v_cfg_byte(1) = '0') OR
                                                                (access_type(0) = '1' AND v_cfg_byte(0) = '0') THEN
                                                                v_fault := '1';
                                                        ELSE
                                                                v_fault := '0';
                                                        END IF;
                                                END IF;
                                        END IF;
                                END IF;
                        END IF;
                END LOOP;

                IF NOT v_match_found THEN
                        IF access_type(1) = '1' AND ss_write = '1' THEN
                                v_fault := '1';
                        ELSE
                                v_fault := '0';
                        END IF;
                END IF;

                RETURN v_fault;
        END FUNCTION;

        SIGNAL s_fetch_fault : STD_LOGIC := '0';
        SIGNAL s_mem_fault   : STD_LOGIC := '0';

BEGIN

        P_FETCH_ACCESS_CHECK : PROCESS (i_fetch_addr, i_pmp_csr)
        BEGIN
                s_fetch_fault <= check_access(i_fetch_addr, "100", i_pmp_csr, '0', '0');
        END PROCESS P_FETCH_ACCESS_CHECK;

        P_MEM_ACCESS_CHECK : PROCESS (i_mem_addr, i_mem_write, i_mem_valid, i_pmp_csr, i_msse, i_ss_write)
                VARIABLE v_acc_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
        BEGIN
                IF i_mem_valid = '1' THEN
                        IF i_mem_write = '1' THEN
                                v_acc_type := "010";
                        ELSE
                                v_acc_type := "001";
                        END IF;

                        s_mem_fault <= check_access(i_mem_addr, v_acc_type, i_pmp_csr, i_msse, i_ss_write);
                ELSE
                        s_mem_fault <= '0';
                END IF;
        END PROCESS P_MEM_ACCESS_CHECK;

        P_PASSTHROUGH : PROCESS (ALL)
        BEGIN
                o_fetch_fault <= s_fetch_fault;
                o_mem_fault <= s_mem_fault;

                IF s_fetch_fault = '1' THEN
                        o_fetch_addr <= (OTHERS => '1');
                ELSE
                        o_fetch_addr <= i_fetch_addr;
                END IF;

                IF s_mem_fault = '1' THEN
                        o_mem_write <= '0';
                        o_mem_addr <= (OTHERS => '1');
                ELSE
                        o_mem_write <= i_mem_write;
                        o_mem_addr <= i_mem_addr;
                END IF;

        END PROCESS P_PASSTHROUGH;

END ARCHITECTURE behavioral;

