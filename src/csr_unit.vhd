LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY csr_unit IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		-- Control Signals
		i_write_en : IN STD_LOGIC;

		-- Data from Decode/Execute Stage
		i_csr_op   : IN t_CsrOpcodes; -- RW, RS, RC, etc.
		i_csr_addr : IN STD_LOGIC_VECTOR(CSR_ADDR_WIDTH - 1 DOWNTO 0);
		i_csr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		-- Outputs 
		o_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY csr_unit;

ARCHITECTURE behavioral OF csr_unit IS
	SIGNAL s_selected_reg_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_new_csr_value : STD_LOGIC_VECTOR(31 DOWNTO 0);
	-- || Internal Register ||

	-- Status and Information
	SIGNAL r_misa : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000"; -- x301: Set to RV32I later 
	SIGNAL r_mvendorid : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000000"; -- xF11: Read-Only
	SIGNAL r_mstatus : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x300

	-- Exception and Trap 
	SIGNAL r_mtvec : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x305
	SIGNAL r_mepc : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x341
	SIGNAL r_mcause : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x342
	SIGNAL r_mie : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x304 
	SIGNAL r_mip : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- x344

	-- Verification Registers (Counters)
	SIGNAL r_mcycle : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- xB00
	SIGNAL r_minstret : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0'); -- xB02

BEGIN

	p_csr_select : PROCESS (i_csr_addr, r_misa, r_mvendorid, r_mstatus, r_mtvec, r_mepc, r_mcause, r_mie, r_mip, r_mcycle, r_minstret)
	BEGIN
		CASE i_csr_addr IS
			WHEN x"301" => s_selected_reg_val <= r_misa;
			WHEN x"F11" => s_selected_reg_val <= r_mvendorid;
			WHEN x"300" => s_selected_reg_val <= r_mstatus;
			WHEN x"305" => s_selected_reg_val <= r_mtvec;
			WHEN x"341" => s_selected_reg_val <= r_mepc;
			WHEN x"342" => s_selected_reg_val <= r_mcause;
			WHEN x"304" => s_selected_reg_val <= r_mie;
			WHEN x"344" => s_selected_reg_val <= r_mip;
			WHEN x"B00" => s_selected_reg_val <= r_mcycle;
			WHEN x"B02" => s_selected_reg_val <= r_minstret;
			WHEN OTHERS => s_selected_reg_val <= (OTHERS => '0');
		END CASE;
	END PROCESS p_csr_select;
	p_csr_atomic_logic : PROCESS (s_selected_reg_val, i_csr_data, i_csr_op)
	BEGIN
		CASE i_csr_op IS
			WHEN CSR_RW => -- CSRRW (Write): New value = Input Data
				s_new_csr_value <= i_csr_data;
			WHEN CSR_RS => -- CSRRS (Set/OR): New value = Old OR Input
				s_new_csr_value <= s_selected_reg_val OR i_csr_data;
			WHEN CSR_RC => -- CSRRC (Clear/AND NOT): New value = Old AND (NOT Input)
				s_new_csr_value <= s_selected_reg_val AND (NOT i_csr_data);
			WHEN OTHERS =>
				s_new_csr_value <= s_selected_reg_val;
		END CASE;
	END PROCESS p_csr_atomic_logic;
	p_csr_registers : PROCESS (i_clk, i_rst)
	BEGIN
		IF i_rst = '1' THEN
			r_misa <= x"40000100";
			r_mstatus <= (OTHERS => '0');
			r_mvendorid <= (OTHERS => '0');
			r_mtvec <= (OTHERS => '0');
			r_mepc <= (OTHERS => '0');
			r_mcause <= (OTHERS => '0');
			r_mie <= (OTHERS => '0');
			r_mip <= (OTHERS => '0');
			r_mcycle <= (OTHERS => '0');
			r_minstret <= (OTHERS => '0');

		ELSIF rising_edge(i_clk) THEN
			IF i_write_en = '1' THEN
				CASE i_csr_addr IS
					WHEN x"301" => NULL;
					WHEN x"F11" => NULL;
					WHEN x"300" => r_mstatus <= s_new_csr_value;
					WHEN x"305" => r_mtvec <= s_new_csr_value;
					WHEN x"341" => r_mepc <= s_new_csr_value;
					WHEN x"342" => r_mcause <= s_new_csr_value;
					WHEN x"304" => r_mie <= s_new_csr_value;
					WHEN x"344" => r_mip <= s_new_csr_value;
					WHEN OTHERS => NULL;
				END CASE;
			END IF;

			IF i_write_en = '1' AND i_csr_addr = x"B00" THEN
				r_mcycle <= s_new_csr_value;
			ELSE
				r_mcycle <= STD_LOGIC_VECTOR(unsigned(r_mcycle) + 1);
			END IF;
                        
                        -- Can be Improved
			IF i_write_en = '1' AND i_csr_addr = x"B02" THEN
				r_minstret <= s_new_csr_value;
			ELSE
				r_minstret <= STD_LOGIC_VECTOR(unsigned(r_minstret) + 1);
			END IF;
		END IF;
	END PROCESS p_csr_registers;
        
	o_read_data <= s_selected_reg_val;

END ARCHITECTURE behavioral;

