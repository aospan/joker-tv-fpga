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
inout    wire  tps_ci_o,

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


/* aospan usb EP2 OUT */
wire buf_out_hasdata;
wire  [7:0] buf_out_q;
wire  [9:0] buf_out_len;
reg   [8:0] buf_out_addr; /* input */
reg buf_out_arm;
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
reg [1:0] insel;
reg [10:0] isoc_commit_len;


   // states
	reg [3:0] c_state = 4'b0000;
	parameter ST_IDLE=0, ST_WAIT_ACK=1, ST_READ=2, ST_WRITE=3, 
		ST_READ_ADDR=4, ST_READ_DATA=5, ST_WAIT_ACK_I2C=6, ST_SET_ADDR=7, 
		ST_READ_FROM_I2C = 8, ST_READ_FROM_I2C2 = 9;

/* CONTROL REGISTERS and I2C  part*/
always @(posedge clk_50) begin
   dc <= dc + 1'b1;
	dc_rd <= dc_rd + 1'b1;

	if (dc_rd == 254)
		dc_rd_wrap <= dc_rd_wrap + 1;
			
	det_ack <= { det_ack[0], buf_out_arm_ack };
			
	if (usb_in_commit_ack)
		usb_in_commit <= 0;
				
   case (c_state)
		ST_IDLE:
		begin	
		   if (buf_out_hasdata) begin
				dc <= 0;
				c_state <= ST_READ;
			end

		end
		
		ST_READ: 
		begin
		   /*  OUT EP2 ready to read data from */
			/* read first byte */
			c_state <= ST_SET_ADDR;
		end
		
		ST_SET_ADDR:
		begin
			buf_out_addr <= 0;
			dc_rd <= 0;
			dc_rd_wrap <= 0;
			c_state <= ST_READ_ADDR;
		end
		
		ST_READ_ADDR:
		begin
			if ( dc_rd > 3)
			begin
				i2c_addr <= buf_out_q[7:0];
				c_state <= ST_READ_DATA;
				buf_out_addr <= 1;
				dc_rd <= 0;
				dc_rd_wrap <= 0;
			end
		end
		
		ST_READ_DATA:
		begin
				if ( dc_rd > 3)
				begin
					i2c_dat <= buf_out_q[7:0];
					c_state <= ST_WAIT_ACK;
				end
			// end
      end
		
		ST_WAIT_ACK:
		begin
			// tell EP that we don't need this data anymore
			buf_out_arm <= 1;
			
			/* negative edge: disarm ep2 OUT */
			if ( acked ) begin
				buf_out_arm <= 0;
				dc_rd <= 0;
				dc_rd_wrap <= 0;
				
				if ( i2c_addr == 5) begin
					/* address 5 for reading from i2c */
					c_state <= ST_READ_FROM_I2C;
				end
				else if ( i2c_addr == 6) begin
					/* address 6 for writing reset_ctrl */
					c_state <= ST_IDLE;
					reset_ctrl <= i2c_dat;
				end
				else if ( i2c_addr == 7) begin
					/* address 7 for TS input selection */
					c_state <= ST_IDLE;
					insel <= i2c_dat;
				end
				else if ( i2c_addr == 8) begin
					/* address 7 for USB ISOC transaction len  HI */
					c_state <= ST_IDLE;
					isoc_commit_len[10:8] <= i2c_dat;
				end
				else if ( i2c_addr == 9) begin
					/* address 7 for USB ISOC transaction len  LO */
					c_state <= ST_IDLE;
					isoc_commit_len[7:0] <= i2c_dat;
				end
				else begin				
					i2c_we <= 1'b1;
					i2c_stb <= 1'b1;
					c_state <= ST_WAIT_ACK_I2C;
				end
			end
		end
		
      ST_WAIT_ACK_I2C:
		begin		
			if ( wb_ack_o ) begin
				/* remove write request from wishbone */
				i2c_we <= 0;
				i2c_stb <= 0;				
				c_state <= ST_IDLE;
				wr_cnt <= wr_cnt + 1'b1;
			end
		end
		
		ST_READ_FROM_I2C:
		begin
				i2c_addr <= i2c_dat[2:0]; /* 'b100 sr - status reg, 'b011 - received byte, etc */
				i2c_we <= 0;
				i2c_stb <= 0;
				dc_rd <= 0;
				dc_rd_wrap <= 0;
				c_state <= ST_READ_FROM_I2C2;
		end
		
		ST_READ_FROM_I2C2:
		begin
			if (dc_rd > 3) begin
				usb_in_data <= wb_dat_o;
				usb_in_wren <= 1;
				usb_in_commit_len <= 1;
				usb_in_commit <= 1;
				c_state <= ST_IDLE;
			end
		end
		
		default begin
			c_state <= ST_IDLE;
		end
   endcase
end

reg [7:0] reset_ctrl = 8'hF3;
	
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
                .commit_len( isoc_commit_len  /* 11'd1024 */ /* 11'd512 */ /* 376 */ /*188 */),
					 .insel(insel),
					 // .tslost(probe_rfa[7:0]),
					 // .acked(probe_rfa[15:8]),
					 // .missed(probe_rfa[23:16]),
					 // .state(probe_rfa[27:24]),
					 // .fifo_clean(probe_rfa[31:28]),
                .reset(reset)
);


aospan_pll  apll (
   .inclk0           ( clk_27 ),
   .c0               (clk_50),
	.c1               (clk_100)
);



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
	c_state <= 0;
	reset_ctrl <= 8'hF3;
	isoc_commit_len <= 11'd512;
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

reg     [ 8:0]   usb_in_addr;
reg     [ 7:0]   usb_in_data;
reg              usb_in_wren;
wire              usb_in_ready;
reg              usb_in_commit;
reg     [ 9:0]   usb_in_commit_len;
wire              usb_in_commit_ack;

wire     [ 1:0]   usb1_dbg_linestate;


endmodule