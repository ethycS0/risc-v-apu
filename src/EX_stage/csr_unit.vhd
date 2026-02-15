--! @file csr_unit.vhd
--! Control and Status Register Unit
--! @author ethycS
--! @details This module implements the Machine-mode Control and Status Registers
--! (CSRs) for the RV32I processor with basic trap handling support. It provides
--! read/write access to CSRs via CSR instructions (CSRRW, CSRRS, CSRRC) and
--! automatically updates trap-related CSRs during exception/interrupt handling.
--!
--! Implemented CSRs:
--! - mvendorid (0xF11): Vendor ID (read-only, hardwired to 0)
--! - misa (0x301): ISA and extensions (read-only, RV32I base)
--! - mstatus (0x300): Machine status register (MIE, MPIE fields)
--! - mtvec (0x305): Machine trap vector base address
--! - mepc (0x341): Machine exception program counter
--! - mcause (0x342): Machine trap cause
--! - mtval (0x343): Machine trap value (bad address or instruction)
--! - mie (0x304): Machine interrupt enable register
--! - mip (0x344): Machine interrupt pending register
--! - mscratch (0x340): Machine scratch register
--! - mcycle (0xB00): Machine cycle counter
--! - minstret (0xB02): Machine instructions retired counter
--!
--! Trap handling automatically saves PC to mepc, updates mcause/mtval, and
--! disables interrupts (MIE=0, MPIE=previous MIE). MRET restores interrupt
--! enable state and returns to mepc.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY csr_unit IS
	PORT (
		i_clk : IN STD_LOGIC;  --! Global clock
		i_rst : IN STD_LOGIC;  --! Synchronous reset (Active High)

		i_write_en           : IN STD_LOGIC;  --! CSR write enable (from CSR instructions)
		i_minstret_increment : IN STD_LOGIC;  --! Increment minstret counter (instruction retired)
		i_is_mret            : IN STD_LOGIC;  --! MRET instruction detected (return from trap)

		i_csr_op   : IN t_CsrOpcodes;                   --! CSR operation (RW, RS, RC)
		i_csr_addr : IN STD_LOGIC_VECTOR(11 DOWNTO 0); --! CSR address from instruction
		i_csr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! CSR write data (rs1 or uimm)

		i_trap_triggered : IN STD_LOGIC;                    --! Trap entry signal (exception or interrupt)
		i_pc_at_trap     : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! PC value at trap occurrence
		i_cause_code     : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap cause code (exception/interrupt type)
		i_trap_mtval     : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --! Trap value (faulting address or instruction)

                o_pmp_csr       : OUT t_ex_pmp_data;
                o_pmp_changed   : OUT STD_LOGIC;

                o_lpad_en   : OUT STD_LOGIC;                     --| Zicfilp enable status
		o_mtvec     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Machine trap vector (trap handler address)
		o_mepc      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Machine exception PC (return address)
		o_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)  --! CSR read data output
	);
END ENTITY csr_unit;

ARCHITECTURE behavioral OF csr_unit IS

	SIGNAL s_selected_reg_val : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Selected CSR value for read operations
	SIGNAL s_new_csr_value    : STD_LOGIC_VECTOR(31 DOWNTO 0); --! Computed new CSR value after operation

	CONSTANT c_mvendorid : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); --! Vendor ID (non-commercial implementation)
	CONSTANT c_misa_val  : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"40000100";     --! ISA = RV32I (bit 8 = I extension, bit 30-31 = XLEN=32)

	SIGNAL r_mie_bit  : STD_LOGIC := '0'; --! Machine Interrupt Enable bit (mstatus[3])
	SIGNAL r_mpie_bit : STD_LOGIC := '0'; --! Machine Previous Interrupt Enable bit (mstatus[7])
        SIGNAL r_mpp      : STD_LOGIC_VECTOR(1 DOWNTO 0) := "11";

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

        SIGNAL r_current_priv : STD_LOGIC := '1'; 

BEGIN

	--! @brief CSR Read Multiplexer Process
	--! @details Combinational process that selects the appropriate CSR value based on
	--! the CSR address. Reconstructs mstatus from individual MIE/MPIE bits with proper
	--! field positioning. Returns zero for unimplemented or invalid CSR addresses.
        P_CSR_SELECT : PROCESS (i_csr_addr, r_mtvec, r_mepc, r_mcause, r_mtval, r_mie_reg, r_mip_reg, r_mcycle, r_minstret, r_mie_bit, r_mpie_bit, r_mscratch)
        BEGIN
                s_selected_reg_val <= (OTHERS => '0');
                CASE i_csr_addr IS
                        WHEN x"F11" => s_selected_reg_val <= c_mvendorid;
                        WHEN x"301" => s_selected_reg_val <= c_misa_val;

                        WHEN x"300" =>
                                s_selected_reg_val(31 DOWNTO 13) <= (OTHERS => '0');
                                s_selected_reg_val(12 DOWNTO 11) <= r_mpp;
                                s_selected_reg_val(10 DOWNTO 8) <= (OTHERS => '0');
                                s_selected_reg_val(7) <= r_mpie_bit;
                                s_selected_reg_val(6 DOWNTO 4) <= (OTHERS => '0');
                                s_selected_reg_val(3) <= r_mie_bit;
                                s_selected_reg_val(2 DOWNTO 0) <= (OTHERS => '0');

                        WHEN x"305" => s_selected_reg_val <= r_mtvec;
                        WHEN x"341" => s_selected_reg_val <= r_mepc;
                        WHEN x"342" => s_selected_reg_val <= r_mcause;
                        WHEN x"343" => s_selected_reg_val <= r_mtval;
                        WHEN x"304" => s_selected_reg_val <= r_mie_reg;
                        WHEN x"340" => s_selected_reg_val <= r_mscratch;
                        WHEN x"344" => s_selected_reg_val <= r_mip_reg;
                        WHEN x"B00" => s_selected_reg_val <= r_mcycle;
                        WHEN x"B02" => s_selected_reg_val <= r_minstret;
                        WHEN x"747" => s_selected_reg_val <= r_mseccfg;
                        WHEN x"3A0" => s_selected_reg_val <= r_pmpcfg0;
                        WHEN x"3B0" => s_selected_reg_val <= r_pmpaddr0;
                        WHEN x"3B1" => s_selected_reg_val <= r_pmpaddr1;
                        WHEN x"3B2" => s_selected_reg_val <= r_pmpaddr2;
                        WHEN x"3B3" => s_selected_reg_val <= r_pmpaddr3;

                        WHEN OTHERS => s_selected_reg_val <= (OTHERS => '0');
                END CASE;
        END PROCESS;


	--! @brief CSR Operation Logic Process
	--! @details Combinational process that computes the new CSR value based on the
	--! CSR operation type:
	--! - CSR_RW (CSRRW): Write = rs1 value (replace)
	--! - CSR_RS (CSRRS): Write = CSR | rs1 (set bits)
	--! - CSR_RC (CSRRC): Write = CSR & ~rs1 (clear bits)
	P_CST_OPR : PROCESS (s_selected_reg_val, i_csr_data, i_csr_op)
	BEGIN
		CASE i_csr_op IS
			WHEN CSR_RW => s_new_csr_value <= i_csr_data;  -- Write (replace)
			WHEN CSR_RS => s_new_csr_value <= s_selected_reg_val OR i_csr_data;  -- Set bits
			WHEN CSR_RC => s_new_csr_value <= s_selected_reg_val AND (NOT i_csr_data);  -- Clear bits
			WHEN OTHERS => s_new_csr_value <= s_selected_reg_val;  -- No operation
		END CASE;
	END PROCESS;

	--! @brief CSR Register Update Process
	--! @details Synchronous process that updates CSR registers on the rising clock edge.
	--! Priority order (highest to lowest):
	--! 1. Trap entry: Save PC to mepc, update mcause/mtval, disable interrupts
	--! 2. MRET: Restore interrupt enable state from MPIE
	--! 3. CSR write: Update CSR based on write enable and address
	--!
	--! Performance counters (mcycle, minstret) increment independently unless being
	--! explicitly written by a CSR instruction.
	P_CSR_UPDATE : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_mie_bit <= '0';
			r_mpie_bit <= '0';
                        r_mpp <= "11";
			r_mtvec <= (OTHERS => '0');
			r_mepc <= (OTHERS => '0');
			r_mcause <= (OTHERS => '0');
			r_mtval <= (OTHERS => '0');
			r_mie_reg <= (OTHERS => '0');
			r_mcycle <= (OTHERS => '0');
			r_minstret <= (OTHERS => '0');
			r_mscratch <= (OTHERS => '0');
                        r_pmpcfg0 <= (OTHERS => '0');
                        r_current_priv <= '1';
		ELSIF rising_edge(i_clk) THEN

			-- Trap entry logic (highest priority)
			IF i_trap_triggered = '1' THEN
				r_mepc <= i_pc_at_trap;        -- Save faulting PC
				r_mcause <= i_cause_code;      -- Save trap cause
				r_mtval <= i_trap_mtval;       -- Save trap value
				r_mpie_bit <= r_mie_bit;       -- Save current MIE to MPIE
				r_mie_bit <= '0';              -- Disable interrupts
                                r_mpp <= r_current_priv & r_current_priv;
                                r_current_priv <= '1';

			-- MRET instruction logic
			ELSIF i_is_mret = '1' THEN
				r_mie_bit <= r_mpie_bit;  -- Restore MIE from MPIE
				r_mpie_bit <= '1';        -- Set MPIE to 1
                                r_current_priv <= r_mpp(1);
                                r_mpp      <= "00";

			-- Normal CSR write logic
			ELSIF i_write_en = '1' THEN
				CASE i_csr_addr IS
					WHEN x"300" =>  -- mstatus
						r_mie_bit  <= s_new_csr_value(3);
						r_mpie_bit <= s_new_csr_value(7);
                                                r_mpp      <= s_new_csr_value(12 DOWNTO 11);
					WHEN x"305" => r_mtvec <= s_new_csr_value;     -- mtvec
					WHEN x"340" => r_mscratch <= s_new_csr_value;  -- mscratch
					WHEN x"341" => r_mepc <= s_new_csr_value;      -- mepc
					WHEN x"342" => r_mcause <= s_new_csr_value;    -- mcause
					WHEN x"343" => r_mtval <= s_new_csr_value;     -- mtval
					WHEN x"304" => r_mie_reg <= s_new_csr_value;   -- mie
					WHEN x"B00" => r_mcycle <= s_new_csr_value;    -- mcycle
					WHEN x"B02" => r_minstret <= s_new_csr_value;  -- minstret
                                        WHEN x"747" => r_mseccfg <= s_new_csr_value;   -- mseccfg
                                        WHEN x"3A0" =>
                                                IF r_pmpcfg0(7) = '0' THEN
                                                        r_pmpcfg0(7 DOWNTO 0) <= s_new_csr_value(7 DOWNTO 0);
                                                END IF;

                                                IF r_pmpcfg0(15) = '0' THEN
                                                        r_pmpcfg0(15 DOWNTO 8) <= s_new_csr_value(15 DOWNTO 8);
                                                END IF;

                                                IF r_pmpcfg0(23) = '0' THEN
                                                        r_pmpcfg0(23 DOWNTO 16) <= s_new_csr_value(23 DOWNTO 16);
                                                END IF;

                                                IF r_pmpcfg0(31) = '0' THEN
                                                        r_pmpcfg0(31 DOWNTO 24) <= s_new_csr_value(31 DOWNTO 24);
                                                END IF;

                                        WHEN x"3B0" =>
                                                IF r_pmpcfg0(7) = '0' THEN
                                                        r_pmpaddr0 <= s_new_csr_value;
                                                END IF;

                                        WHEN x"3B1" =>
                                                IF r_pmpcfg0(15) = '0' THEN
                                                        r_pmpaddr1 <= s_new_csr_value;
                                                END IF;

                                        WHEN x"3B2" =>
                                                IF r_pmpcfg0(23) = '0' THEN
                                                        r_pmpaddr2 <= s_new_csr_value;
                                                END IF;

                                        WHEN x"3B3" =>
                                                IF r_pmpcfg0(31) = '0' THEN

                                                        r_pmpaddr3 <= s_new_csr_value;
                                                END IF;

                                        WHEN OTHERS => NULL;
                                        END CASE;
			END IF;

                        IF NOT (i_write_en = '1' AND i_csr_addr = x"B00") THEN
                                r_mcycle <= STD_LOGIC_VECTOR(unsigned(r_mcycle) + 1);
                        END IF;

                        IF i_minstret_increment = '1' AND NOT (i_write_en = '1' AND i_csr_addr = x"B02") THEN
                                r_minstret <= STD_LOGIC_VECTOR(unsigned(r_minstret) + 1);
                        END IF;

		END IF;
	END PROCESS;

        P_PMP_CHANGE_DETECT : PROCESS (i_write_en, i_csr_addr)
        BEGIN
                s_pmp_changed <= '0';
                IF i_write_en = '1' THEN
                        CASE i_csr_addr IS
                                WHEN x"3A0" | x"3B0" | x"3B1" | x"3B2" | x"3B3" =>
                                        s_pmp_changed <= '1';
                                WHEN OTHERS =>
                                        s_pmp_changed <= '0';
                        END CASE;
                END IF;
        END PROCESS;


	-- Output assignments
	o_mtvec <= r_mtvec;
        o_lpad_en <= r_mseccfg(0);
	o_mepc <= r_mepc;
	o_read_data <= s_selected_reg_val;

        o_pmp_changed <= s_pmp_changed;
        o_pmp_csr.pmpcfg0  <= r_pmpcfg0;
        o_pmp_csr.pmpaddr0 <= r_pmpaddr0;
        o_pmp_csr.pmpaddr1 <= r_pmpaddr1;
        o_pmp_csr.pmpaddr2 <= r_pmpaddr2;
        o_pmp_csr.pmpaddr3 <= r_pmpaddr3;
        o_pmp_csr.priv_mode <= r_current_priv;

END ARCHITECTURE behavioral;

