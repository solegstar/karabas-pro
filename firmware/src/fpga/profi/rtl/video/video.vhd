-------------------------------------------------------------------------------
-- VIDEO Controller
-------------------------------------------------------------------------------

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity video is
	generic (
			enable_turbo 		 : boolean := true
	);
	port (
		CLK2X 	: in std_logic; -- 28 MHz
		CLK		: in std_logic; -- 14 MHz
		ENA		: in std_logic; -- 7 MHz 
		RESET 	: in std_logic := '0';

		BORDER	: in std_logic_vector(3 downto 0);	-- bordr color (port #xxFE)
		DI			: in std_logic_vector(7 downto 0);	-- video data from memory
		TURBO 	: in std_logic := '0'; -- 1 = turbo mode, 0 = normal mode
		INTA		: in std_logic := '0'; -- int request for turbo mode
		INT		: out std_logic; -- int output
		ATTR_O	: out std_logic_vector(7 downto 0); -- attribute register output
		A			: out std_logic_vector(13 downto 0); -- video address

		VIDEO_R	: out std_logic_vector(2 downto 0);
		VIDEO_G	: out std_logic_vector(2 downto 0);
		VIDEO_B	: out std_logic_vector(2 downto 0);
		
		HSYNC		: buffer std_logic;
		VSYNC		: buffer std_logic;
		CSYNC		: out std_logic;
		
		DS80		: in std_logic; -- 1 = Profi CP/M mode. 0 = standard mode
		PALETTE_EN: in std_logic := '1';
		CS7E 		: in std_logic := '0';
		BUS_A 	: in std_logic_vector(15 downto 8);
		BUS_D 	: in std_logic_vector(7 downto 0);
		BUS_WR_N : in std_logic;
		GX0 		: out std_logic;
		
		HCNT : out std_logic_vector(9 downto 0);
		VCNT : out std_logic_vector(8 downto 0);
		
		VBUS_MODE : in std_logic := '0'; -- 1 = video bus, 2 = cpu bus
		VID_RD : in std_logic -- 1 = read attribute, 0 = read pixel data
	);
end entity;

architecture rtl of video is

	signal rgb 	 		: std_logic_vector(2 downto 0);
	signal i 			: std_logic;
	signal o_rgb 		: std_logic_vector(8 downto 0);
	
	type t_palette is array (0 to 15) of std_logic_vector(8 downto 0);
	signal palette		: t_palette := (
		0 => "000000000", 1 => "000000100", 2 =>  "000100000", 3 =>  "000100100", 4 =>  "100000000", 5 =>  "100000100", 6 =>  "100100000", 7 =>  "100100100",
		8 => "000000000", 9 => "000000110", 10 => "000110000", 11 => "000110110", 12 => "110000000", 13 => "110000110", 14 => "110110000", 15 => "110110110"
	);
	signal palette_a 	: std_logic_vector(3 downto 0);
	signal palette_wr_a 	: std_logic_vector(3 downto 0);
	signal palette_wr_data 	: std_logic_vector(7 downto 0);
	signal palette_wr : std_logic := '0';
	signal palette_need_wr : std_logic := '0';
	signal palette_grb: std_logic_vector(8 downto 0);
	signal palette_grb_reg: std_logic_vector(8 downto 0);
	signal palette_prev : std_logic_vector(15 downto 8);
	
	-- profi videocontroller signals
	signal vid_a_profi : std_logic_vector(13 downto 0);
	signal int_profi : std_logic;
	signal rgb_profi : std_logic_vector(2 downto 0);
	signal i_profi : std_logic;
	signal hsync_profi : std_logic;
	signal vsync_profi : std_logic;
	signal blank_profi : std_logic;
	
	signal hcnt_profi : std_logic_vector(9 downto 0);
	signal vcnt_profi : std_logic_vector(8 downto 0);

	-- spectrum videocontroller signals
	signal vid_a_spec : std_logic_vector(13 downto 0);
	signal int_spec : std_logic;
	signal rgb_spec : std_logic_vector(2 downto 0);
	signal i_spec : std_logic;
	signal hsync_spec : std_logic;
	signal vsync_spec : std_logic;

	signal hcnt_spec : std_logic_vector(9 downto 0);
	signal vcnt_spec : std_logic_vector(8 downto 0);

begin

	U_PENT: entity work.pentagon_video 
--	generic map (
--		enable_turbo => enable_turbo
--	)
	port map (
		CLK => CLK, -- 14
--		CLK2x => CLK2x, -- 28
		CLK2x => CLK, -- 28
		ENA => ENA, -- 7
		BORDER => BORDER(2 downto 0),
		DI => DI,
--		TURBO => TURBO,
		INTA => INTA,
		INT => int_spec,
		ATTR_O => ATTR_O, 
		A => vid_a_spec,
		MODE60 => palette_en,

		RGB => rgb_spec,
		I 	 => i_spec,
		
		HSYNC => hsync_spec,
		VSYNC => vsync_spec,

		HCNT => hcnt_spec,
		VCNT => vcnt_spec,
		
		VBUS_MODE => VBUS_MODE,
		VID_RD => VID_RD
	);

	U_PROFI: entity work.profi_video 
	port map (
		CLK => CLK, -- 14
		CLK2x => CLK2x, -- 28
		ENA => ENA, -- 7
		BORDER => BORDER,
		DI => DI,
		INTA => INTA,
		INT => int_profi,
		A => vid_a_profi,
		DS80 => DS80,
		MODE60 => palette_en,

		RGB => rgb_profi,
		I 	 => i_profi,
		BLANK => blank_profi,
		
		HSYNC => hsync_profi,
		VSYNC => vsync_profi,

		HCNT => hcnt_profi,
		VCNT => vcnt_profi,

		VBUS_MODE => VBUS_MODE,
		VID_RD => VID_RD
	);

	A <= vid_a_profi when ds80 = '1' else vid_a_spec;

	INT <= int_profi when ds80 = '1' else int_spec;

	rgb <= rgb_profi when ds80 = '1' else rgb_spec;
	i <= i_profi when ds80 = '1' else i_spec;

	HSYNC <= hsync_profi when ds80 = '1' else hsync_spec;
	VSYNC <= vsync_profi when ds80 = '1' else vsync_spec;	
	
	HCNT <= hcnt_profi when ds80 = '1' else hcnt_spec;
	VCNT <= vcnt_profi when ds80 = '1' else vcnt_spec;
	
	-- Палитра profi:

	-- 1) палитра - это память на 16 ячеек. каждая ячейка - 8-битное значение цвета в виде GGGRRRBB
	-- 2) в палитру пишется инвертированное значение старшей половины адреса ША по адресу, заданному в порту #FE (тоже инвертированное значение)
	-- 3) строб записи по схеме формируется при обращении к порту палитры #7E в режиме DS80
	-- 4) при чтении адресом выступает код цвета от видеоконтроллера - YGRB
			
	-- запись палитры
	process(CLK2x, reset, palette_wr, palette_a, palette_wr_data, palette)
	begin
		if reset = '1' then 
			-- set default palette on reset
			palette <= (
				0 => "000000000", 1 => "000000100", 2 =>  "000100000", 3 =>  "000100100", 4 =>  "100000000", 5 =>  "100000100", 6 =>  "100100000", 7 =>  "100100100",
				8 => "000000000", 9 => "000000110", 10 => "000110000", 11 => "000110110", 12 => "110000000", 13 => "110000110", 14 => "110110000", 15 => "110110110"
			);
		elsif rising_edge(CLK2x) then 
			if palette_wr = '1' then
--				-- это костыль для проверки теории, что первый цвет пишется криво
--				if (BORDER(3 downto 0) = X"F") then -- первый цвет в палитре (неяркий черный)
--					palette(to_integer(unsigned(BORDER(3 downto 0) xor X"F"))) <= (others => '0');
--				else 
					palette(to_integer(unsigned(BORDER(3 downto 0) xor X"F"))) <= (not BUS_A) & '0';
--				end if;
			end if;
		end if;
	end process;
	
	palette_a <= i & rgb(1) & rgb(2) & rgb(0);
   palette_wr <= '1' when CS7E = '1' and BUS_WR_N = '0' and ds80 = '1' and reset = '0' else '0';

	-- чтение из палитры
	palette_grb <= palette(to_integer(unsigned(palette_a)));
	
	-- возвращаем наверх (top level) значение младшего разряда зеленого компонента палитры, это служит для отпределения наличия палитры в системе
	GX0 <= palette_grb(6);
	
	-- применяем blank для профи, ибо в видеоконтроллере он после палитры
	process(CLK2x, CLK, blank_profi, palette_grb) 
	begin 
		if (blank_profi = '1' and ds80='1') then
			palette_grb_reg <= (others => '0');
		else
			palette_grb_reg <= palette_grb;
		end if;
	end process;

	-- преобразование стандартного цвета RGBI в RGB 3:3:3 
--	U9BIT: entity work.rgbi_9bit
--	port map(
--		I_RED		=> rgb(2),
--		I_GREEN	=> rgb(1),
--		I_BLUE	=> rgb(0),
--		I_BRIGHT => i,
--		O_RGB		=> o_rgb
--	);
	
--	-- переключение видео вывода с палитрой или без по сигналу palette_en
--	process(ds80, palette_en, palette_grb_reg, o_rgb)
--	begin
--		if (ds80 = '1' and palette_en = '1') then 
			VIDEO_R <= palette_grb_reg(5 downto 3);
			VIDEO_G <= palette_grb_reg(8 downto 6);
			VIDEO_B <= palette_grb_reg(2 downto 0);
--		else
--			VIDEO_R <= o_rgb(8 downto 6);
--			VIDEO_G <= o_rgb(5 downto 3);
--			VIDEO_B <= o_rgb(2 downto 0);
--		end if;
--	end process;
	
	CSYNC <= not (vsync xor hsync);

end architecture;