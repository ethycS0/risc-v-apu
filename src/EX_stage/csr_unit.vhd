LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY csr_unit IS
	PORT (
		i_clk : IN STD_LOGIC;  --! Global clock
		i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

                i_csr_raddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
                o_csr_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);

                i_csr_wbus        : IN t_csr_reg_data;
                i_trap            : IN STD_LOGIC;
                i_trap_pc         : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                i_trap_mtval      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                i_trap_mcause     : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                i_minstret        : IN STD_LOGIC;
                i_mret            : IN STD_LOGIC;

                o_pmp_csr       : OUT t_ex_pmp_data;
                o_pmp_changed   : OUT STD_LOGIC;
                o_lpad_en       : OUT STD_LOGIC;                     
		o_mtvec         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); 
		o_mepc          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); 
                o_msse          : OUT STD_LOGIC
	);
END ENTITY csr_unit;

ARCHITECTURE behavioral OF csr_unit IS

	CONSTANT c_mvendorid : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Vendor ID (non-commercial implementation)
	CONSTANT c_misa_val  : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"40000100";     --! ISA = RV32I (bit 8 = I extension, bit 30-31 = XLEN=32)

	SIGNAL r_mie_bit  : STD_LOGIC := '0'; --! Machine Interrupt Enable bit (mstatus[3])
	SIGNAL r_mpie_bit : STD_LOGIC := '0'; --! Machine Previous Interrupt Enable bit (mstatus[7])

	SIGNAL r_mtvec    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Trap Vector register
	SIGNAL r_mtval    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Trap Value register
	SIGNAL r_mepc     : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Exception Program Counter
	SIGNAL r_mcause   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Cause register
	SIGNAL r_mie_reg  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Interrupt Enable register
	SIGNAL r_mip_reg  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Interrupt Pending register

	SIGNAL r_mcycle    : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Cycle counter (increments every clock)
	SIGNAL r_minstret  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Instructions Retired counter
	SIGNAL r_mscratch  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Machine Scratch register (software use)
        SIGNAL r_mseccfg   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --| Machine Security Configuration Register 

        SIGNAL s_pmp_changed : STD_LOGIC;
        SIGNAL r_pmpcfg0     :  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); 
        SIGNAL r_pmpaddr0    :  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); 
        SIGNAL r_pmpaddr1    :  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); 
        SIGNAL r_pmpaddr2    :  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); 
        SIGNAL r_pmpaddr3    :  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); 

        SIGNAL r_miselect   : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
        SIGNAL r_mireg      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
        SIGNAL r_mireg2     : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
        SIGNAL r_pmp_e_bits : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

        SIGNAL r_ssp : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

        IMPURE FUNCTION read_csr (
                csr_addr : STD_LOGIC_VECTOR(11 DOWNTO 0)
        ) RETURN STD_LOGIC_VECTOR IS
                VARIABLE v_read_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
        BEGIN
                v_read_data := (OTHERS => '0');

                CASE csr_addr IS
                        WHEN x"F11" => v_read_data := c_mvendorid;
                        WHEN x"301" => v_read_data := c_misa_val;
                        WHEN x"300" =>
                                v_read_data(31 DOWNTO 13) := (OTHERS => '0');
                                v_read_data(12 DOWNTO 11) := "11";
                                v_read_data(10 DOWNTO 8)  := (OTHERS => '0');
                                v_read_data(7)            := r_mpie_bit;
                                v_read_data(6 DOWNTO 4)   := (OTHERS => '0');
                                v_read_data(3)            := r_mie_bit;
                                v_read_data(2 DOWNTO 0)   := (OTHERS => '0');

                        WHEN x"011" => v_read_data := r_ssp;
                        WHEN x"305" => v_read_data := r_mtvec;
                        WHEN x"341" => v_read_data := r_mepc;
                        WHEN x"342" => v_read_data := r_mcause;
                        WHEN x"343" => v_read_data := r_mtval;
                        WHEN x"304" => v_read_data := r_mie_reg;
                        WHEN x"340" => v_read_data := r_mscratch;
                        WHEN x"344" => v_read_data := r_mip_reg;
                        WHEN x"B00" => v_read_data := r_mcycle;
                        WHEN x"B02" => v_read_data := r_minstret;
                        WHEN x"747" => v_read_data := r_mseccfg;
                        WHEN x"3A0" => v_read_data := r_pmpcfg0;
                        WHEN x"3B0" => v_read_data := r_pmpaddr0;
                        WHEN x"3B1" => v_read_data := r_pmpaddr1;
                        WHEN x"3B2" => v_read_data := r_pmpaddr2;
                        WHEN x"3B3" => v_read_data := r_pmpaddr3;

                        WHEN x"350" =>
                                v_read_data(31 DOWNTO 2) := (OTHERS => '0');
                                v_read_data(1 DOWNTO 0)  := r_miselect(1 DOWNTO 0);

                        WHEN x"351" =>
                                CASE r_miselect(1 DOWNTO 0) IS
                                        WHEN "00" => v_read_data   := r_pmpaddr0;
                                        WHEN "01" => v_read_data   := r_pmpaddr1;
                                        WHEN "10" => v_read_data   := r_pmpaddr2;
                                        WHEN "11" => v_read_data   := r_pmpaddr3;
                                        WHEN OTHERS => v_read_data := (OTHERS => '0');
                                END CASE;

                        WHEN x"352" =>
                                v_read_data(30 DOWNTO 8) := (OTHERS => '0');
                                CASE r_miselect(1 DOWNTO 0) IS
                                        WHEN "00" =>
                                                v_read_data(31)         := r_pmp_e_bits(0);
                                                v_read_data(7 DOWNTO 0) := r_pmpcfg0(7 DOWNTO 0);
                                        WHEN "01" =>
                                                v_read_data(31)         := r_pmp_e_bits(1);
                                                v_read_data(7 DOWNTO 0) := r_pmpcfg0(15 DOWNTO 8);
                                        WHEN "10" =>
                                                v_read_data(31)         := r_pmp_e_bits(2);
                                                v_read_data(7 DOWNTO 0) := r_pmpcfg0(23 DOWNTO 16);
                                        WHEN "11" =>
                                                v_read_data(31)         := r_pmp_e_bits(3);
                                                v_read_data(7 DOWNTO 0) := r_pmpcfg0(31 DOWNTO 24);
                                        WHEN OTHERS            =>
                                                v_read_data := (OTHERS => '0');
                                END CASE;

                        WHEN OTHERS =>
                                v_read_data := (OTHERS => '0');
                END CASE;

                RETURN v_read_data;
        END FUNCTION;

BEGIN

	P_CSR_UPDATE : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_mie_bit <= '0';
			r_mpie_bit <= '0';
			r_mtvec <= (OTHERS => '0');
			r_mepc <= (OTHERS => '0');
			r_mcause <= (OTHERS => '0');
			r_mtval <= (OTHERS => '0');
			r_mie_reg <= (OTHERS => '0');
			r_mcycle <= (OTHERS => '0');
			r_minstret <= (OTHERS => '0');
			r_mscratch <= (OTHERS => '0');
                        r_pmpcfg0 <= (OTHERS => '0');
                        r_miselect <= (OTHERS => '0');
                        r_pmp_e_bits <= (OTHERS => '0');
                        r_ssp <= (OTHERS => '0');
		ELSIF rising_edge(i_clk) THEN
                        IF i_trap = '1' THEN
                                r_mepc   <= i_trap_pc;
                                r_mcause <= i_trap_mcause;
                                r_mtval  <= i_trap_mtval;

                                r_mpie_bit <= r_mie_bit;
                                r_mie_bit  <= '0';

                        ELSIF i_mret = '1' THEN
                                r_mie_bit  <= r_mpie_bit;
                                r_mpie_bit <= '1';

                        ELSIF i_csr_wbus.csr_write_en = '1' THEN
				CASE i_csr_wbus.csr_addr IS
					WHEN x"300" =>  -- mstatus
						r_mie_bit  <= i_csr_wbus.csr_data(3);
						r_mpie_bit <= i_csr_wbus.csr_data(7);
					WHEN x"305" => r_mtvec <= i_csr_wbus.csr_data;     -- mtvec
					WHEN x"340" => r_mscratch <= i_csr_wbus.csr_data;  -- mscratch
					WHEN x"341" => r_mepc <= i_csr_wbus.csr_data;      -- mepc
					WHEN x"342" => r_mcause <= i_csr_wbus.csr_data;    -- mcause
					WHEN x"343" => r_mtval <= i_csr_wbus.csr_data;     -- mtval
					WHEN x"304" => r_mie_reg <= i_csr_wbus.csr_data;   -- mie
					WHEN x"B00" => r_mcycle <= i_csr_wbus.csr_data;    -- mcycle
					WHEN x"B02" => r_minstret <= i_csr_wbus.csr_data;  -- minstret
                                        WHEN x"747" => r_mseccfg <= i_csr_wbus.csr_data;   -- mseccfg
                                        WHEN x"3A0" =>
                                                IF r_pmpcfg0(7) = '0' THEN
                                                        r_pmpcfg0(7 DOWNTO 0) <= i_csr_wbus.csr_data(7 DOWNTO 0);
                                                END IF;

                                                IF r_pmpcfg0(15) = '0' THEN
                                                        r_pmpcfg0(15 DOWNTO 8) <= i_csr_wbus.csr_data(15 DOWNTO 8);
                                                END IF;

                                                IF r_pmpcfg0(23) = '0' THEN
                                                        r_pmpcfg0(23 DOWNTO 16) <= i_csr_wbus.csr_data(23 DOWNTO 16);
                                                END IF;

                                                IF r_pmpcfg0(31) = '0' THEN
                                                        r_pmpcfg0(31 DOWNTO 24) <= i_csr_wbus.csr_data(31 DOWNTO 24);
                                                END IF;

                                        WHEN x"3B0" =>
                                                IF r_pmpcfg0(7) = '0' THEN
                                                        r_pmpaddr0 <= i_csr_wbus.csr_data;
                                                END IF;

                                        WHEN x"3B1" =>
                                                IF r_pmpcfg0(15) = '0' THEN
                                                        r_pmpaddr1 <= i_csr_wbus.csr_data;
                                                END IF;

                                        WHEN x"3B2" =>
                                                IF r_pmpcfg0(23) = '0' THEN
                                                        r_pmpaddr2 <= i_csr_wbus.csr_data;
                                                END IF;

                                        WHEN x"3B3" =>
                                                IF r_pmpcfg0(31) = '0' THEN
                                                        r_pmpaddr3 <= i_csr_wbus.csr_data;
                                                END IF;

                                        WHEN x"350" =>
                                                r_miselect(1 DOWNTO 0) <= i_csr_wbus.csr_data(1 DOWNTO 0);

                                        WHEN x"351" => 
                                                CASE r_miselect(1 DOWNTO 0) IS
                                                        WHEN "00" => IF r_pmpcfg0(7) = '0' THEN r_pmpaddr0 <= i_csr_wbus.csr_data; END IF;
                                                        WHEN "01" => IF r_pmpcfg0(15) = '0' THEN r_pmpaddr1 <= i_csr_wbus.csr_data; END IF;
                                                        WHEN "10" => IF r_pmpcfg0(23) = '0' THEN r_pmpaddr2 <= i_csr_wbus.csr_data; END IF;
                                                        WHEN "11" => IF r_pmpcfg0(31) = '0' THEN r_pmpaddr3 <= i_csr_wbus.csr_data; END IF;
                                                        WHEN OTHERS => NULL;
                                                END CASE;

                                        WHEN x"352" => 
                                                CASE r_miselect(1 DOWNTO 0) IS
                                                        WHEN "00" =>
                                                                IF r_pmpcfg0(7) = '0' THEN
                                                                        r_pmpcfg0(7 DOWNTO 0) <= i_csr_wbus.csr_data(7 DOWNTO 0);
                                                                        r_pmp_e_bits(0) <= i_csr_wbus.csr_data(31);
                                                                END IF;
                                                        WHEN "01" =>
                                                                IF r_pmpcfg0(15) = '0' THEN
                                                                        r_pmpcfg0(15 DOWNTO 8) <= i_csr_wbus.csr_data(15 DOWNTO 8);
                                                                        r_pmp_e_bits(1) <= i_csr_wbus.csr_data(31);
                                                                END IF;
                                                        WHEN "10" =>
                                                                IF r_pmpcfg0(23) = '0' THEN
                                                                        r_pmpcfg0(23 DOWNTO 16) <= i_csr_wbus.csr_data(23 DOWNTO 16);
                                                                        r_pmp_e_bits(2) <= i_csr_wbus.csr_data(31);
                                                                END IF;
                                                        WHEN "11" =>
                                                                IF r_pmpcfg0(31) = '0' THEN
                                                                        r_pmpcfg0(31 DOWNTO 24) <= i_csr_wbus.csr_data(31 DOWNTO 24);
                                                                        r_pmp_e_bits(3) <= i_csr_wbus.csr_data(31);
                                                                END IF;
                                                        WHEN OTHERS => NULL;
                                                END CASE;
                                        WHEN x"011" => 
                                                r_ssp <= i_csr_wbus.csr_data;

                                        WHEN OTHERS => NULL;
                                        END CASE;
			END IF;

                        IF NOT (i_csr_wbus.csr_write_en = '1' AND i_csr_wbus.csr_addr = x"B00") THEN
                                r_mcycle <= STD_LOGIC_VECTOR(unsigned(r_mcycle) + 1);
                        END IF;

                        IF i_minstret = '1' AND NOT (i_csr_wbus.csr_write_en = '1' AND i_csr_wbus.csr_addr= x"B02") THEN
                                r_minstret <= STD_LOGIC_VECTOR(unsigned(r_minstret) + 1);
                        END IF;

		END IF;
	END PROCESS;

        P_PMP_CHANGE_DETECT : PROCESS (i_csr_wbus.csr_write_en, i_csr_wbus.csr_addr)
        BEGIN
                s_pmp_changed <= '0';
                IF i_csr_wbus.csr_write_en = '1' THEN
                        CASE i_csr_wbus.csr_addr IS
                                WHEN x"3A0" | x"3B0" | x"3B1" | x"3B2" | x"3B3" | x"351" | x"352" =>
                                        s_pmp_changed <= '1';
                                WHEN OTHERS =>
                                        s_pmp_changed <= '0';
                        END CASE;
                END IF;
        END PROCESS;

	-- Output assignments
	o_csr_rdata <= read_csr(i_csr_raddr);
	o_mtvec <= r_mtvec;
        o_lpad_en <= r_mseccfg(0);
	o_mepc <= r_mepc;
        o_msse <= r_mseccfg(2);  
        o_pmp_changed <= s_pmp_changed;
        o_pmp_csr.pmpcfg0  <= r_pmpcfg0;
        o_pmp_csr.pmpaddr0 <= r_pmpaddr0;
        o_pmp_csr.pmpaddr1 <= r_pmpaddr1;
        o_pmp_csr.pmpaddr2 <= r_pmpaddr2;
        o_pmp_csr.pmpaddr3 <= r_pmpaddr3;
        o_pmp_csr.pmp_e_bits <= r_pmp_e_bits;

END ARCHITECTURE behavioral;

