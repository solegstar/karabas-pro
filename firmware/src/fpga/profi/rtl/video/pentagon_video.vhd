-------------------------------------------------------------------------------
-- VIDEO Spectrum mode
-------------------------------------------------------------------------------

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity pentagon_video is
	generic (
		enable_turbo	: boolean := true
	);
	port (
		CLK2X		: in std_logic; -- 28
		CLK		: in std_logic; -- 14					
		ENA		: in std_logic; -- 7
		INTA		: in std_logic;
		TURBO		: in std_logic;
		TV_VGA 	: in std_logic := '0'; -- 1 = TV mode, 0 = VGA mode
		INT		: out std_logic;
		BORDER	: in std_logic_vector(2 downto 0);	
		A			: out std_logic_vector(13 downto 0);
		DI			: in std_logic_vector(7 downto 0);
		RGB		: out std_logic_vector(2 downto 0);	-- RGB
		I 			: out std_logic;
		pFF_CS	: out std_logic; -- port FF select
		ATTR_O	: out std_logic_vector(7 downto 0);
		BLANK 	: out std_logic;
		HSYNC		: out std_logic;
		VSYNC		: out std_logic;		
		HCNT 		: out std_logic_vector(9 downto 0);
		VCNT 		: out std_logic_vector(8 downto 0);	
		MODE60	: in std_logic;
		VBUS_MODE : in std_logic := '0';
		VID_RD : in std_logic
	);
end entity;

architecture rtl of pentagon_video is
-- Spectrum screen mode
	constant spec_scr_h			: natural := 256;
	constant spec_brd_right		: natural :=  64;	-- 32 для выравнивания из-за задержки на чтение vid_reg и attr_reg задано на 8 точек больше
	constant spec_blk_front		: natural :=  16; -- 48
	constant spec_sync_h			: natural :=  16; -- 64
	constant spec_blk_back		: natural :=  32; -- 80
	constant spec_brd_left		: natural :=  64;	-- 32 для выравнивания из-за задержки на чтение vid_reg и attr_reg задано на 8 точек меньше

	constant spec_scr_v			: natural := 192;
	constant spec_brd_bot		: natural :=  40;--16
	constant spec_blk_down		: natural :=  8;--8
	constant spec_sync_v			: natural :=  16;--16
	constant spec_blk_up			: natural :=  8;--16
	constant spec_brd_top		: natural :=  56;--16
	
	constant spec_brd_bot_60	: natural :=  16;--16
	constant spec_blk_down_60	: natural :=  12;--8
	constant spec_sync_v_60		: natural :=  12;--16
	constant spec_blk_up_60		: natural :=  8;--16
	constant spec_brd_top_60	: natural :=  16;--16

	constant spec_h_blk_on		: natural := (spec_scr_h + spec_brd_right) - 1;
	constant spec_h_sync_on		: natural := (spec_scr_h + spec_brd_right + spec_blk_front) - 1;
	constant spec_h_sync_off	: natural := (spec_scr_h + spec_brd_right + spec_blk_front + spec_sync_h);
	constant spec_h_blk_off		: natural := (spec_scr_h + spec_brd_right + spec_blk_front + spec_sync_h + spec_blk_back);
	constant spec_h_end			: natural := 447;

	constant spec_v_blk_on		: natural := (spec_scr_v + spec_brd_bot) - 1;
	constant spec_v_sync_on		: natural := (spec_scr_v + spec_brd_bot + spec_blk_down) - 1;
	constant spec_v_sync_off	: natural := (spec_scr_v + spec_brd_bot + spec_blk_down + spec_sync_v);
	constant spec_v_blk_off		: natural := (spec_scr_v + spec_brd_bot + spec_blk_down + spec_sync_v + spec_blk_up);
	constant spec_v_end			: natural := 319;	-- 319 = Pentagon; -- 311 = Spectrum; 50HZ
	constant spec_v_blk_on_60	: natural := (spec_scr_v + spec_brd_bot_60) - 1;
	constant spec_v_sync_on_60	: natural := (spec_scr_v + spec_brd_bot_60 + spec_blk_down_60) - 1;
	constant spec_v_sync_off_60: natural := (spec_scr_v + spec_brd_bot_60 + spec_blk_down_60 + spec_sync_v_60);
	constant spec_v_blk_off_60	: natural := (spec_scr_v + spec_brd_bot_60 + spec_blk_down_60 + spec_sync_v_60 + spec_blk_up_60);
	constant spec_v_end_60		: natural := 263;	-- 60Hz

	constant spec_h_int_on		: natural := 318; --pspec_sync_h+8;
	constant spec_v_int_on		: natural := 239; --pspec_v_blk_off - 1;
	constant spec_h_int_off		: natural := 24;
	constant spec_v_int_off		: natural := 239;

-- INT  Y303,X752  - Y304,X128

---------------------------------------------------------------------------------------	

	signal h_cnt			: unsigned(8 downto 0) := (others => '0');
	signal v_cnt			: unsigned(9 downto 0) := (others => '0');
	signal paper			: std_logic;
	signal paper1			: std_logic;
	signal flash			: std_logic_vector(4 downto 0) := "00000";
	signal vid_reg			: std_logic_vector(7 downto 0);
	signal pixel_reg		: std_logic_vector(7 downto 0);
	signal at_reg			: std_logic_vector(7 downto 0);	
	signal attr_reg		: std_logic_vector(7 downto 0);
	signal h_sync			: std_logic;
	signal v_sync			: std_logic;
	signal int_sig			: std_logic;
	signal blank_sig		: std_logic;
	signal blank_h			: std_logic;
	signal blank_v			: std_logic;
	signal rgbi				: std_logic_vector(3 downto 0);
	signal infp 			: std_logic;
	signal selector 		: std_logic_vector(2 downto 0);
	signal blank1 			: std_logic;

begin

-- sync, counters
process (CLK2X, CLK)
begin
	if (CLK2X'event and CLK2X = '1') then
			if (CLK = '1') then		-- 14MHz
				if TV_VGA = '1' then -- TV
					if ENA = '1' then
						if (h_cnt = spec_h_end) then
							h_cnt <= (others => '0');
						else
							h_cnt <= h_cnt + 1;
						end if;
			
						if (h_cnt = spec_h_sync_on) then
							if (v_cnt = spec_v_end and mode60 = '0') or (v_cnt = spec_v_end_60 and mode60 = '1') then
								v_cnt <= (others => '0');
							else
								v_cnt <= v_cnt + 1;
							end if;
						end if;
				
						if (v_cnt = spec_v_sync_on and mode60 = '0') or (v_cnt = spec_v_sync_on_60 and mode60 = '1') then
							v_sync <= '0';
						elsif (v_cnt = spec_v_sync_off and mode60 = '0') or (v_cnt = spec_v_sync_off_60 and mode60 = '1') then
							v_sync <= '1';
						end if;

						if (h_cnt = spec_h_sync_on) then
							h_sync <= '0';
						elsif (h_cnt = spec_h_sync_off) then
							h_sync <= '1';
						end if;

						--Int
						if (h_cnt = spec_h_int_on  and v_cnt = spec_v_int_on) then
							int_sig <= '0';
						elsif (h_cnt = 383 and v_cnt = 240) then
							int_sig <= '1';
						end if;
					end if;
					
				else -- VGA
				
					if (h_cnt = spec_h_end) then
						h_cnt <= (others => '0');
					else
						h_cnt <= h_cnt + 1;
					end if;
			
					if (h_cnt = spec_h_sync_on) then
						if (v_cnt(9 downto 1) = spec_v_end and mode60 = '0') or (v_cnt(9 downto 1) = spec_v_end_60 and mode60 = '1') then
							v_cnt <= (others => '0');
						else
							v_cnt <= v_cnt + 1;
						end if;
					end if;
				
					if (v_cnt(9 downto 1) = spec_v_sync_on and mode60 = '0') or (v_cnt(9 downto 1) = spec_v_sync_on_60 and mode60 = '1') then
						v_sync <= '0';
					elsif (v_cnt(9 downto 1) = spec_v_sync_off and mode60 = '0') or (v_cnt(9 downto 1) = spec_v_sync_off_60 and mode60 = '1') then
						v_sync <= '1';
					end if;

					if (h_cnt = spec_h_sync_on) then
						h_sync <= '0';
					elsif (h_cnt = spec_h_sync_off) then
						h_sync <= '1';
					end if;

				--Int
					if (h_cnt = spec_h_int_on  and v_cnt(9 downto 1) = spec_v_int_on and v_cnt(0) = '0') then
						int_sig <= '0';
					elsif (h_cnt = spec_h_int_off and v_cnt(9 downto 1) = spec_v_int_off and v_cnt(0) = '1') then
						int_sig <= '1';
					end if;
				end if;
			end if;
	end if;
end process;

-- memory read
process(CLK2X, CLK, ENA, h_cnt, VBUS_MODE, VID_RD)
begin
	if CLK2X'event and CLK2X='1' then 
		if (CLK = '0' and h_cnt(2 downto 0) < 7) then -- 14 mhz falling edge
		if (h_cnt(2 downto 0) < 7) then -- 14 mhz falling edge
			if (VBUS_MODE = '1') then
				if VID_RD = '0' then 
					vid_reg <= DI;
				else 
					at_reg <= DI;
				end if;
			end if;				
		end if;
		end if;
	end if;
end process;

-- pixel / attr registers
process( CLK2X, CLK, h_cnt )
	begin
		if CLK2X'event and CLK2X = '1' then
			if CLK = '1' then
				if h_cnt(2 downto 0) = 7 then
					pixel_reg <= vid_reg;
					attr_reg <= at_reg;
					paper1 <= paper;
					blank1 <= blank_sig;
				end if;
			end if;
		end if;
	end process;

flash <= (flash + 1) when (v_cnt(9)'event and v_cnt(9)='0');

process (CLK2X, CLK, blank_sig, paper1, pixel_reg, h_cnt, attr_reg, BORDER, flash)
begin 
	if CLK2X'event and CLK2X='1' then 
		if CLK = '1' then
			if (blank1 = '1') then 
				rgbi <= "0000";
			elsif paper1 = '1' and (pixel_reg(7 - to_integer(h_cnt(2 downto 0))) xor (flash(4) and attr_reg(7))) = '0' then 
				rgbi <= attr_reg(4) & attr_reg(5) & attr_reg(3) & attr_reg(6);
			elsif paper1 = '1' and (pixel_reg(7 - to_integer(h_cnt(2 downto 0))) xor (flash(4) and attr_reg(7))) = '1' then 
				rgbi <= attr_reg(1) & attr_reg(2) & attr_reg(0) & attr_reg(6);
			else
				rgbi <= BORDER(1) & BORDER(2) & BORDER(0) & '0';
			end if;
		end if;
	end if;
end process;

process (TV_VGA, VBUS_MODE, VID_RD, v_cnt, h_cnt)
begin
	if TV_VGA = '0' then
		if VBUS_MODE = '1' and VID_RD = '0' then
			A <= std_logic_vector( '0' & v_cnt(8 downto 7)) & std_logic_vector(v_cnt(3 downto 1)) & std_logic_vector(v_cnt(6 downto 4)) & std_logic_vector(h_cnt(7 downto 3)); -- data address
		else
			A <= std_logic_vector( '0' & "110" & v_cnt(8 downto 4) & h_cnt(7 downto 3));	-- standard attribute address
		end if;
	else
		if VBUS_MODE = '1' and VID_RD = '0' then
			A <= std_logic_vector( '0' & v_cnt(7 downto 6)) & std_logic_vector(v_cnt(2 downto 0)) & std_logic_vector(v_cnt(5 downto 3)) & std_logic_vector(h_cnt(7 downto 3)); -- data address
		else
			A <= std_logic_vector( '0' & "110" & v_cnt(7 downto 3) & h_cnt(7 downto 3));	-- standard attribute address
		end if;	
	end if;	
end process;

blank_sig	<= '1' when (((h_cnt > spec_h_blk_on and h_cnt < spec_h_blk_off) or
								((v_cnt(9 downto 1) > spec_v_blk_on and v_cnt(9 downto 1) < spec_v_blk_off and mode60 = '0') or
								(v_cnt(9 downto 1) > spec_v_blk_on_60 and v_cnt(9 downto 1) < spec_v_blk_off_60 and mode60 = '1'))) and TV_VGA = '0') or	-- VGA Blank

								(((h_cnt > spec_h_blk_on and h_cnt < spec_h_blk_off) or
								((v_cnt > spec_v_blk_on and v_cnt < spec_v_blk_off and mode60 = '0') or
								(v_cnt > spec_v_blk_on_60 and v_cnt < spec_v_blk_off_60 and mode60 = '1'))) and TV_VGA = '1') else '0';	-- TV Blank

paper			<= '1' when ((h_cnt < spec_scr_h and v_cnt(9 downto 1) < spec_scr_v) and TV_VGA = '0') or	-- VGA Paper
								((h_cnt < spec_scr_h and v_cnt < spec_scr_v) and TV_VGA = '1') else '0';		-- TV Paper

pFF_CS		<= paper;
ATTR_O		<= attr_reg;
INT			<= int_sig;
RGB 			<= rgbi(3 downto 1);
I 				<= rgbi(0);
HSYNC 		<= h_sync when TV_VGA = '0' else (h_sync xor (not v_sync));
VSYNC 		<= v_sync;
HCNT <= '0' & std_logic_vector(h_cnt);
VCNT <= std_logic_vector(v_cnt(9 downto 1)) when TV_VGA = '0' else std_logic_vector(v_cnt(8 downto 0));
BLANK <= blank1;

end architecture;