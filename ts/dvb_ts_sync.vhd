-- $Id$

-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dvb_ts_sync is
	port (
		-- transport stream input port
		ts_clk		: in std_logic;
		ts_strt		: in std_logic;
		ts_dval		: in std_logic;
		ts_data		: in std_logic_vector(7 downto 0);
		-- data output port (system clock domain)
		rst			: in std_logic;
		clk			: in std_logic;
		--
		strt		: out std_logic;	
		data		: out std_logic_vector(7 downto 0);
		dval		: out std_logic
	);

end entity;

architecture rtl of dvb_ts_sync is

	signal ts_rst_meta	: std_logic;
	signal ts_rst_n		: std_logic;

	signal src_latch	: std_logic_vector(ts_data'left + 2 downto 0);
	signal src_hold_0	: std_logic_vector(ts_data'left + 1 downto 0);
	signal src_hold_1	: std_logic_vector(ts_data'left + 1 downto 0);
	signal src_hold_2	: std_logic_vector(ts_data'left + 1 downto 0);
	signal src_hold_3	: std_logic_vector(ts_data'left + 1 downto 0);
	signal src_ptr		: std_logic_vector(1 downto 0);

	signal src_ptr_meta	: std_logic_vector(1 downto 0);
	signal src_ptr_sync	: std_logic_vector(1 downto 0);
	signal dst_ptr		: std_logic_vector(1 downto 0);

begin

	process (rst, ts_rst_n, ts_clk)
	begin
		if rising_edge(ts_clk) then
			ts_rst_meta <= '1';
			ts_rst_n <= ts_rst_meta;
			--
			src_latch <= ts_dval & ts_strt & ts_data;
			if src_latch(src_latch'left) then
				src_ptr(0) <= not src_ptr(1);
				src_ptr(1) <= src_ptr(0);
				if src_ptr = "00" then
					src_hold_0 <= src_latch(src_latch'left - 1 downto 0);
				end if;
				if src_ptr = "01" then
					src_hold_1 <= src_latch(src_latch'left - 1 downto 0);
				end if;
				if src_ptr = "11" then
					src_hold_2 <= src_latch(src_latch'left - 1 downto 0);
				end if;
				if src_ptr = "10" then
					src_hold_3 <= src_latch(src_latch'left - 1 downto 0);
				end if;
			end if;
		end if;
		if rst then
			ts_rst_meta <= '0';
			ts_rst_n <= '0';
		end if;
		if not ts_rst_n then
			src_latch <= (others => '0');
			src_ptr <= (others => '0');
			src_hold_0 <= (others => '0');
			src_hold_1 <= (others => '0');
			src_hold_2 <= (others => '0');
			src_hold_3 <= (others => '0');
		end if;
	end process;

	process (rst, clk)
		variable fifo_not_empty : std_logic;
	begin
		if rising_edge(clk) then
			src_ptr_meta <= src_ptr;
			src_ptr_sync <= src_ptr_meta;
			--
			fifo_not_empty := (src_ptr_sync(1) xor dst_ptr(1)) or (src_ptr_sync(0) xor dst_ptr(0));
			if fifo_not_empty then
				dst_ptr(0) <= not dst_ptr(1);
				dst_ptr(1) <= dst_ptr(0);
				case dst_ptr is
					when "00" => 
						strt <= src_hold_0(src_hold_0'left);
						data <= src_hold_0(src_hold_0'left - 1 downto 0);
					when "01" => 
						strt <= src_hold_1(src_hold_1'left);
						data <= src_hold_1(src_hold_1'left - 1 downto 0);
					when "11" => 
						strt <= src_hold_2(src_hold_2'left);
						data <= src_hold_2(src_hold_2'left - 1 downto 0);
					when others => 
						strt <= src_hold_3(src_hold_3'left);
						data <= src_hold_3(src_hold_3'left - 1 downto 0);
				end case;
			end if;
			dval <= fifo_not_empty;
		end if;
		if rst then
			src_ptr_meta <= (others => '0');
			src_ptr_sync <= (others => '0');
			dst_ptr <= (others => '0');
			strt <= '0';
			data <= (others => '0');
			dval <= '0';
		end if;
	end process;

end;
