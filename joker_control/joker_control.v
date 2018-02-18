//
// Joker TV control API
// (c) Abylay Ospan, 2017
// aospan@jokersys.com
// https://jokersys.com
// GPLv2

/* EP2 OUT EP used as joker commands (jcmd) source
	EP1 IN EP used as command reply storage
	*/

module joker_control
(
   input    wire  clk,
   input    wire  reset,
	
	/* SPI flash pins */
	output		wire	FLASH_SCLK,
	output		wire	FLASH_MOSI,
	input			wire	FLASH_MISO,
	output		wire	FLASH_nCS,

	/* EP3 IN, TS to host, isoc */
	output	reg	ep3_buf_out_clear,
	
	/* EP4 OUT, TS from host, bulk  */
   input    wire  ep4_buf_out_hasdata, 
	input		wire	[10:0] ep4_buf_out_len, 
	input		wire	[7:0] ep4_buf_out_q,
	output	wire	[10:0] ep4_buf_out_addr,
	input		wire	ep4_buf_out_arm_ack,
	output	reg	ep4_buf_out_arm,	
	output	reg	ep4_buf_out_clear,
	
	/* EP2 OUT */
   input    wire  buf_out_hasdata, 
	input		wire	[9:0] buf_out_len, 
	input		wire	[7:0] buf_out_q,
	output	wire	[10:0] buf_out_addr_o,
	input		wire	buf_out_arm_ack,
	output	reg	buf_out_arm,
	
	/* EP1 IN */
   input    wire  usb_in_commit_ack,
	input		wire	usb_in_ready,
   output   reg  usb_in_commit,
	output	wire	[ 10:0]   usb_in_addr_o,
	output	wire	[ 7:0]   usb_in_data_o,
	output	wire	usb_in_wren_o,
	output	reg	[ 10:0]   usb_in_commit_len,
	
	/* I2C */
	inout		wire	io_scl,
	inout		wire	io_sda,
	
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
	output	wire	ci_iord_n,
	output	wire	ci_oe_n,
	output	wire	ci_we_n,
	output	wire	ci_d_en,
	output	wire	ci_reg_n,
	output	wire	ci_ce_n,
	
	/* TS traffic from USB bulk transfers */
	output	wire	[7:0]	ts_usb_data,
	output	wire	ts_usb_writereq,
	input		wire	ts_usb_almost_full,
	
	/* staff that we care about */
	output	reg	[7:0]	reset_ctrl,
	output	reg	[7:0]	insel,
	output	reg	[10:0] isoc_commit_len,
	output	wire	cam0_ready,
	output	wire	cam0_fail,
	output	reg	ts_ci_enable,
	
	output		reg	fifo_aclr,

	output	wire[12:0]  table_wr_address,
	output	wire [0:0]  table_data,
	output	wire table_wren
);

// remote update
wire	busy;
reg	reconfig;
wire [28:0] data_out;
reg [2:0]  param;
reg	read_param;

joker_remote_update joker_remote_update_inst (
	.clock(clk),
	.reset(reset),
	.busy(busy),
	.reconfig(reconfig),
	.data_out(data_out),
	.param(param),
	.read_param(read_param)
);

reg	[7:0]	j_cmd;
`include "joker_control.vh"

reg   reset_prev;
reg	buf_out_arm_ack_prev;
reg	usb_in_commit_ack_prev;

reg ci_do_reset;

// main states
reg [3:0] c_state = 4'b0000;
parameter ST_RESET=0, ST_IDLE=1, ST_CMD=2, ST_CMD_DONE=3, ST_READ_CMD=4;

// states inside j_cmd processing
reg [7:0] j_state;
parameter	J_ST_DEFAULT=1,
				J_ST_I2C_WRITE=2, 
				J_ST_I2C_WRITE2=3,
				J_ST_I2C_WRITE3=4,
				J_ST_I2C_WRITE_WAIT_ACK=5,
				J_ST_I2C_READ=6,
				J_ST_I2C_READ2=7,
				J_ST_I2C_READ3=8,
				J_ST_I2C_READ4=9,
				J_ST_1=10,
				J_ST_2=11,
				J_ST_3=12,
				J_ST_4=13,
				J_ST_5=14,
				J_ST_6=15,
				J_ST_7=16,
				J_ST_8=17;

// i2c part
reg i2c_we;
reg i2c_stb;
wire wb_ack_o;
wire wb_inta_o;
reg [7:0] i2c_addr;
reg [7:0] i2c_dat;
wire [7:0] wb_dat_o;

opencores_i2c i2c_inst (
   .wb_clk_i (clk),
   .wb_rst_i ( reset /* wb_rst_i */),
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

reg source_1;

/* counter and times (calculated for 50MHZ clock) */
reg [31:0] cnt;
parameter	TIME_1US=50, TIME_1MS=20000, TIME_100MS=2000000;

// SPI part
wire	spi_ack;
wire	[10:0]	buf_out_addr_spi;
reg	[10:0]	buf_out_addr;
wire	[10:0]	usb_in_addr_spi;
reg	[10:0]	usb_in_addr;
wire	usb_in_wren_spi;
reg	usb_in_wren;
wire	[10:0]	usb_in_commit_len_spi;
wire	[7:0]	usb_in_data_spi;
reg	[7:0]	usb_in_data;

joker_spi joker_spi_inst(
	.clk(clk),
	.reset(reset),
	.j_cmd(j_cmd),
	.ack_o(spi_ack),
	.buf_out_addr(buf_out_addr_spi),
	.buf_out_len(buf_out_len),
	.buf_out_q(buf_out_q),
	.usb_in_addr(usb_in_addr_spi),
	.usb_in_wren(usb_in_wren_spi),
	.usb_in_commit_len(usb_in_commit_len_spi),
	.usb_in_data(usb_in_data_spi),
	.FLASH_SCLK(FLASH_SCLK),
	.FLASH_MOSI(FLASH_MOSI),
	.FLASH_MISO(FLASH_MISO),
	.FLASH_nCS(FLASH_nCS)	
);

// CI part
wire	ci_ack;
wire	[10:0]	buf_out_addr_ci;
wire	[10:0]	usb_in_addr_ci;
wire	usb_in_wren_ci;
wire	[10:0]	usb_in_commit_len_ci;
wire	[7:0]	usb_in_data_ci;

joker_ci joker_ci_inst(
	.clk(clk),
	.reset(reset),
	.ci_do_reset(ci_do_reset),
	.j_cmd(j_cmd),
	.ack_o(ci_ack),
	.buf_out_addr(buf_out_addr_ci),
	.buf_out_len(buf_out_len),
	.buf_out_q(buf_out_q),
	.usb_in_addr(usb_in_addr_ci),
	.usb_in_wren(usb_in_wren_ci),
	.usb_in_commit_len(usb_in_commit_len_ci),
	.usb_in_data(usb_in_data_ci),
	
	// only first CI (cia) used
	.ci_ireq_n(ci_ireq_n),
	.ci_cd1(ci_cd1),
	.ci_cd2(ci_cd2),
	.ci_overcurrent_n (ci_overcurrent_n),
	.ci_reset_oe_n(ci_reset_oe_n),
	.ci_reset(ci_reset),
	.ci_data_buf_oe_n(ci_data_buf_oe_n),
	.ci_a(ci_a),
	.ci_d(ci_d),
	.ci_bus_dir(ci_bus_dir),
	.ci_wait_n(ci_wait_n),
	.ci_iowr_n(ci_iowr_n),
	.ci_iord_n(ci_iord_n),
	.ci_oe_n(ci_oe_n),
	.ci_we_n(ci_we_n),
	.cam0_ready(cam0_ready),
	.cam0_fail(cam0_fail),
	// .cam0_bypass(probe[11]),
	.ci_d_en(ci_d_en),
	.ci_reg_n(ci_reg_n),
	.ci_ce_n(ci_ce_n)	
);

// TS PID filtering 
wire	ts_filter_ack;
wire	[10:0]	buf_out_addr_ts_filter;

joker_ts_filter_control joker_ts_filter_control_inst(
	.clk(clk),
	.reset(reset),
	.ack_o(ts_filter_ack),
	.j_cmd(j_cmd),
	.buf_out_addr(buf_out_addr_ts_filter),
	.buf_out_q(buf_out_q),
	.table_wr_address(table_wr_address),
	.table_data(table_data),
	.table_wren(table_wren)
);

// TS part
wire	ts_ack;
wire	[10:0]	usb_in_commit_len_ts;
wire	[10:0]	buf_out_addr_ts;
wire	[10:0]	usb_in_addr_ts;
wire	usb_in_wren_ts;
wire	[7:0]	usb_in_data_ts;


joker_control_ts joker_control_ts_inst(
	.clk(clk),
	.reset(reset),
	.j_cmd(j_cmd),
	.ack_o(ts_ack),

	.usb_in_addr(usb_in_addr_ts),
	.usb_in_wren(usb_in_wren_ts),
	.usb_in_commit_len(usb_in_commit_len_ts),
	.usb_in_data(usb_in_data_ts),
	.ts_usb_data(ts_usb_data),
	.ts_usb_writereq(ts_usb_writereq),
	.ts_usb_almost_full(ts_usb_almost_full),
	
	/* EP4 OUT. TS from host, bulk */
   .ep4_buf_out_hasdata(ep4_buf_out_hasdata), 
	.ep4_buf_out_len(ep4_buf_out_len), 
	.ep4_buf_out_q(ep4_buf_out_q),
	.ep4_buf_out_addr(ep4_buf_out_addr),
	.ep4_buf_out_arm_ack(ep4_buf_out_arm_ack),
	.ep4_buf_out_arm(ep4_buf_out_arm)
);

/* mux usb EP's between submodules */
assign	buf_out_addr_o = (j_cmd == J_CMD_TS_FILTER) ? buf_out_addr_ts_filter :
								(j_cmd == J_CMD_SPI) ? buf_out_addr_spi : 
								(j_cmd == J_CMD_CI_RW) ? buf_out_addr_ci :  buf_out_addr;
assign	usb_in_addr_o = (j_cmd == J_CMD_SPI) ? usb_in_addr_spi :
								(j_cmd == J_CMD_CI_RW) ? usb_in_addr_ci : usb_in_addr;
assign	usb_in_wren_o = (j_cmd == J_CMD_SPI) ? usb_in_wren_spi : 
								(j_cmd == J_CMD_CI_RW) ? usb_in_wren_ci : usb_in_wren;
assign	usb_in_data_o = (j_cmd == J_CMD_SPI) ? usb_in_data_spi : 
								(j_cmd == J_CMD_CI_RW) ? usb_in_data_ci : usb_in_data;



always @(posedge clk) 
begin
	// detect reset
   reset_prev <= reset;
   if (~reset && reset_prev)
      c_state <= ST_RESET;
	
	// detect EP2 ack
	buf_out_arm_ack_prev <= buf_out_arm_ack;
	
	/* EP1 commit acked */
	if (usb_in_commit_ack_prev && ~usb_in_commit_ack)
	begin	
		usb_in_commit <= 0;
	end
	usb_in_commit_ack_prev <= usb_in_commit_ack;
	cnt <= cnt + 1;
	ci_do_reset <= 0;
	   
   case(c_state)
   ST_RESET:
   begin
		cnt <= 0;
		buf_out_addr <= 0;
		buf_out_arm <= 0;
		ci_do_reset <= 0;
		// probe <= 0;
		c_state <= ST_IDLE;
		j_cmd <= 0;
		j_state <= 0;
		i2c_we <= 0;
		i2c_stb <= 0;
		i2c_addr <= 0;
		i2c_dat <= 0;
		usb_in_wren <= 0;
		usb_in_commit <= 0;
		usb_in_addr <= 0;
		usb_in_data <= 0;
		usb_in_commit_len <= 0;
		ep3_buf_out_clear <= 0;
		ep4_buf_out_clear <= 0;
		/* '1' - mean in reset state
		 * '0' - mean in unreset state
		 * bit:
		 *  7 - Sony tuner i2c gate
		 *  6 - CI power
		 *  5 - 5V power for TERR antenna
		 *  4 - USB phy (always on ! )
		 *  3 - Altobeam demod
		 *  2 - LG demod
		 *  1 - Sony tuner
		 *  0 - Sony demod
		 * Note: 5V tps for TERR antenna disabled by default. Can cause shorts with passive antenna */
		reset_ctrl <= 8'hBF; /* unreset CI power by default */ 
		insel <= 0;
		isoc_commit_len <= 11'd512;
		ts_ci_enable <= 0;
		fifo_aclr <= 0;
		reconfig <= 0;
   end
   
   ST_IDLE:
   begin
		if (buf_out_hasdata) 
		begin
			cnt <= 0;
			c_state <= ST_READ_CMD;
		end
   end
	
	ST_READ_CMD:
   begin
		if (cnt > 2) begin
			j_cmd <= buf_out_q[7:0];
			c_state <= ST_CMD;
			j_state <= J_ST_DEFAULT;
			cnt <= 0;
		end
		else
			buf_out_addr <= 0;
	end
	
	ST_CMD:
	begin
		/********** J_CMD_I2C_WRITE **********/
		case(j_cmd)
		J_CMD_I2C_WRITE:
		begin
			case(j_state)
			J_ST_I2C_WRITE:
			begin
				if (cnt > 2)
				begin
				i2c_addr <= buf_out_q[7:0]; /* data from addr=1 */
				j_state <= J_ST_I2C_WRITE2;
				buf_out_addr <= 2;
				cnt <= 0;
				end
			end
			J_ST_I2C_WRITE2:
			begin
				if (cnt > 2)
				begin
					i2c_dat <= buf_out_q[7:0]; /* data from addr=2 */
					j_state <= J_ST_I2C_WRITE3;
				end
			end
			J_ST_I2C_WRITE3:
			begin
				i2c_we <= 1'b1;
				i2c_stb <= 1'b1;
				j_state <= J_ST_I2C_WRITE_WAIT_ACK;
			end	
			J_ST_I2C_WRITE_WAIT_ACK:
			begin
				if ( wb_ack_o || cnt > TIME_100MS /* can't wait more */) begin
					/* remove write request from wishbone */
					i2c_we <= 0;
					i2c_stb <= 0;
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				buf_out_addr <= 1; /* data will be available on next clk */
				cnt <= 0;
				j_state <= J_ST_I2C_WRITE;
			end
			default: j_state <= J_ST_DEFAULT;
			endcase
		end
		
		/********** J_CMD_I2C_READ **********/
		J_CMD_I2C_READ:
		begin
			// probe[15:8] <= j_cmd;
			case(j_state)
			J_ST_I2C_READ:
			begin
				if (cnt > 2)
				begin
					i2c_addr <= buf_out_q[7:0]; /* data from addr=1 */	
					cnt <= 0;
					usb_in_addr <= 1;
					j_state <= J_ST_I2C_READ2;
				end
			end
			J_ST_I2C_READ2:
			begin
				if (cnt > 3)
				begin
					usb_in_data <= wb_dat_o;
					cnt <= 0;
					j_state <= J_ST_I2C_READ3;
				end
			end
			J_ST_I2C_READ3:
			begin
				if (cnt > 2)
				begin
					usb_in_commit <= 1;
					usb_in_wren <= 0;
					j_state <= J_ST_I2C_READ4;
					cnt <= 0;
				end
			end
			J_ST_I2C_READ4:
			begin
				if(cnt > 4)
				begin
				c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				if(usb_in_ready) /*prevent owerwriting; may cause lock */
				begin
					buf_out_addr <= 1; /* addr */
					/* jcmd code in reply */
					usb_in_addr <= 0;
					usb_in_data = J_CMD_I2C_READ;
					usb_in_wren <= 1;
					
					i2c_we <= 0;
					i2c_stb <= 0;
					cnt <= 0;
					usb_in_commit_len <= 2;
					j_state <= J_ST_I2C_READ;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end

		/********** J_CMD_RESET_CTRL_WRITE **********/
		J_CMD_RESET_CTRL_WRITE:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					/* if CAM module poweron detected */
					if (reset_ctrl[6] && !buf_out_q[6])
						ci_do_reset <= 1;
					c_state <= ST_CMD_DONE; /* wait next cmd */
					reset_ctrl <= buf_out_q[7:0]; /* data from addr=1 */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					buf_out_addr <= 1; /* addr */
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end
	
		/********** J_CMD_TS_FILTER **********/
		J_CMD_TS_FILTER:
		begin
			case(j_state)
			J_ST_1:
			begin
				if(ts_filter_ack)
				begin
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				if(usb_in_ready) /*prevent owerwriting; may cause lock */
				begin
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end		
		
		/********** J_CMD_TS_INSEL_WRITE **********/
		J_CMD_TS_INSEL_WRITE:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					insel <= buf_out_q[7:0]; /* data from addr=1 */	
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					buf_out_addr <= 1; /* addr */
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end
		
		/********** J_CMD_ISOC_LEN_WRITE_HI **********/
		J_CMD_ISOC_LEN_WRITE_HI:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					isoc_commit_len[10:8] <= buf_out_q[2:0]; /* data from addr=1 */	
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					buf_out_addr <= 1; /* addr */
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end
		
		/********** J_CMD_ISOC_LEN_WRITE_LO **********/
		J_CMD_ISOC_LEN_WRITE_LO:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					isoc_commit_len[7:0] <= buf_out_q[7:0]; /* data from addr=1 */	
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					buf_out_addr <= 1; /* addr */
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end
		
		/********** J_CMD_CI_STATUS **********/
		J_CMD_CI_STATUS:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					usb_in_addr <= 1;
					usb_in_data <= {cam0_fail, cam0_ready};
					cnt <= 0;
					j_state <= J_ST_2;
				end
			end
			J_ST_2:
			begin
				if (cnt > 2)
				begin
					usb_in_commit <= 1;
					usb_in_wren <= 0;
					c_state <= ST_CMD_DONE; /* wait next cmd */
					cnt <= 0;
				end
			end
			J_ST_DEFAULT: 
			begin
				if(usb_in_ready) /*prevent owerwriting; may cause lock */
				begin
					/* jcmd code in reply */
					usb_in_addr <= 0;
					usb_in_data = J_CMD_CI_STATUS;
					usb_in_wren <= 1;
					cnt <= 0;
					usb_in_commit_len <= 2;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end			
		
		/********** J_CMD_CLEAR_TS_FIFO **********/
		J_CMD_CLEAR_TS_FIFO:
		begin
			case(j_state)
			J_ST_1:
			begin
				// clear FIFO
				fifo_aclr <= 1;
				// clear collected TS data from EP3 buffers
				ep3_buf_out_clear <= 1;
				ep4_buf_out_clear <= 1;
				j_state <= J_ST_2;
				cnt <= 0;
			end
			J_ST_2:
			begin
				if (cnt > 2) begin
					fifo_aclr <= 0;
					ep3_buf_out_clear <= 0;
					ep4_buf_out_clear <= 0;
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end		
		
		/********** J_CMD_REBOOT **********/
		J_CMD_REBOOT:
		begin
			case(j_state)
			J_ST_1:
			begin
				reconfig <= 1;
				c_state <= ST_CMD_DONE; /* wait next cmd */
			end
			J_ST_DEFAULT: 
			begin
				begin
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end
		

		/********** J_CMD_CI_TS **********/
		J_CMD_CI_TS:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					if(buf_out_q[0])
						ts_ci_enable <= 1;
					else
						ts_ci_enable <= 0;
					c_state <= ST_CMD_DONE; /* wait next cmd */
				end
			end
			J_ST_DEFAULT: 
			begin
				begin
					buf_out_addr <= 1; /* addr */
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end		
		
		/********** J_CMD_CI_RW **********/
		J_CMD_CI_RW:
		begin
			case(j_state)
			J_ST_1:
			begin
				if(ci_ack)
				begin
					usb_in_commit_len <= usb_in_commit_len_ci;
					usb_in_commit <= 1;
					c_state <= ST_CMD_DONE; /* wait next cmd */
					cnt <= 0;
				end
			end
			J_ST_DEFAULT: 
			begin
				if(usb_in_ready) /*prevent owerwriting; may cause lock */
				begin
					buf_out_addr <= 1; /* addr */
					/* jcmd code in reply */
					usb_in_addr <= 0;
					usb_in_data = J_CMD_CI_RW;
					usb_in_wren <= 1;
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end	

		/********** J_CMD_SPI **********/
		J_CMD_SPI:
		begin
			case(j_state)
			J_ST_1:
			begin
				if(spi_ack)
				begin
					usb_in_commit_len <= usb_in_commit_len_spi;
					usb_in_commit <= 1;
					c_state <= ST_CMD_DONE; /* wait next cmd */
					cnt <= 0;
				end
			end
			J_ST_DEFAULT: 
			begin
				if(usb_in_ready) /*prevent owerwriting; may cause lock */
				begin
					buf_out_addr <= 1; /* addr */
					/* jcmd code in reply */
					usb_in_addr <= 0;
					usb_in_data = J_CMD_SPI;
					usb_in_wren <= 1;
					cnt <= 0;
					j_state <= J_ST_1;
				end
			end
			default:	j_state <= J_ST_DEFAULT;
			endcase
		end		
		
		/* END JCMD */
		default: c_state <= ST_CMD_DONE;
		endcase // case(j_cmd)
	end
	ST_CMD_DONE:
	begin
		j_state <= 0;
		j_cmd <= 0;
		// tell EP2 OUT that we don't need this data anymore
		buf_out_arm <= 1;
		if ( ~buf_out_arm_ack && buf_out_arm_ack_prev ) begin
			buf_out_arm <= 0;
			c_state <= ST_IDLE;
		end
	end
   default: c_state <= ST_IDLE;
	endcase // case(c_state)
end

endmodule
