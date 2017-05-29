-- NetUP Universal Dual DVB-CI FPGA firmware
-- http://www.netup.tv
-- 
-- Copyright (c) 2014 NetUP Inc, AVB Labs
-- License: GPLv3


-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ci_control is

	generic (
		t_h		: natural := 18750000;	-- 300 ms
		t_w		: natural := 12500;		-- 200 us aospan:increase reset time (20->200usec) for neotion cam's
		t_su	: natural := 1251250	-- t_w + 20 ms
	);
	port (
		clk			: in std_logic;
		rst			: in std_logic;
		-- CAM control
		soft_reset	: in std_logic;
		stschg_ack	: in std_logic;
		ci_timeout	: in std_logic;
		-- CAM interface
		ci_cd_n				: in std_logic_vector(1 downto 0);
		ci_reset			: out std_logic;
		ci_reset_oe_n		: out std_logic;
		ci_overcurrent_n	: in std_logic;
		ci_ireq_n			: in std_logic;
		-- CAM status
		cam_stschg		: out std_logic;
		cam_present		: out std_logic;
		cam_reset		: out std_logic;
		cam_ready		: out std_logic;
		cam_error		: out std_logic;
		cam_ovcp		: out std_logic;
		cam_busy		: out std_logic;
		cam_interrupt	: out std_logic
	);

end entity;

architecture rtl of ci_control is

	signal ci_cd_meta	: std_logic_vector(1 downto 0);
	signal ci_cd_sync	: std_logic_vector(1 downto 0);

	signal ci_ovcp_meta	: std_logic;
	signal ci_ovcp_sync	: std_logic;

	signal ci_ireq_meta	: std_logic;
	signal ci_ireq_sync	: std_logic;

	signal end_of_por	: std_logic;
	signal end_of_reset	: std_logic;
	signal end_of_tsu	: std_logic;
	signal ci_cnt		: unsigned(24 downto 0);

	signal ci_cd		: std_logic;
	signal ci_stschg	: std_logic;

	signal ci_reset_oe_i	: std_logic;
	signal ci_reset_phase_n	: std_logic;
	signal ci_reset_n		: std_logic;

	type ci_state_t	is (
		ci_state_por, 
		ci_state_reset, 
		ci_state_busy, 
		ci_state_ready, 
		ci_state_ovcp, 
		ci_state_error
	);

	signal ci_state		: ci_state_t;

begin

	ci_reset_oe_n <= not ci_reset_oe_i;
	ci_reset <= not ci_reset_n;

	cam_stschg <= ci_stschg;
	cam_present <= ci_cd;
	cam_reset <= '1' when ci_state = ci_state_reset else '0';
	cam_ready <= '1' when ci_state = ci_state_ready else '0';
	cam_busy <= '1' when ci_state = ci_state_busy else '0';
	cam_ovcp <= '1' when ci_state = ci_state_ovcp else '0';
	cam_error <= '1' when ci_state = ci_state_error else '0';

	process (rst, clk, ci_cd)
	begin
		if rising_edge(clk) then
			ci_cd_meta <= not ci_cd_n;
			ci_cd_sync <= ci_cd_meta;
			ci_cd <= ci_cd_sync(1) and ci_cd_sync(0);
			--
			ci_ovcp_meta <= not ci_overcurrent_n;
			ci_ovcp_sync <= ci_ovcp_meta;
			ci_ireq_meta <= not ci_ireq_n;
			ci_ireq_sync <= ci_ireq_meta;
			-- process timer
			if ci_cnt = t_h then
				end_of_por <= not ci_reset_oe_i;
			else
				end_of_por <= '0';
			end if;
			if ci_cnt = t_w then
				end_of_reset <= ci_reset_oe_i;
			else
				end_of_reset <= '0';
			end if;
			if ci_cnt = t_su then
				end_of_tsu <= ci_reset_oe_i;
			else
				end_of_tsu <= '0';
			end if;
			if end_of_por or ci_reset_phase_n then
				ci_cnt <= (others => '0');
			else
				ci_cnt <= ci_cnt + 1;
			end if;
			--
			if stschg_ack then
				ci_stschg <= '0';
			end if;
			case ci_state is
				when ci_state_reset | ci_state_busy =>
					if ci_reset_phase_n and (ci_ovcp_sync or not ci_ireq_sync) then
						ci_stschg <= '1';
					end if;
				when ci_state_ready =>
					if ci_ovcp_sync or ci_timeout or (ci_cd_sync(1) nand ci_cd_sync(0)) then
						ci_stschg <= '1';
					end if;
				when ci_state_ovcp | ci_state_error =>
					if ci_cd_sync(1) nand ci_cd_sync(0) then
						ci_stschg <= '1';
					end if;
				when others =>
					null;
			end case;
			-- process reset state machine
			ci_reset_oe_i <= ci_reset_oe_i or end_of_por;
			if ci_reset_phase_n and soft_reset then
				ci_reset_n <= '0';
				ci_reset_phase_n <= '0';
			else
				ci_reset_n <= ci_reset_n or end_of_reset;
				ci_reset_phase_n <= ci_reset_phase_n or end_of_tsu;
			end if;
			-- status state machine
			case ci_state is
				when ci_state_por =>
					if ci_reset_oe_i then
						ci_state <= ci_state_reset;
					end if;
				when ci_state_reset =>
					if ci_reset_phase_n then
						if ci_ovcp_sync then
							ci_state <= ci_state_ovcp;
						elsif ci_ireq_sync then
							ci_state <= ci_state_busy;
						else
							ci_state <= ci_state_ready;
						end if;
					end if;
				when ci_state_busy =>
					if not ci_reset_phase_n then
						ci_state <= ci_state_reset;
					elsif ci_ovcp_sync then
						ci_state <= ci_state_ovcp;
					elsif not ci_ireq_sync then
						ci_state <= ci_state_ready;
					end if;
				when ci_state_ready =>
					if not ci_reset_phase_n then
						ci_state <= ci_state_reset;
					elsif ci_ovcp_sync then
						ci_state <= ci_state_ovcp;
					elsif ci_timeout then
						ci_state <= ci_state_error;
					end if;
				when ci_state_ovcp =>
					if not ci_reset_phase_n then
						ci_state <= ci_state_reset;
					end if;
				when ci_state_error =>
					if not ci_reset_phase_n then
						ci_state <= ci_state_reset;
					end if;
			end case;
			-- interrupt function
			if ci_state = ci_state_ready then
				cam_interrupt <= ci_ireq_sync;
			else
				cam_interrupt <= '0';
			end if;
		end if;
		if not ci_cd then
			end_of_por <= '0';
			end_of_reset <= '0';
			end_of_tsu <= '0';
			ci_cnt <= (others => '0');
			--
			ci_reset_oe_i <= '0';
			ci_reset_phase_n <= '0';
			ci_reset_n <= '0';
			--
			ci_state <= ci_state_por;
			--
			cam_interrupt <= '0';
		end if;
		if rst then
			ci_cd_meta <= (others => '0');
			ci_cd_sync <= (others => '0');
			--
			ci_ovcp_meta <= '0';
			ci_ovcp_sync <= '0';
			--
			ci_ireq_meta <= '0';
			ci_ireq_sync <= '0';
			--
			ci_cd <= '0';
			ci_stschg <= '0';
		end if;
	end process;

end architecture;
