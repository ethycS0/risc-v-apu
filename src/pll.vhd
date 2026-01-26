LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY pll IS
	PORT (
		clk_in : IN STD_LOGIC;
		clk_out : OUT STD_LOGIC
	);
END ENTITY pll;

ARCHITECTURE structural OF pll IS
	COMPONENT rPLL
		GENERIC (
			FCLKIN : STRING := "100.0";
			DEVICE : STRING := "GW2A-18";
			IDIV_SEL : INTEGER := 0;
			FBDIV_SEL : INTEGER := 0;
			ODIV_SEL : INTEGER := 8;
			DYN_SDIV_SEL : INTEGER := 2;
			DYN_FBDIV_SEL : STRING := "false";
			DYN_ODIV_SEL : STRING := "false";
			DYN_DA_EN : STRING := "false";
			DUTYDA_SEL : STRING := "1000";
			CLKOUT_FT_DIR : STRING := "1'b1";
			CLKOUTP_FT_DIR : STRING := "1'b1";
			CLKOUT_DLY_STEP : INTEGER := 0;
			CLKOUTP_DLY_STEP : INTEGER := 0;
			CLKFB_SEL : STRING := "internal";
			CLKOUT_BYPASS : STRING := "false";
			CLKOUTP_BYPASS : STRING := "false";
			CLKOUTD_BYPASS : STRING := "false";
			CLKOUTD_SRC : STRING := "CLKOUT";
			CLKOUTD3_SRC : STRING := "CLKOUT"
		);
		PORT (
			CLKIN : IN STD_LOGIC;
			CLKOUT : OUT STD_LOGIC;
			CLKOUTP : OUT STD_LOGIC;
			CLKOUTD : OUT STD_LOGIC;
			CLKOUTD3 : OUT STD_LOGIC;
			LOCK : OUT STD_LOGIC;
			RESET : IN STD_LOGIC;
			RESET_P : IN STD_LOGIC;
			CLKFB : IN STD_LOGIC;
			FBDSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			IDSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			ODSEL : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
			PSDA : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			DUTYDA : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			FDLY : IN STD_LOGIC_VECTOR(3 DOWNTO 0)
		);
	END COMPONENT;
BEGIN
	-- Parameters for 27MHz -> 54MHz
	-- Target VCO range: 400 MHz - 1200 MHz (Actually 500-1250 for this device)
	-- FCLKIN = 27 MHz.
	-- PFD = 27 MHz / (0+1) = 27 MHz (Valid > 3MHz).
	-- VCO = 27 MHz * (1+1) * 16 / (0+1) = 864 MHz (Valid).
	-- Output = 54 MHz.

	U_rPLL : rPLL
	GENERIC MAP(
		FCLKIN => "27.0",
		IDIV_SEL => 1, -- Divide input by (1+1) = 2.
		FBDIV_SEL => 3, -- Multiply feedback by (3+1) = 4. Output = 27 * 4/2 = 54 MHz.
		ODIV_SEL => 16 -- Output Divider. VCO = 54 * 16 = 864 MHz.
	)
	PORT MAP(
		CLKIN => clk_in,
		CLKOUT => clk_out,
		-- Unused ports
		CLKOUTP => OPEN,
		CLKOUTD => OPEN,
		CLKOUTD3 => OPEN,
		LOCK => OPEN,
		RESET => '0',
		RESET_P => '0',
		CLKFB => '0', -- Internal feedback used
		FBDSEL => (OTHERS => '0'),
		IDSEL => (OTHERS => '0'),
		ODSEL => (OTHERS => '0'),
		PSDA => (OTHERS => '0'),
		DUTYDA => (OTHERS => '0'),
		FDLY => (OTHERS => '0')
	);
END ARCHITECTURE structural;

