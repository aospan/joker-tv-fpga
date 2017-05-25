-- $Id$

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dvb_ts_deser_tb is
end;

architecture sym of dvb_ts_deser_tb is

	signal rst		: std_logic := '1';

	signal src_clk		: std_logic := '0';
	signal src_dsop		: std_logic := '0';
	signal src_data		: std_logic := '0';
	signal src_dval		: std_logic := '0';

	signal dvb_dsop	: std_logic;
	signal dvb_data	: std_logic_vector(7 downto 0);
	signal dvb_dval	: std_logic;

begin

	DESER_0 : entity work.dvb_ts_deser
		port map (
			a_rst	=> rst,
			-- serial input port
			ts_clk	=> src_clk,
			ts_strt => src_dsop,
			ts_dval => src_dval,
			ts_data => src_data,
			-- parallel output port
			strt	=> dvb_dsop,
			data	=> dvb_data,
			dval	=> dvb_dval
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
		wait for 4.63 ns;
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
