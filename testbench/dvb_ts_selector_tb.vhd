-- $Id$

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dvb_ts_selector_tb is
end;

architecture sym of dvb_ts_selector_tb is

	signal rst		: std_logic := '1';

	signal clk		: std_logic := '0';

	signal debug_insel	: std_logic;
	signal strt            : std_logic;
	signal dval            : std_logic;
	signal data            : std_logic_vector(7 downto 0);

	signal src_clk		: std_logic := '0';
	signal src_dsop         : std_logic := '0';
	signal src_data         : std_logic := '0';
	signal src_dval         : std_logic := '0';

	signal dvb_clk		: std_logic := '0';
	signal dvb_dsop         : std_logic := '0';
	signal dvb_data         : std_logic := '0';
	signal dvb_dval         : std_logic := '0';

	signal insel           : std_logic_vector(1 downto 0) := "10";

begin

	DSEL_0 : entity work.dvb_ts_selector
		port map (
			rst	=> rst,
			clk		=> clk,
			insel	=> insel,
			strt	=> strt,
			debug_insel	=> debug_insel,
			dval	=> dval,
			data	=> data,

			atsc_clock	=> src_clk,
			atsc_start	=> src_dsop,
			atsc_valid	=> src_dval,
			atsc_data	=> src_data,

			dvb_clock	=> dvb_clk,
			dvb_start	=> dvb_dsop,
			dvb_valid	=> dvb_dval,
			dvb_data	=> dvb_data,

			dtmb_clock	=> dvb_clk,
			dtmb_start	=> dvb_dsop,
			dtmb_valid	=> dvb_dval,
			dtmb_data	=> dvb_data,

			swts_clock	=> dvb_clk,
			swts_start	=> dvb_dsop,
			swts_valid	=> dvb_dval,
			swts_data	=> (others => '0')
		);

	process
	begin
		wait for 10 ns;
		rst <= '0';
		--
		wait;
	end process;

	process
	begin
		src_clk <= not src_clk;
		wait for 4.63 ns; -- 108Mhz
	end process;

	process
	begin
		clk <= not clk;
		wait for 10 ns;
	end process;

	process
		variable octet : std_logic_vector(7 downto 0);
	begin
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		--
		octet := X"47";
		for i in 7 downto 0 loop
			src_dsop <= '1';
			src_data <= octet(i);
			src_dval <= '1';
			wait until falling_edge(src_clk);
			src_dval <= '0';
			wait until falling_edge(src_clk);
			wait until falling_edge(src_clk);
		end loop;
		--
		octet := X"55";
		for i in 7 downto 0 loop
			src_dsop <= '0';
			src_data <= octet(i);
			src_dval <= '1';
			wait until falling_edge(src_clk);
			src_dval <= '0';
			wait until falling_edge(src_clk);
			wait until falling_edge(src_clk);
		end loop;
		--
		octet := X"AA";
		for i in 7 downto 0 loop
			src_dsop <= '0';
			src_data <= octet(i);
			src_dval <= '1';
			wait until falling_edge(src_clk);
		end loop;
		--
		src_dval <= '0';
		src_dsop <= '1';
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		wait until falling_edge(src_clk);
		octet := X"47";
		for i in 7 downto 0 loop
			if i = 7 then
				src_dsop <= '1';
			else 
				src_dsop <= '0';
			end if;
			src_data <= octet(i);
			src_dval <= '1';
			wait until falling_edge(src_clk);
		end loop;
		--
		src_dval <= '0';
		wait until falling_edge(src_clk);
		wait;
	end process;

end;
