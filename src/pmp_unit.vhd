--! @file pmp_unit.vhd
--! @brief Physical Memory Protection (PMP) Unit with Shadow Stack security controls.
--! @author ethycS
--! @details This module implements the RISC-V Physical Memory Protection (PMP) checker for
--! 4 regions. It supports TOR (Top-of-Range), NA4 (Naturally Aligned 4-Byte), and NAPOT
--! (Naturally Aligned Power-of-Two) address matching.
--!
--! Security integrations:
--! - **Smcfiss Shadow Stack Protection**:
--!   - Classifies a PMP region as a Shadow Stack region if the region's enable bit (`pmp_e_bits(i)`) is active
--!     and its permission configuration is set to `"010"` (write-only space).
--!   - In a shadow stack region, normal memory writes (standard `sw`/`sh`/`sb`) and instruction fetches are blocked.
--!     Writes are strictly restricted to shadow stack push instructions (`sspush` / `ss_instr = '1'`).
--!   - Out-of-region shadow stack operations are blocked; shadow stack instructions (`ss_instr = '1'`) targeting
--!     normal memory space (non-shadow-stack regions) will trigger a PMP write/read fault.
--! - **Machine-Mode PMP Enforcement**: Enforces PMP checks in Machine-mode (M-mode) when the region's lock bit `L`
--!   (bit 7 of the config byte) is set.
--! - **Fault Actions**: When a violation occurs, the unit blocks memory writes (`o_mem_write <= '0'`), forces
--!   addresses to all-ones (`x"FFFFFFFF"`), and asserts fault flags (`o_fetch_fault` / `o_mem_fault`) which propagate to traps.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY pmp_unit IS
	PORT (
		i_pmp_csr     : IN  t_ex_pmp_data;                 --! PMP configuration settings from CSR unit
		i_mem_valid   : IN  STD_LOGIC;                     --! Memory transaction active (read/write) strobe

		i_fetch_addr  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input address of current instruction fetch
		o_fetch_addr  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Output instruction fetch address (scrambled on fault)

		i_mem_addr    : IN  STD_LOGIC_VECTOR(31 DOWNTO 0); --! Input address of current data memory access
		o_mem_addr    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --! Output data memory address (scrambled on fault)

		i_mem_write   : IN  STD_LOGIC;                     --! Input memory write request strobe
		o_mem_write   : OUT STD_LOGIC;                     --! Output memory write request (forced low on fault)

		i_ss_instr    : IN  STD_LOGIC;                     --! High if memory request is from a shadow stack operation

		o_fetch_fault : OUT STD_LOGIC;                     --! Instruction Fetch access fault exception indicator
		o_mem_fault   : OUT STD_LOGIC                      --! Memory data load/store access fault exception indicator
	);
END ENTITY pmp_unit;

ARCHITECTURE behavioral OF pmp_unit IS

	--! @brief Checks memory accesses against PMP configuration rules.
	--! @details Combinational helper function evaluating address range matches and permission flags.
	--! - NAPOT masks are calculated by checking trailing ones in the `pmpaddr` register.
	--! - Checks if the region is a Shadow Stack region (PMP enable bit = 1 and configuration = "010").
	--! - Restricts standard stores to non-shadow-stack regions and shadow stack pushes to shadow stack regions.
	--! - Evaluates lock bit (L) settings to check M-mode permissions.
	FUNCTION check_access (
		addr        : STD_LOGIC_VECTOR(31 DOWNTO 0);
		access_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
		pmp_csr     : t_ex_pmp_data;
		ss_instr    : STD_LOGIC
	) RETURN STD_LOGIC IS

		VARIABLE v_fault       : STD_LOGIC := '0';
		VARIABLE v_match_found : BOOLEAN := FALSE;
		VARIABLE v_cfg_byte    : STD_LOGIC_VECTOR(7 DOWNTO 0);
		VARIABLE v_mode        : STD_LOGIC_VECTOR(1 DOWNTO 0);

		VARIABLE v_addr_u      : UNSIGNED(31 DOWNTO 0);
		VARIABLE v_lower_bound : UNSIGNED(31 DOWNTO 0);
		VARIABLE v_upper_bound : UNSIGNED(31 DOWNTO 0);
		VARIABLE v_pmp_val     : UNSIGNED(31 DOWNTO 0);

		VARIABLE v_napot_mask  : UNSIGNED(29 DOWNTO 0);
		VARIABLE v_pmp_bits    : UNSIGNED(29 DOWNTO 0);
		VARIABLE v_addr_bits   : UNSIGNED(31 DOWNTO 2);
		VARIABLE v_is_ss_region: BOOLEAN;

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
					WHEN "00" => -- OFF
						v_match_found := FALSE;
					WHEN "01" => -- TOR (Top of Range)
						v_upper_bound := shift_left(v_pmp_val, 2);

						IF i = 0 THEN
							v_lower_bound := (OTHERS => '0');
						ELSE
							v_lower_bound := shift_left(unsigned(v_addrs(i - 1)), 2);
						END IF;

						IF (v_addr_u >= v_lower_bound) AND (v_addr_u < v_upper_bound) THEN
							v_match_found := TRUE;
						END IF;
					WHEN "10" => -- NA4 (Naturally Aligned 4-byte)
						IF v_addr_u(31 DOWNTO 2) = v_pmp_val(29 DOWNTO 0) THEN
							v_match_found := TRUE;
						END IF;

					WHEN "11" => -- NAPOT (Naturally Aligned Power-of-Two)
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
					-- A region is a shadow stack region if enabled (pmp_e_bits=1) and configured to "010"
					v_is_ss_region := (pmp_csr.pmp_e_bits(i) = '1') AND 
					                  (v_cfg_byte(2 DOWNTO 0) = "010");
					                    
					IF v_is_ss_region THEN
						IF access_type(2) = '1' THEN
							v_fault := '1'; -- Executing from shadow stack is forbidden
						ELSIF access_type(1) = '1' THEN
							IF ss_instr = '1' THEN
								v_fault := '0'; -- Only shadow stack instructions (sspush) can write
							ELSE
								v_fault := '1'; -- Standard stores trigger fault
							END IF;
						ELSIF access_type(0) = '1' THEN
							v_fault := '0'; -- Reads (sspop checks) are allowed
						END IF;
					ELSE
						-- Normal memory region: shadow stack instructions are forbidden
						IF ss_instr = '1' THEN
							v_fault := '1';
						ELSE
							-- standard PMP check: lock bit (L) must be set for M-mode checks
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
			END IF;
		END LOOP;

		-- If no match found, shadow stack operations fault, others bypass
		IF NOT v_match_found THEN
			IF ss_instr = '1' THEN
				v_fault := '1';
			ELSE
				v_fault := '0';
			END IF;
		END IF;

		RETURN v_fault;
	END FUNCTION;

	SIGNAL s_fetch_fault : STD_LOGIC := '0'; --! Fetch PMP fault intermediate signal
	SIGNAL s_mem_fault   : STD_LOGIC := '0'; --! Memory read/write PMP fault intermediate signal

BEGIN

	--! @brief Process to evaluate Instruction Fetch PMP violations.
	P_FETCH_ACCESS_CHECK : PROCESS (ALL)
	BEGIN
		s_fetch_fault <= check_access(i_fetch_addr, "100", i_pmp_csr, '0');
	END PROCESS P_FETCH_ACCESS_CHECK;

	--! @brief Process to evaluate Data Load/Store PMP violations.
	P_MEM_ACCESS_CHECK : PROCESS (ALL)
		VARIABLE v_acc_type : STD_LOGIC_VECTOR(2 DOWNTO 0);
	BEGIN
		IF i_mem_valid = '1' THEN
			IF i_mem_write = '1' THEN
				v_acc_type := "010"; -- Write access check
			ELSE
				v_acc_type := "001"; -- Read access check
			END IF;

			s_mem_fault <= check_access(i_mem_addr, v_acc_type, i_pmp_csr, i_ss_instr);
		ELSE
			s_mem_fault <= '0';
		END IF;
	END PROCESS P_MEM_ACCESS_CHECK;

	--! @brief Process to handle fault actions and forward addresses.
	--! @details Scrambles addresses to all-ones (x"FFFFFFFF") and drops writes on PMP violations.
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
