-- NetUP Universal Dual DVB-CI FPGA firmware
-- http://www.netup.tv
-- 
-- Copyright (c) 2014 NetUP Inc, AVB Labs
-- License: GPLv3


-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ci_bridge is

	port (
		clk			: in std_logic;
		rst			: in std_logic;
		-- CI control port (avalon-MM slave)
		address		: in std_logic_vector(1 downto 0);
		byteenable	: in std_logic_vector(1 downto 0);
		writedata	: in std_logic_vector(15 downto 0);
		write		: in std_logic;
		readdata	: out std_logic_vector(15 downto 0);
		interrupt	: out std_logic;
		-- CI data port (avalon-MM slave)
		cam_address		: in std_logic_vector(17 downto 0);
		cam_writedata	: in std_logic_vector(7 downto 0);
		cam_write		: in std_logic;
		cam_readdata	: out std_logic_vector(7 downto 0);
		cam_read		: in std_logic;
		cam_waitreq		: out std_logic;
		cam_interrupts	: out std_logic_vector(1 downto 0);
		-- conduit (CI bus)
		cia_reset		: out std_logic;
		cib_reset		: out std_logic;
		cia_ce_n		: out std_logic;
		cib_ce_n		: out std_logic;
		ci_reg_n		: out std_logic;
		ci_a			: out std_logic_vector(14 downto 0);
		ci_d_out		: out std_logic_vector(7 downto 0);
		ci_d_in			: in std_logic_vector(7 downto 0);
		ci_d_en			: out std_logic;
		ci_we_n			: out std_logic;
		ci_oe_n			: out std_logic;
		ci_iowr_n		: out std_logic;
		ci_iord_n		: out std_logic;
		cia_wait_n		: in std_logic;
		cib_wait_n		: in std_logic;
		cia_ireq_n		: in std_logic;
		cib_ireq_n		: in std_logic;
		cia_cd_n		: in std_logic_vector(1 downto 0);
		cib_cd_n		: in std_logic_vector(1 downto 0);
		-- conduit (CI bus helpers)
		cia_overcurrent_n	: in std_logic;
		cib_overcurrent_n	: in std_logic;
		cia_reset_buf_oe_n	: out std_logic;
		cib_reset_buf_oe_n	: out std_logic;
		cia_data_buf_oe_n	: out std_logic;
		cib_data_buf_oe_n	: out std_logic;
		ci_bus_dir			: out std_logic;
		-- conduit (CAM status)
		cam0_ready		: out std_logic;
		cam0_fail		: out std_logic;
		cam0_bypass		: out std_logic;
		cam1_ready		: out std_logic;
		cam1_fail		: out std_logic;
		cam1_bypass		: out std_logic
	);

end entity;

architecture rtl of ci_bridge is

	constant BIT_CAM0_STCHG		: natural := 0;
	constant BIT_CAM0_PRESENT	: natural := 1;
	constant BIT_CAM0_RESET		: natural := 2;
	constant BIT_CAM0_BYPASS	: natural := 3;
	constant BIT_CAM0_READY		: natural := 4;
	constant BIT_CAM0_ERROR		: natural := 5;
	constant BIT_CAM0_OVERCURR	: natural := 6;
	constant BIT_CAM0_BUSY		: natural := 7;

	constant BIT_CAM1_STCHG		: natural := 8;
	constant BIT_CAM1_PRESENT	: natural := 9;
	constant BIT_CAM1_RESET		: natural := 10;
	constant BIT_CAM1_BYPASS	: natural := 11;
	constant BIT_CAM1_READY		: natural := 12;
	constant BIT_CAM1_ERROR		: natural := 13;
	constant BIT_CAM1_OVERCURR	: natural := 14;
	constant BIT_CAM1_BUSY		: natural := 15;

	signal scratchpad_reg	: std_logic_vector(15 downto 0);
	signal status_reg		: std_logic_vector(15 downto 0);

	signal ci_timeout_cnt	: unsigned(9 downto 0);

	alias ci_access_cnt	is ci_timeout_cnt(4 downto 0);

	signal cia_ce_i		: std_logic;
	signal cib_ce_i		: std_logic;
	signal ci_iord_i	: std_logic;
	signal ci_iowr_i	: std_logic;
	signal ci_oe_i		: std_logic;
	signal ci_we_i		: std_logic;
	signal ci_d_latch	: std_logic_vector(7 downto 0);

	signal cia_data_buf_oe_i	: std_logic;
	signal cib_data_buf_oe_i	: std_logic;

	signal cam_ready	: std_logic;

	signal cia_wait_meta	: std_logic;
	signal cia_wait			: std_logic;
	signal cib_wait_meta	: std_logic;
	signal cib_wait			: std_logic;

	signal ci_access_io		: std_logic;
	signal ci_access_read	: std_logic;
	signal ci_state_idle_n	: std_logic;
	signal ci_state_access	: std_logic;
	signal ci_state_wait	: std_logic;
	signal ci_state_ack		: std_logic;
	signal ci_state_hold	: std_logic;

	signal ci_evt_error		: std_logic;

	signal ci_oe_start		: std_logic;
	signal ci_oe_end		: std_logic;
	signal ci_we_start		: std_logic;
	signal ci_we_end		: std_logic;
	signal ci_iord_start	: std_logic;
	signal ci_iord_end		: std_logic;
	signal ci_iowr_start	: std_logic;
	signal ci_iowr_end		: std_logic;
	signal bus_oe_start		: std_logic;

	signal cam0_soft_rst	: std_logic;
	signal cam0_stschg_ack	: std_logic;
	signal cia_timeout		: std_logic;

	signal cam1_soft_rst	: std_logic;
	signal cam1_stschg_ack	: std_logic;
	signal cib_timeout		: std_logic;

	signal cam0_stschg		: std_logic;
	signal cam0_present		: std_logic;
	signal cam0_reset		: std_logic;
	signal cam0_bypass_n	: std_logic;
	signal cam0_ready_i		: std_logic;
	signal cam0_error		: std_logic;
	signal cam0_ovcp		: std_logic;
	signal cam0_busy		: std_logic;
	
	signal cam1_stschg		: std_logic;
	signal cam1_present		: std_logic;
	signal cam1_reset		: std_logic;
	signal cam1_bypass_n	: std_logic;
	signal cam1_ready_i		: std_logic;
	signal cam1_error		: std_logic;
	signal cam1_ovcp		: std_logic;
	signal cam1_busy		: std_logic;

begin

	status_reg <= (
		BIT_CAM0_STCHG		=> cam0_stschg,
		BIT_CAM0_PRESENT	=> cam0_present,
		BIT_CAM0_RESET		=> cam0_reset,
		BIT_CAM0_BYPASS		=> not cam0_bypass_n,
		BIT_CAM0_READY		=> cam0_ready_i,
		BIT_CAM0_ERROR		=> cam0_error,
		BIT_CAM0_OVERCURR	=> cam0_ovcp,
		BIT_CAM0_BUSY		=> cam0_busy,
		--
		BIT_CAM1_STCHG		=> cam1_stschg,
		BIT_CAM1_PRESENT	=> cam1_present,
		BIT_CAM1_RESET		=> cam1_reset,
		BIT_CAM1_BYPASS		=> not cam1_bypass_n,
		BIT_CAM1_READY		=> cam1_ready_i,
		BIT_CAM1_ERROR		=> cam1_error,
		BIT_CAM1_OVERCURR	=> cam1_ovcp,
		BIT_CAM1_BUSY		=> cam1_busy
	);

	readdata <= scratchpad_reg when address(1) else status_reg;
	interrupt <= cam0_stschg or cam1_stschg;

	cam_waitreq <= not cam_ready;

	cam0_soft_rst <= write and byteenable(BIT_CAM0_RESET / 8) and writedata(BIT_CAM0_RESET) and (address(0) nor address(1));
	cam0_stschg_ack <= write and byteenable(BIT_CAM0_STCHG / 8) and writedata(BIT_CAM0_STCHG) and address(0) and not address(1);
	cia_timeout <= ci_evt_error and cia_ce_i;
	cam1_soft_rst <= write and byteenable(BIT_CAM1_RESET / 8) and writedata(BIT_CAM1_RESET) and (address(0) nor address(1));
	cam1_stschg_ack <= write and byteenable(BIT_CAM1_STCHG / 8) and writedata(BIT_CAM1_STCHG) and address(0) and not address(1);
	cib_timeout <= ci_evt_error and cib_ce_i;

	cam0_fail <= cam0_error or cam0_ovcp;
	cam0_ready <= cam0_ready_i;
	cam0_bypass <= not cam0_bypass_n;
	cam1_fail <= cam1_error or cam1_ovcp;
	cam1_ready <= cam1_ready_i;
	cam1_bypass <= not cam1_bypass_n;

	CI_CTRL_0 : entity work.ci_control
		port map (
			rst		=> rst,
			clk		=> clk,
			--
			soft_reset	=> cam0_soft_rst,
			stschg_ack	=> cam0_stschg_ack,
			ci_timeout	=> cia_timeout,
			--
			ci_cd_n				=> cia_cd_n,
			ci_reset			=> cia_reset,
			ci_reset_oe_n		=> cia_reset_buf_oe_n,
			ci_overcurrent_n	=> cia_overcurrent_n,
			ci_ireq_n			=> cia_ireq_n,
			--
			cam_stschg		=> cam0_stschg,
			cam_present		=> cam0_present,
			cam_reset		=> cam0_reset,
			cam_ready		=> cam0_ready_i,
			cam_error		=> cam0_error,
			cam_ovcp		=> cam0_ovcp,
			cam_busy		=> cam0_busy,
			cam_interrupt	=> cam_interrupts(0)
		);

	CI_CTRL_1 : entity work.ci_control
		port map (
			rst		=> rst,
			clk		=> clk,
			--
			soft_reset	=> cam1_soft_rst,
			stschg_ack	=> cam1_stschg_ack,
			ci_timeout	=> cib_timeout,
			--
			ci_cd_n				=> cib_cd_n,
			ci_reset			=> cib_reset,
			ci_reset_oe_n		=> cib_reset_buf_oe_n,
			ci_overcurrent_n	=> cib_overcurrent_n,
			ci_ireq_n			=> cib_ireq_n,
			--
			cam_stschg		=> cam1_stschg,
			cam_present		=> cam1_present,
			cam_reset		=> cam1_reset,
			cam_ready		=> cam1_ready_i,
			cam_error		=> cam1_error,
			cam_ovcp		=> cam1_ovcp,
			cam_busy		=> cam1_busy,
			cam_interrupt	=> cam_interrupts(1)
		);

	ci_oe_start <= not ci_state_access and not ci_access_io and ci_access_read when ci_access_cnt = 1 else '0';
	ci_oe_end <= not ci_state_wait and ci_oe_i when ci_access_cnt = 16 else '0';

	ci_we_start <= not ci_state_access and not ci_access_io and not ci_access_read when ci_access_cnt = 1 else '0';
	ci_we_end <= not ci_state_wait and ci_we_i when ci_access_cnt = 11 else '0';

	ci_iord_start <= not ci_state_access and ci_access_io and ci_access_read when ci_access_cnt = 4 else '0';
	ci_iord_end <= not ci_state_wait and ci_iord_i when ci_access_cnt = 13 else '0';

	ci_iowr_start <= not ci_state_access and ci_access_io and not ci_access_read when ci_access_cnt = 7 else '0';
	ci_iowr_end <= not ci_state_wait and ci_iowr_i when ci_access_cnt = 16 else '0';

	bus_oe_start <= ci_access_read when ci_access_cnt = 1 else not ci_access_read when ci_access_cnt = 3 else '0';

	process (rst, clk)
	begin
		if rising_edge(clk) then
			if write and address(1) then
				if byteenable(0) then
					scratchpad_reg(7 downto 0) <= writedata(7 downto 0);
				end if;
				if byteenable(1) then
					scratchpad_reg(15 downto 8) <= writedata(15 downto 8);
				end if;
			end if;
			if not cam0_present then
				cam0_bypass_n <= '0';
			elsif write and byteenable(BIT_CAM0_BYPASS / 8) and writedata(BIT_CAM0_BYPASS) and not address(1) then
				cam0_bypass_n <= address(0);
			end if;
			if not cam1_present then
				cam1_bypass_n <= '0';
			elsif write and byteenable(BIT_CAM1_BYPASS / 8) and writedata(BIT_CAM1_BYPASS) and not address(1) then
				cam1_bypass_n <= address(0);
			end if;
			--
			ci_d_latch <= ci_d_in;
			--
	 	 	cia_wait_meta <= not cia_wait_n;
			cia_wait <= cia_wait_meta;
			cib_wait_meta <= not cib_wait_n;
			cib_wait <= cib_wait_meta;
			-- CI main timer
			if not ci_state_idle_n then
				ci_timeout_cnt <= (others => '0');
			else
				ci_timeout_cnt <= ci_timeout_cnt + 1;
			end if;
			-- CI events
			if ci_timeout_cnt = 750 then
				ci_evt_error <= '1';
			else
				ci_evt_error <= '0';
			end if;
			cam_ready <= (ci_state_ack or ci_evt_error) and not ci_state_hold;
			-- state machine
			if cam_ready then
				ci_state_idle_n <= '0';
			elsif not ci_state_idle_n then
				ci_state_idle_n <= cam_read or cam_write;
			end if;
			if not ci_state_idle_n then
				ci_state_access <= '0';
			elsif ci_oe_start or ci_we_start or ci_iord_start or ci_iowr_start then
				ci_state_access <= '1';
			end if;
			if not ci_state_idle_n then
				ci_state_wait <= '0';
			elsif ci_oe_end or ci_we_end or ci_iord_end or ci_iowr_end then
				ci_state_wait <= '1';
			end if;
			if not ci_state_idle_n then
				ci_state_ack <= '0';
			elsif not ci_state_ack then
				ci_state_ack <= ci_state_wait and ((cia_wait and cia_ce_i) nor (cib_wait and cib_ce_i));
			end if;
			if not ci_state_idle_n then
				ci_state_hold <= '0';
			elsif not ci_state_hold then
				ci_state_hold <= ci_evt_error or ci_state_ack;
			end if; 
			--
			if not ci_state_idle_n then
				cia_ce_i <= (cam_read or cam_write) and not cam_address(17); 
				cib_ce_i <= (cam_read or cam_write) and cam_address(17); 
			end if;
			if not ci_state_idle_n and (cam_read or cam_write) then
				ci_reg_n <= cam_address(16);
				ci_a <= cam_address(14 downto 0);
				ci_d_out <= cam_writedata;
				ci_access_io <= cam_address(15) and not cam_address(16);
				ci_access_read <= cam_read;
			end if;
			if not ci_state_idle_n then
				cam_readdata <= (others => '1');
			elsif ci_state_ack and not ci_state_hold then
				cam_readdata <= ci_d_latch;
			end if;
			-- Data direction control
			ci_d_en <= ci_state_idle_n and not ci_access_read;
			ci_bus_dir <= ci_access_read;
			cia_data_buf_oe_i <= ci_state_idle_n and cia_ce_i and (cia_data_buf_oe_i or bus_oe_start);
			cib_data_buf_oe_i <= ci_state_idle_n and cib_ce_i and (cib_data_buf_oe_i or bus_oe_start);
			--
			if ci_oe_start then
				ci_oe_i <= '1';
			elsif ci_state_ack or ci_evt_error then
				ci_oe_i <= '0';
			end if;
			if ci_we_start then
				ci_we_i <= '1';
			elsif ci_state_ack or ci_evt_error then
				ci_we_i <= '0';
			end if;
			if ci_iord_start then
				ci_iord_i <= '1';
			elsif ci_state_ack or ci_evt_error then
				ci_iord_i <= '0';
			end if;
			if ci_iowr_start then
				ci_iowr_i <= '1';
			elsif ci_state_ack or ci_evt_error then
				ci_iowr_i <= '0';
			end if;
		end if;
		if rst then
			scratchpad_reg <= (others => '0');
			cam0_bypass_n <= '0';
			cam1_bypass_n <= '0';
			--
			ci_d_latch <= (others => '0');
			cia_wait_meta <= '0';
			cia_wait <= '0';
			cib_wait_meta <= '0';
			cib_wait <= '0';
			--
			ci_timeout_cnt <= (others => '0');
			ci_access_io <= '0';
			ci_access_read <= '0';
			ci_evt_error <= '0';
			--
			ci_state_idle_n <= '0';
			ci_state_access <= '0';
			ci_state_wait <= '0';
			ci_state_ack <= '0';
			ci_state_hold <= '0';
			--
			cam_ready <= '0';
			cam_readdata <= (others => '0');
			--
			cia_ce_i <= '0';
			cib_ce_i <= '0';
			ci_reg_n <= '0';
			ci_a <= (others => '0');
			ci_d_out <= (others => '0');
			ci_d_en <= '0';
			ci_bus_dir <= '0';
			cia_data_buf_oe_i <= '0';
			cib_data_buf_oe_i <= '0';
			ci_oe_i <= '0';
			ci_we_i <= '0';
			ci_iord_i <= '0';
			ci_iowr_i <= '0';
		end if;
	end process;

	cia_ce_n <= not cia_ce_i;
	cib_ce_n <= not cib_ce_i;
	ci_oe_n <= not ci_oe_i;
	ci_we_n <= not ci_we_i;
	ci_iord_n <= not ci_iord_i;
	ci_iowr_n <= not ci_iowr_i;

	cia_data_buf_oe_n <= not cia_data_buf_oe_i;
	cib_data_buf_oe_n <= not cib_data_buf_oe_i;

end architecture;
