-- $Id$

library ieee;
use ieee.std_logic_1164.all;

entity dvb_ts_selector is
	port (
		rst			: in std_logic;
		clk			: in std_logic;
		--
		insel		: in std_logic_vector(1 downto 0);
		--
		dvb_clock	: in std_logic;
		dvb_start	: in std_logic;
		dvb_valid	: in std_logic;
		dvb_data	: in std_logic;
		--
		dtmb_clock	: in std_logic;
		dtmb_start	: in std_logic;
		dtmb_valid	: in std_logic;
		dtmb_data	: in std_logic;
		--
		atsc_clock	: in std_logic;
		atsc_start	: in std_logic;
		atsc_valid	: in std_logic;
		atsc_data	: in std_logic;
		--
		swts_clock	: in std_logic;
		swts_start	: in std_logic;
		swts_valid	: in std_logic;
		swts_data	: in std_logic_vector(7 downto 0);
		--
		debug_insel		: out std_logic := '0';
		strt		: out std_logic;
		dval		: out std_logic;
		data		: out std_logic_vector(7 downto 0)
	);

end;

architecture rtl of dvb_ts_selector is

	signal deser_dvb_sop	: std_logic;
	signal deser_dvb_dval	: std_logic;
	signal deser_dvb_data	: std_logic_vector(7 downto 0);
	signal deser_dtmb_sop	: std_logic;
	signal deser_dtmb_dval	: std_logic;
	signal deser_dtmb_data	: std_logic_vector(7 downto 0);
	signal deser_atsc_sop	: std_logic;
	signal deser_atsc_dval	: std_logic;
	signal deser_atsc_data	: std_logic_vector(7 downto 0);

	signal debug_insel_int	: std_logic := '0';
	signal ts_dvb_sop		: std_logic;
	signal ts_dvb_dval		: std_logic;
	signal ts_dvb_data		: std_logic_vector(7 downto 0);
	signal ts_dtmb_sop		: std_logic;
	signal ts_dtmb_dval		: std_logic;
	signal ts_dtmb_data		: std_logic_vector(7 downto 0);
	signal ts_atsc_sop		: std_logic;
	signal ts_atsc_dval		: std_logic;
	signal ts_atsc_data		: std_logic_vector(7 downto 0);
	signal ts_swts_sop		: std_logic;
	signal ts_swts_dval		: std_logic;
	signal ts_swts_data		: std_logic_vector(7 downto 0);

begin

	DVB_DESER_0 : entity work.dvb_ts_deser
		port map (
			a_rst		=> rst,
			--
			ts_clk		=> dvb_clock,
			ts_strt		=> dvb_start,
			ts_dval		=> dvb_valid,
			ts_data		=> dvb_data,
			--
			strt		=> deser_dvb_sop,
			data		=> deser_dvb_data,
			dval		=> deser_dvb_dval
		);

	DVB_SYNC_0 : entity work.dvb_ts_sync
		port map (
			ts_clk		=> dvb_clock,
			ts_strt		=> deser_dvb_sop,
			ts_data		=> deser_dvb_data,
			ts_dval		=> deser_dvb_dval,
			--
			rst			=> rst,
			clk			=> clk,
			--
			strt		=> ts_dvb_sop,
			data		=> ts_dvb_data,
			dval		=> ts_dvb_dval
		);

	DTMB_DESER_0 : entity work.dvb_ts_deser
		port map (
			a_rst		=> rst,
			--
			ts_clk		=> dtmb_clock,
			ts_strt		=> dtmb_start,
			ts_dval		=> dtmb_valid,
			ts_data		=> dtmb_data,
			--
			strt		=> deser_dtmb_sop,
			data		=> deser_dtmb_data,
			dval		=> deser_dtmb_dval
		);

	DTMB_SYNC_0 : entity work.dvb_ts_sync
		port map (
			ts_clk		=> dtmb_clock,
			ts_strt		=> deser_dtmb_sop,
			ts_data		=> deser_dtmb_data,
			ts_dval		=> deser_dtmb_dval,
			--
			rst			=> rst,
			clk			=> clk,
			--
			strt		=> ts_dtmb_sop,
			data		=> ts_dtmb_data,
			dval		=> ts_dtmb_dval
		);

	ATSC_DESER_0 : entity work.dvb_ts_deser
		port map (
			a_rst		=> rst,
			--
			ts_clk		=> atsc_clock,
			ts_strt		=> atsc_start,
			ts_dval		=> atsc_valid,
			ts_data		=> atsc_data,
			--
			strt		=> deser_atsc_sop,
			data		=> deser_atsc_data,
			dval		=> deser_atsc_dval
		);

	ATSC_SYNC_0 : entity work.dvb_ts_sync
		port map (
			ts_clk		=> atsc_clock,
			ts_strt		=> deser_atsc_sop,
			ts_data		=> deser_atsc_data,
			ts_dval		=> deser_atsc_dval,
			--
			rst			=> rst,
			clk			=> clk,
			--
			strt		=> ts_atsc_sop,
			data		=> ts_atsc_data,
			dval		=> ts_atsc_dval
		);

	SWTS_SYNC_0 : entity work.dvb_ts_sync
		port map (
			ts_clk		=> swts_clock,
			ts_strt		=> swts_start,
			ts_data		=> swts_data,
			ts_dval		=> swts_valid,
			--
			rst			=> rst,
			clk			=> clk,
			--
			strt		=> ts_swts_sop,
			data		=> ts_swts_data,
			dval		=> ts_swts_dval
		);

	process (rst, clk)
	begin
		if rising_edge(clk) then
			case insel is
				when "00" =>
					strt <= ts_dvb_sop;
					dval <= ts_dvb_dval;
					data <= ts_dvb_data;
					debug_insel <= '0';
				when "01" =>
					strt <= ts_dtmb_sop;
					dval <= ts_dtmb_dval;
					data <= ts_dtmb_data;
					debug_insel <= '0';
				when "10" =>
					strt <= ts_atsc_sop;
					dval <= ts_atsc_dval;
					data <= ts_atsc_data;
					debug_insel <= not debug_insel;
					/* debug_insel <= debug_insel_int; */
				when others =>
					strt <= ts_swts_sop;
					dval <= ts_swts_dval;
					data <= ts_swts_data;
					debug_insel <= '0';
			end case;
		end if;
		if rst then
			strt <= '0';
			dval <= '0';
			data <= (others => '0');
		end if;
	end process;
	
end;
