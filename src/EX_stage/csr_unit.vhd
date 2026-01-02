LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.rv32i_pkg.ALL;

ENTITY csr_unit IS
	PORT (
		i_clk : IN STD_LOGIC;
		i_rst : IN STD_LOGIC;

		i_write_en           : IN STD_LOGIC;
		i_minstret_increment : IN STD_LOGIC;
		i_is_mret            : IN STD_LOGIC;

		i_csr_op   : IN t_CsrOpcodes;
		i_csr_addr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		i_csr_data : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		i_trap_triggered : IN STD_LOGIC;
		i_pc_at_trap     : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_cause_code     : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		i_trap_mtval     : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

		o_mtvec     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_mepc      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		o_read_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END ENTITY csr_unit;

ARCHITECTURE behavioral OF csr_unit IS
	SIGNAL s_selected_reg_val : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL s_new_csr_value : STD_LOGIC_VECTOR(31 DOWNTO 0);

	CONSTANT c_mvendorid : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	CONSTANT c_misa_val : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"40000100";

	SIGNAL r_mie_bit : STD_LOGIC := '0';
	SIGNAL r_mpie_bit : STD_LOGIC := '0';

	SIGNAL r_mtvec : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mtval : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mepc : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mcause : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mie_reg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mip_reg : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

	SIGNAL r_mcycle : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_minstret : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL r_mscratch : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');

BEGIN

	p_csr_select : PROCESS (i_csr_addr, r_mtvec, r_mepc, r_mcause, r_mtval, r_mie_reg, r_mip_reg, r_mcycle, r_minstret, r_mie_bit, r_mpie_bit, r_mscratch)
	BEGIN
		s_selected_reg_val <= (OTHERS => '0');
		CASE i_csr_addr IS
			WHEN x"F11" => s_selected_reg_val <= c_mvendorid;
			WHEN x"301" => s_selected_reg_val <= c_misa_val;

			WHEN x"300" =>
				s_selected_reg_val(31 DOWNTO 13) <= (OTHERS => '0');
				s_selected_reg_val(12 DOWNTO 11) <= "11";
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
			WHEN OTHERS => s_selected_reg_val <= (OTHERS => '0');
		END CASE;
	END PROCESS;

	PROCESS (s_selected_reg_val, i_csr_data, i_csr_op)
	BEGIN
		CASE i_csr_op IS
			WHEN CSR_RW => s_new_csr_value <= i_csr_data;
			WHEN CSR_RS => s_new_csr_value <= s_selected_reg_val OR i_csr_data;
			WHEN CSR_RC => s_new_csr_value <= s_selected_reg_val AND (NOT i_csr_data);
			WHEN OTHERS => s_new_csr_value <= s_selected_reg_val;
		END CASE;
	END PROCESS;

	PROCESS (i_clk, i_rst)
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
                ELSIF rising_edge(i_clk) THEN

			IF i_trap_triggered = '1' THEN
				r_mepc <= i_pc_at_trap;
				r_mcause <= i_cause_code;
				r_mtval <= i_trap_mtval;
				r_mpie_bit <= r_mie_bit;
				r_mie_bit <= '0';

				ELSIF i_is_mret = '1' THEN
				r_mie_bit <= r_mpie_bit;
				r_mpie_bit <= '1';

				ELSIF i_write_en = '1' THEN
				CASE i_csr_addr IS
					WHEN x"300" =>
						r_mie_bit <= s_new_csr_value(3);
						r_mpie_bit <= s_new_csr_value(7);
					WHEN x"305" => r_mtvec <= s_new_csr_value;
					WHEN x"340" => r_mscratch <= s_new_csr_value;
					WHEN x"341" => r_mepc <= s_new_csr_value;
					WHEN x"342" => r_mcause <= s_new_csr_value;
					WHEN x"343" => r_mtval <= s_new_csr_value;
					WHEN x"304" => r_mie_reg <= s_new_csr_value;
					WHEN x"B00" => r_mcycle <= s_new_csr_value;
					WHEN x"B02" => r_minstret <= s_new_csr_value;
					WHEN OTHERS => NULL;
				END CASE;
			END IF;

			IF (i_write_en = '1' AND i_csr_addr = x"B00") THEN
				NULL;
				ELSE
				r_mcycle <= STD_LOGIC_VECTOR(unsigned(r_mcycle) + 1);
			END IF;

			IF (i_write_en = '1' AND i_csr_addr = x"B02") THEN
				NULL;
				ELSIF i_minstret_increment = '1' THEN
				r_minstret <= STD_LOGIC_VECTOR(unsigned(r_minstret) + 1);
			END IF;

		END IF;
	END PROCESS;

	o_mtvec <= r_mtvec;
	o_mepc <= r_mepc;
	o_read_data <= s_selected_reg_val;

END ARCHITECTURE behavioral;

