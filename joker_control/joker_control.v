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
	
	/* staff that we care about */
	output	reg	[7:0]	reset_ctrl,
	output	reg	[7:0]	insel,
	output	reg	[10:0] isoc_commit_len
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
				J_CMD_ISOC_LEN_WRITE_LO=17
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
				J_ST_1=10;

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

/* counter and times (calculated for 50MHZ clock) */
reg [31:0] cnt;
parameter	TIME_1US=50, TIME_1MS=20000, TIME_100MS=2000000;

reg [31:0] source;
reg [31:0] probe;

/*
`ifndef MODEL_TECH
probe	probe_inst(
	.probe( probe ),
	.source(source)
);
`endif
*/

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
		// usb_in_wren <= 0;
	end
	usb_in_commit_ack_prev <= usb_in_commit_ack;
		
	cnt <= cnt + 1;
	
	probe[10:0] <= isoc_commit_len;
   
   case(c_state)
   ST_RESET:
   begin
		cnt <= 0;
		buf_out_addr <= 0;
		buf_out_arm <= 0;
		probe <= 0;
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
		reset_ctrl <= 8'hB3;
		insel <= 0;
		isoc_commit_len <= 11'd512;
   end
   
   ST_IDLE:
   begin
		if (buf_out_hasdata) begin
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