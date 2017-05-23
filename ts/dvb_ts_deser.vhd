-- $Id$

-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dvb_ts_deser is
	port (
		a_rst		: in std_logic;
		-- serial input port
		ts_clk		: in std_logic;
		ts_strt		: in std_logic;
		ts_dval		: in std_logic;
		ts_data		: in std_logic;
		-- parallel output port
		strt		: out std_logic;	
		data		: out std_logic_vector(7 downto 0);
		dval		: out std_logic
	);

end entity;

architecture rtl of dvb_ts_deser is

	signal ts_rst_meta	: std_logic;
	signal ts_rst_n		: std_logic;

	signal strt_0		: std_logic;
	signal dval_0		: std_logic;
	signal data_0		: std_logic;

	signal strt_latch	: std_logic;
	signal strt_latch_d	: std_logic;
	signal dval_latch	: std_logic;
	signal data_latch	: std_logic;

	signal bitcnt		: unsigned(2 downto 0);
	signal shifted		: std_logic;
	signal started		: std_logic;
	signal shiftreg		: std_logic_vector(data'range);

begin

	process (a_rst, ts_rst_n, ts_clk)
	begin
		if rising_edge(ts_clk) then
			ts_rst_meta <= '1';
			ts_rst_n <= ts_rst_meta;
			--
			strt_0 <= ts_strt;
			dval_0 <= ts_dval;
			data_0 <= ts_data;
			strt_latch <= strt_0;
			dval_latch <= dval_0;
			data_latch <= data_0;
			--
			if dval_latch then
				strt_latch_d <= strt_latch;
				if strt_latch and not strt_latch_d then
					bitcnt <= (others => '0');
				else
					bitcnt <= bitcnt + 1;
				end if;
				shiftreg <= shiftreg(shiftreg'left - 1 downto shiftreg'right) & data_latch;
			end if;
			shifted <= dval_latch;
			if dval_latch and strt_latch and not strt_latch_d then
				started <= '1';
			elsif bitcnt = 7 then
				started <= '0';
			end if;
			if bitcnt = 7 and shifted = '1' then
				strt <= started;
				data <= shiftreg;
			end if;
			if bitcnt = 7 then
				dval <= shifted;
			else
				dval <= '0';
			end if;
		end if;
		if a_rst then
			ts_rst_meta <= '0';
			ts_rst_n <= '0';
		end if;
		if not ts_rst_n then
			strt_0 <= '0';
			dval_0 <= '0';
			data_0 <= '0';
			--
			strt_latch <= '0';
			strt_latch_d <= '0';
			dval_latch <= '0';
			data_latch <= '0';
			--
			bitcnt <= (others => '0');
			shiftreg <= (others => '0');
			started <= '0';
			shifted <= '0';
			--
			strt <= '0';
			dval <= '0';
			data <= (others => '0');
		end if;
	end process;

end;
