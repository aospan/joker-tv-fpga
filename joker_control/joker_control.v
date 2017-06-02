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
	
	/* EP2 OUT */
   input    wire  buf_out_hasdata, 
	input		wire	[9:0] buf_out_len, 
	input		wire	[7:0] buf_out_q,
	output	reg	[10:0] buf_out_addr,
	input		wire	buf_out_arm_ack,
	output	reg	buf_out_arm,
	
	/* EP1 IN */
   input    wire  usb_in_commit_ack,
	input		wire	usb_in_ready,
   output   reg  usb_in_commit,
	output	reg	[ 10:0]   usb_in_addr,
	output	reg	[ 7:0]   usb_in_data,
	output	reg	usb_in_wren,
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
	output	wire	ci_oe_n,
	output	wire	ci_we_n,
	output	wire	ci_d_en,
	output	wire	ci_reg_n,
	output	wire	ci_ce_n,
	
	/* staff that we care about */
	output	reg	[7:0]	reset_ctrl,
	output	reg	[7:0]	insel,
	output	reg	[10:0] isoc_commit_len,
	output	wire	cam0_ready,
	output	wire	cam0_fail
);

reg   reset_prev;
reg	buf_out_arm_ack_prev;
reg	usb_in_commit_ack_prev;

// joker commands
reg	[7:0]	j_cmd;
parameter 	J_CMD_VERSION=0, /* return fw version */
				J_CMD_I2C_WRITE=10, /* i2c read/write */				
				J_CMD_I2C_READ=11,
				J_CMD_RESET_CTRL_WRITE=12, /* reset control register  r/w */
				J_CMD_RESET_CTRL_READ=13,
				J_CMD_TS_INSEL_WRITE=14, /* ts input select */
				J_CMD_TS_INSEL_READ=15,
				J_CMD_ISOC_LEN_WRITE_HI=16, /* USB isoc transfers length */
				J_CMD_ISOC_LEN_WRITE_LO=17,
				J_CMD_CI_STATUS=20, /* CI - common interface */
				J_CMD_CI_READ_MEM=21, 
				J_CMD_CI_WRITE_MEM=22
				;

// main states
reg [3:0] c_state = 4'b0000;
parameter ST_RESET=0, ST_IDLE=1, ST_CMD=2, ST_CMD_DONE=3, ST_READ_CMD=4;

// states inside j_cmd processing
reg [3:0] j_state = 4'b0000;
parameter	J_ST_DEFAULT=0,
				J_ST_I2C_WRITE=1, 
				J_ST_I2C_WRITE2=2,
				J_ST_I2C_WRITE3=3,
				J_ST_I2C_WRITE_WAIT_ACK=4,
				J_ST_I2C_READ=5,
				J_ST_I2C_READ2=6,
				J_ST_I2C_READ3=7,
				J_ST_I2C_READ4=8,
				J_ST_1=10,
				J_ST_2=11,
				J_ST_3=12,
				J_ST_4=13;

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

// CI part (Common Interface)
reg 	cam_read;
wire	cam_waitreq;
reg	[7:0]	cam_readdata;
reg	[17:0] cam_address;

ci_bridge ci_bridge_inst (
	.clk(clk),
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
	.cam0_ready(cam0_ready),
	.cam0_fail(cam0_fail),
	// .cam0_bypass(probe[11]),
	.ci_d_en(probe[8] /* ci_d_en */),
	.cam_readdata(cam_readdata),
	.cam_read(cam_read),
	.cam_waitreq(cam_waitreq),
	.cam_address(cam_address),
	.ci_reg_n(ci_reg_n),
	.cia_ce_n(ci_ce_n)	
);

reg source_1;

/* counter and times (calculated for 50MHZ clock) */
reg [31:0] cnt;
parameter	TIME_1US=50, TIME_1MS=20000, TIME_100MS=2000000;

reg [31:0] source;
reg [31:0] probe;

`ifndef MODEL_TECH
probe	probe_inst(
	.probe( probe ),
	.source(source)
);
`endif

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
	
	probe[7:0] <= reset_ctrl;
	probe[9] <= cam0_ready;
	probe[10] <= cam0_fail;
	probe[23:16] <= c_state;
	   
   case(c_state)
   ST_RESET:
   begin
		cnt <= 0;
		buf_out_addr <= 0;
		buf_out_arm <= 0;
		// probe <= 0;
		c_state <= ST_IDLE;
		j_cmd <= 0;
		i2c_we <= 0;
		i2c_stb <= 0;
		i2c_addr <= 0;
		i2c_dat <= 0;
		usb_in_wren <= 0;
		usb_in_commit <= 0;
		usb_in_addr <= 0;
		usb_in_data <= 0;
		usb_in_commit_len <= 0;
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
		cam_read <= 0;
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
					reset_ctrl <= buf_out_q[7:0]; /* data from addr=1 */	
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
		
		/********** J_CMD_CI_READ_MEM **********/
		J_CMD_CI_READ_MEM:
		begin
			case(j_state)
			J_ST_1:
			begin
				if (cnt > 2)
				begin
					cam_address <= buf_out_q[7:0]; /* data from addr=1 */	
					cam_read <= 1;
					cnt <= 0;
					j_state <= J_ST_2;
				end
			end
			J_ST_2:
			begin
				if (~cam_waitreq)
				begin
					cam_read <= 0;
					usb_in_addr <= 1;
					usb_in_data <= cam_readdata;
					cnt <= 0;
					j_state <= J_ST_3;
				end
			end
			J_ST_3:
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
					buf_out_addr <= 1; /* addr */
					/* jcmd code in reply */
					usb_in_addr <= 0;
					usb_in_data = J_CMD_CI_READ_MEM;
					usb_in_wren <= 1;
					cnt <= 0;
					usb_in_commit_len <= 2;
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