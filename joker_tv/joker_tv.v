//
// Joker TV top
// https://jokersys.com
// 
// Based on 
// USB 2.0 tap with USB 2.0 to host,
// for Daisho main board, USB 3.0 front-end
// top-level
//
// Copyright (c) 2014 Jared Boone, ShareBrained Technology, Inc.
//
// This file is part of Project Daisho.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; see the file COPYING.  If not, write to
// the Free Software Foundation, Inc., 51 Franklin Street,
// Boston, MA 02110-1301, USA.
//

module joker_tv
(
input    wire           clk_27,

/* CI pins */
input		wire	ci_ireq_n,
input		wire	ci_cd1,
input		wire	ci_cd2,
input		wire	ci_overcurrent_n,
output	wire	ci_reset_oe_n,
output	wire	ci_reset,
output	wire	ci_data_buf_oe_n,
output	wire	[14:0] ci_a,
inout		wire	[7:0] ci_d,
output	wire	ci_bus_dir,
input		wire	ci_wait_n,
output	wire	ci_iowr_n,
output	wire	ci_oe_n,
output	wire	ci_we_n,
output	wire	ci_d_en,
output	wire	ci_reg_n,
output	wire	ci_ce_n,


/* LG TS pins */
input		wire	lg_clk,
input		wire	lg_data,
input		wire	lg_valid,
input		wire	lg_start,

/* SONY TS pins */
input		wire	sony_clk,
input		wire	sony_data,
input		wire	sony_valid,
input		wire	sony_start,

output   wire  atbm,
output   wire  lg,
output   wire  sony_tuner,
output   wire  sony_tuner_i2c_en,
output   wire  sony_demod,
output   wire  tps,
output   wire  tps_ci,
inout    wire  tps_o,

inout    wire           io_scl,
inout    wire           io_sda,
output   wire           io_reset_n,
input    wire           io_int_n,


// USB: PIPE
output   wire           usb_pipe_tx_clk,
output   wire  [15:0]   usb_pipe_tx_data,
output   wire  [ 1:0]   usb_pipe_tx_datak,
input    wire           usb_pipe_pclk,
input    wire  [15:0]   usb_pipe_rx_data,
input    wire  [ 1:0]   usb_pipe_rx_datak,
input    wire           usb_pipe_rx_valid,

// USB: Control and Status
output   wire           usb_phy_reset_n,
output   wire           usb_tx_detrx_lpbk,
output   wire           usb_tx_elecidle,
inout    wire           usb_rx_elecidle,
input    wire  [ 2:0]   usb_rx_status,
output   wire  [ 1:0]   usb_power_down,
inout    wire           usb_phy_status,
input    wire           usb_pwrpresent,

// USB: Configuration
output   wire           usb_tx_oneszeros,
output   wire  [ 1:0]   usb_tx_deemph,
output   wire  [ 2:0]   usb_tx_margin,
output   wire           usb_tx_swing,
output   wire           usb_rx_polarity,
output   wire           usb_rx_termination,
output   wire           usb_rate,
output   wire           usb_elas_buf_mode,

// USB: ULPI
input    wire           usb_ulpi_clk,
inout    wire  [ 7:0]   usb_ulpi_d,
input    wire           usb_ulpi_dir,
output   wire           usb_ulpi_stp,
input    wire           usb_ulpi_nxt,
input    wire           usb_id,

// USB: Reset and Output Control Interface
output   wire           usb_reset_n,
output   wire           usb_out_enable
);


joker_control joker_control_inst (
	.clk(usb_ulpi_clk /* clk_50 */),
   .reset(reset),
	
	/* EP2 OUT */
   .buf_out_hasdata(buf_out_hasdata), 
	.buf_out_len(buf_out_len), 
	.buf_out_q(buf_out_q),
	.buf_out_addr(buf_out_addr),
	.buf_out_arm_ack(buf_out_arm_ack),
	.buf_out_arm(buf_out_arm),
	
	/* EP1 IN */
   .usb_in_commit_ack(usb_in_commit_ack),
   .usb_in_commit(usb_in_commit),
	.usb_in_ready(usb_in_ready),
	.usb_in_addr(usb_in_addr),
	.usb_in_data(usb_in_data),
	.usb_in_wren(usb_in_wren),
	.usb_in_commit_len(usb_in_commit_len),
	
	/* I2C pins */
	.io_scl(io_scl),
	.io_sda(io_sda),
	
	/* staff that we care about */
	.reset_ctrl(reset_ctrl),
	.insel(insel),
	.isoc_commit_len(isoc_commit_len)
);

/*
reg wb_we_i;
reg wb_stb_i;
reg   [31:0]   count_i2c;

reg i2c_we;
reg i2c_stb;
wire wb_ack_o;
wire wb_inta_o;
wire wb_rst_i;
reg [7:0] i2c_addr;
reg [7:0] i2c_dat;
wire [7:0] wb_dat_o;

opencores_i2c i2c_inst (
   .wb_clk_i (clk_50),
   .wb_rst_i ( wb_rst_i ),
   .wb_dat_i ( i2c_dat ),
   .wb_adr_i ( i2c_addr[2:0] ),
   .wb_we_i ( i2c_we ),
   .wb_stb_i ( i2c_stb ),
   .wb_dat_o ( wb_dat_o ),
   .wb_ack_o ( wb_ack_o ),
   .wb_inta_o ( wb_inta_o ),
   .scl_pad_io  (io_scl),
   .sda_pad_io  (io_sda)
);
*/

/* aospan usb EP2 OUT */
wire buf_out_hasdata;
wire  [7:0] buf_out_q;
wire  [9:0] buf_out_len;
wire 	[10:0] buf_out_addr; /* input */
wire buf_out_arm;
wire buf_out_arm_ack;

reg [7:0] dc;
reg [7:0] dc_rd = 8'h00;
reg [7:0] dc_rd_wrap = 8'h00;

wire clk_50;
wire clk_100;
reg [1:0] det_ack;
wire acked;
assign acked = (det_ack == 2'b10);
reg [7:0] wr_cnt = 8'b00000000;
wire [1:0] insel;
wire [10:0] isoc_commit_len;
wire	[7:0] reset_ctrl;
// reg [7:0] reset_ctrl = 8'hF3;
	
// aospan: rf
assign   sony_tuner_i2c_en = reset_ctrl[7];
assign   tps_ci = reset_ctrl[6];
assign   tps = reset_ctrl[5];
assign   usb_phy_reset_n = reset_ctrl[4];
assign   atbm = reset_ctrl[3];
assign   lg = reset_ctrl[2];
assign   sony_tuner = reset_ctrl[1];
assign   sony_demod = reset_ctrl[0];
 

 
ts_proxy ts_proxy_inst (
                .clk( usb_ulpi_clk /* clk_50 */),
                .atsc_clock(lg_clk),
                .atsc_start(lg_start),
                .atsc_valid(lg_valid),
                .atsc_data(lg_data),
					 .dvb_clock(sony_clk),
                .dvb_start(sony_start),
                .dvb_valid(sony_valid),
                .dvb_data(sony_data),
                .ep3_usb_in_data(ep3_usb_in_data),
                .ep3_usb_in_addr(ep3_usb_in_addr),
                .ep3_usb_in_wren(ep3_usb_in_wren),
                .ep3_usb_in_commit(ep3_usb_in_commit),
                .ep3_usb_in_commit_len(ep3_usb_in_commit_len),
                .ep3_usb_in_ready(ep3_usb_in_ready),
					 .ep3_usb_in_commit_ack(ep3_usb_in_commit_ack),
					 .ep3_ext_buf_out_arm(ep3_ext_buf_out_arm),
                .commit_len(isoc_commit_len),
					 .insel(insel),
					 //.pkts_cnt(probe[15:0]),
					 //.tslost(probe[23:16]),
					 // .acked(probe[15:8]),
					 // .missed(probe[23:16]),
					 // .state(probe[27:24]),
					 //.fifo_clean(probe[31:28]),
                .reset(reset)
);


aospan_pll  apll (
   .inclk0           ( clk_27 ),
   .c0               (clk_50),
	.c1               (clk_100)
);


	reg [31:0] source;
	wire [31:0] probe;

/*
`ifndef MODEL_TECH
probe	probe_inst(
	.probe( probe ),
	.source(source)
);
`endif
*/

reg 	cam_read;
wire	cam_waitreq;
reg	[7:0]	cam_readdata;

ci_bridge ci_bridge_inst (
	.clk(clk_50),
	.rst(reset),
	
	/* only first CI (cia) used */
	.cia_ireq_n(ci_ireq_n),
	.cia_cd_n( {ci_cd1, ci_cd2} ),
	.cia_overcurrent_n (ci_overcurrent_n),
	.cia_reset_buf_oe_n(ci_reset_oe_n),
	.cia_reset(ci_reset),
	.cia_data_buf_oe_n(ci_data_buf_oe_n),
	.ci_a(ci_a),
	.ci_d_in(ci_d),
	//.ci_d_out(ci_d),
	.ci_bus_dir(ci_bus_dir),
	.cia_wait_n(ci_wait_n),
	.ci_iowr_n(ci_iowr_n),
	.ci_oe_n(ci_oe_n),
	.ci_we_n(ci_we_n),
	// .cam0_ready(probe[9]),
	// .cam0_fail(probe[10]),
	// .cam0_bypass(probe[11]),
	// .ci_d_en(probe[8] /* ci_d_en */),
	.cam_readdata(cam_readdata),
	.cam_read(cam_read),
	.cam_waitreq(cam_waitreq),
	.cam_address(source[17:0]),
	.ci_reg_n(ci_reg_n),
	.cia_ce_n(ci_ce_n)	
);

reg source_1;

/*
always @(posedge clk_50) begin
	source_1 <= source[18];
	probe[12] <= cam_read;
	
	if (cam_read && ~cam_waitreq)
	begin
		cam_read <= 0;
		probe[7:0] <= cam_readdata;
		probe[31:24] <= ci_d;
	end
	
	if(source[18] && ~source_1)
	begin
		cam_read <= 1;
	end
end

*/

reg      reset;

assign   usb_pipe_tx_clk      = 1'b0;
assign   usb_pipe_tx_data     = 16'h0000;
assign   usb_pipe_tx_datak    = 2'b00;
// assign   usb_phy_reset_n      = 1'b1;
assign   usb_tx_detrx_lpbk    = 1'b0;
assign   usb_tx_elecidle      = 1'b1;
assign   usb_rx_elecidle      = usb_strapping ? 1'bZ : 1'b0;
assign   usb_power_down       = 2'b00;
assign   usb_phy_status       = usb_strapping ? 1'bZ : 1'b0;
assign   usb_tx_oneszeros     = 1'b0;
assign   usb_tx_deemph        = 2'b10;
assign   usb_tx_margin[2:1]   = 2'b00;
assign   usb_tx_margin[0]     = usb_strapping ? 1'b0 : 1'b1;
assign   usb_tx_swing         = 1'b0;
assign   usb_rx_polarity      = 1'b0;
assign   usb_rx_termination   = 1'b0;
assign   usb_rate             = 1'b1;
assign   usb_elas_buf_mode    = 1'b0;
assign   usb_reset_n          = reset_n;
assign   usb_out_enable       = 1'b1;
wire     usb_strapping;
wire     usb_connected;
wire     usb_configured;

/* USB PHY strapping control (ordinarily handled by USB 3.0 block) */
/* TODO: This is probably not necessary for USB0 and USB1, as the
 * reset lines are controlled by an I/O expander, which has a lot of
 * latency between changing the output voltages and the I2C transaction
 * stopping.
 */

reg   reset_n_q1, reset_n_q2, reset_n_q3;
reg   usb0_phy_ready_q3, usb0_phy_ready_q2, usb0_phy_ready_q1;
reg   usb1_phy_ready_q3, usb1_phy_ready_q2, usb1_phy_ready_q1;

always @(posedge clk_50) begin
   { reset_n_q3, reset_n_q2, reset_n_q1 } <= { reset_n_q2, reset_n_q1, reset_n };
end

assign   usb_strapping = reset_n_q3;
assign   usb0_strapping = usb0_phy_ready_q3;
assign   usb1_strapping = usb1_phy_ready_q3;

/* System reset */
wire     reset_n;
assign   reset_n = ~reset;

reg   [ 7:0]   count_clk_in_us;
reg            pulse_1us;
reg   [31:0]   count_us;

parameter count_board_reset = 50000000;   // 1sec


reg   [31:0]   count_1;
   
initial begin
   reset <= 1;
   count_1 <= 0;
   
   count_clk_in_us <= 0;
   pulse_1us <= 0;
   count_us <= 0;
	wr_cnt <= 0;
	// reset_ctrl <= 8'hB3;
	// isoc_commit_len <= 11'd512;
	cam_read <= 0;
end

always @(posedge clk_50) begin
   if(count_clk_in_us == 49) begin
      count_clk_in_us <= 0;
      pulse_1us <= 1;
      count_us <= count_us + 1'b1;
   end
   else begin
      count_clk_in_us <= count_clk_in_us + 1'b1;
      pulse_1us <= 0;
   end
end

always @(posedge clk_50) begin
   count_1 <= count_1 + 1'b1;
   if(count_1 >= count_board_reset) reset <= 0;
end




////////////////////////////////////////////////////////////
//
// USB 2.0 controller
//
////////////////////////////////////////////////////////////

usb2_top iu2 (
   .ext_clk          ( /* usb_ulpi_clk */ clk_50 ),
   .reset_n          ( usb_reset_n ),
   .reset_n_out      (  ),
   
   .opt_disable_all  ( 1'b0 ),
   .opt_enable_hs    ( 1'b1 ),
   .opt_ignore_vbus  ( 1'b1 ),
   .stat_connected   ( usb_connected ),
   .stat_configured  ( usb_configured ),
   
   .phy_ulpi_clk     ( usb_ulpi_clk ),
   .phy_ulpi_d       ( usb_ulpi_d ),
   .phy_ulpi_dir     ( usb_ulpi_dir ),
   .phy_ulpi_stp     ( usb_ulpi_stp ),
   .phy_ulpi_nxt     ( usb_ulpi_nxt ),

   .buf_in_addr         ( usb_in_addr ),
   .buf_in_data         ( usb_in_data ),
   // .buf_in_data         ( indata ),
   .buf_in_wren         ( usb_in_wren ),
   .buf_in_ready        ( usb_in_ready ),
   .buf_in_commit       ( usb_in_commit ),
   .buf_in_commit_len   ( usb_in_commit_len ),
   .buf_in_commit_ack   ( usb_in_commit_ack ),
	
	/* EP3 TS */
	.ep3_ext_clk				( /* lg_clk */ /* clk_50 */ usb_ulpi_clk),
	.ep3_buf_in_addr         ( ep3_usb_in_addr ),
   .ep3_buf_in_data         ( ep3_usb_in_data ),
   .ep3_buf_in_wren         ( ep3_usb_in_wren ),
   .ep3_buf_in_ready        ( ep3_usb_in_ready ),
   .ep3_buf_in_commit       ( ep3_usb_in_commit ),
   .ep3_buf_in_commit_len   ( ep3_usb_in_commit_len ),
   .ep3_buf_in_commit_ack   ( ep3_usb_in_commit_ack ),
	.ep3_ext_buf_out_arm			(ep3_ext_buf_out_arm),
   
   /* aospan */
   .buf_out_hasdata     ( buf_out_hasdata ),
   .buf_out_q           ( buf_out_q ),
   .buf_out_len         ( buf_out_len ),
   .buf_out_addr        ( buf_out_addr ),
   .buf_out_arm         ( buf_out_arm ),
   .buf_out_arm_ack     ( buf_out_arm_ack ),
   

   .dbg_linestate    (  ),
   .dbg_frame_num    (  )
);

// ULPI interfaces to access raw USB packet data

wire              usb0_ulpi_out_act;
wire     [ 7:0]   usb0_ulpi_out_byte;
wire              usb0_ulpi_out_latch;

wire              usb0_ulpi_in_cts;
wire              usb0_ulpi_in_nxt;
wire     [ 7:0]   usb0_ulpi_in_byte;
wire              usb0_ulpi_in_latch;
wire              usb0_ulpi_in_stp;

wire     [ 1:0]   usb0_dbg_linestate;



/* EP3 TS */
wire     [ 10:0]   ep3_usb_in_addr;
wire     [ 7:0]   ep3_usb_in_data;
wire              ep3_usb_in_wren;
wire              ep3_usb_in_ready;
wire              ep3_usb_in_commit;
wire     [ 10:0]   ep3_usb_in_commit_len;
wire              ep3_usb_in_commit_ack;
wire					ep3_ext_buf_out_arm;

wire     [ 8:0]   usb_in_addr;
wire     [ 7:0]   usb_in_data;
wire              usb_in_wren;
wire              usb_in_ready;
wire              usb_in_commit;
wire     [ 9:0]   usb_in_commit_len;
wire              usb_in_commit_ack;

wire     [ 1:0]   usb1_dbg_linestate;


endmodule
