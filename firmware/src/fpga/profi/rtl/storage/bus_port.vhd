library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

entity bus_port is
	port (

	-- global clocks
	CLK : in std_logic;
	CLK2: in std_logic;
	CLK_BUS : in std_logic;
	CLK_CPU : in std_logic;
	RESET : in std_logic;
	 
	-- physical interface with CPLD
	SD : inout std_logic_vector(15 downto 0) := "ZZZZZZZZZZZZZZZZ";
	SA : out std_logic_vector(1 downto 0);
--	SDIR : out std_logic;
	CPLD_CLK : out std_logic;
	CPLD_CLK2 : out std_logic;
	NRESET : out std_logic;

	-- zx bus signals to rx/tx from/to the CPLD controller
	BUS_A : in std_logic_vector(15 downto 0);
	BUS_DI : in std_logic_vector(7 downto 0);
	BUS_DO : out std_logic_vector(7 downto 0);
	OE_N : out std_logic := '1';
	BUS_RD_N : in std_logic;
	BUS_WR_N : in std_logic;
	BUS_MREQ_N : in std_logic;
	BUS_IORQ_N : in std_logic;
	BUS_M1_N : in std_logic;
	BUS_CPM : in std_logic;
	BUS_DOS : in std_logic;
	BUS_ROM14 : in std_logic	
	
	);
    end bus_port;
architecture RTL of bus_port is

signal cnt: std_logic_vector(1 downto 0) := "00";
signal bus_a_reg : std_logic_vector(15 downto 0);
signal bus_d_reg : std_logic_vector(7 downto 0);
signal bus_s_reg : std_logic_vector(7 downto 0);

begin
	
	CPLD_CLK <= CLK;
	CPLD_CLK2 <= CLK2;
	NRESET <= not reset;
	--SDIR <= CLK_BUS;
	SA <= cnt;	
	BUS_DO <= SD(15 downto 8);

	process (CLK, cnt, CLK_BUS)
	begin 
		if (rising_edge(CLK)) then 
			if (clk_cpu = '0') then --11
				bus_a_reg <= bus_a;
				bus_d_reg <= bus_di;
				bus_s_reg <= BUS_RD_N & BUS_WR_N & BUS_MREQ_N & BUS_IORQ_N & BUS_M1_N & BUS_CPM & BUS_DOS & BUS_ROM14;
			end if;
			cnt <= cnt + 1;
		end if;
	end process;
	
	UMUX: entity work.bus_mux
	port map(
		data0x => bus_a_reg(15 downto 8),
		data1x => bus_a_reg(7 downto 0),
		data2x => bus_d_reg,
		data3x => bus_s_reg,
		sel => cnt,
		result => SD(7 downto 0)
	);

end RTL;

