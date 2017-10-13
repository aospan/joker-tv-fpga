//
// Joker TV
// CI EN50221 stuff
// (c) Abylay Ospan, 2017
// aospan@jokersys.com
// https://jokersys.com
// GPLv2

module joker_ci
(
	input		wire	clk,
	input		wire	reset,
	input		wire	ci_do_reset, // separate reset for CAM
	
	input		wire	[7:0] j_cmd,
	output	reg	ack_o,
	
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

	output	reg	[7:0]	ci_command,
	output	reg	[7:0]	ci_command_rw, // read-write copy

	output	wire	cam0_ready,
	output	wire	cam0_fail
);

`include "joker_control.vh"

// CI part (Common Interface)
reg 	cam_read;
reg 	cam_write;
wire	cam_waitreq;
wire	[7:0]	cam_readdata;
reg	[17:0] cam_address;
reg	[7:0] cam_writedata;


reg	[15:0]	ci_off;
reg	[15:0]	ci_size;
reg	[7:0]		ci_result;
reg	[15:0]	ci_len;
reg	[15:0]	processed;
reg	[15:0] cnt;
reg	[15:0] ms; // milliseconds
reg	[15:0] ms_cnt;
wire	[7:0] ci_d_out;
wire	[7:0] ci_d_in;



ci_bridge ci_bridge_inst (
	.clk(clk),
	.rst(ci_do_reset /* reset */),
	
	/* only first CI (cia) used */
	.cia_ireq_n(ci_ireq_n),
	.cia_cd_n( {ci_cd1, ci_cd2} ),
	.cia_overcurrent_n (ci_overcurrent_n),
	.cia_reset_buf_oe_n(ci_reset_oe_n),
	.cia_reset(ci_reset),
	.cia_data_buf_oe_n(ci_data_buf_oe_n),
	.ci_a(ci_a),
	.ci_d_in(ci_d_in),
	.ci_d_out(ci_d_out),
	.ci_bus_dir(ci_bus_dir),
	.cia_wait_n(ci_wait_n),
	.ci_iowr_n(ci_iowr_n),
	.ci_iord_n(ci_iord_n),
	.ci_oe_n(ci_oe_n),
	.ci_we_n(ci_we_n),
	.cam0_ready(cam0_ready),
	.cam0_fail(cam0_fail),
	// .cam0_bypass(probe[11]),
	.ci_d_en(ci_d_en),
	.cam_readdata(cam_readdata),
	.cam_writedata(cam_writedata),
	.cam_read(cam_read),
	.cam_write(cam_write),
	.cam_waitreq(cam_waitreq),
	.cam_address(cam_address),
	.ci_reg_n(ci_reg_n),
	.cia_ce_n(ci_ce_n)	
);

/* mux in/out for ci data */
assign	ci_d = (ci_d_en) ? ci_d_out : 'bz;
assign	ci_d_in = ci_d;

/* other stuff */
reg	[7:0]	waitfor;
reg	[7:0]	cam_readdata_store;


/* state machine */
reg [7:0] ci_state;
reg [7:0] ci_next_state;
reg [7:0] ci_next_state_rw;
reg [7:0] ci_next_state_status;
reg [7:0] ci_next_state_waitfor;

parameter	ST_CI_IDLE=0,
				ST_CI_PREPARE=1,
				ST_CI_READ_COMMAND=2,
				ST_CI_READ_SIZE_HIGH=3,
				ST_CI_READ_SIZE_LOW=4,
				ST_CI_READ_OFFSET_HIGH=5,
				ST_CI_READ_OFFSET_LOW=6,
				ST_CI_PROCESS=7,
				ST_CI_CYCLE=8,
				ST_CI_IO_CYCLE=9,
				ST_CI_DO_RW=10,
				ST_CI_DO_RW_WAIT=11,
				ST_CI_DO_RW_DONE=12,
				ST_CI_WRITE_RESULT=13,
				ST_CI_WRITE_LEN_HIGH=14,
				ST_CI_WRITE_LEN_LOW=15,
				ST_CI_FINISH=16,
				ST_CI_WAITFOR=17,
				ST_CI_IO_SET_HC=18,
				ST_CI_IO_WAIT_FR=19,
				ST_CI_IO_WRITE_SIZE_HIGH=20,
				ST_CI_IO_WRITE_SIZE_LOW=21,
				ST_CI_IO_WRITE_DATA=22,
				ST_CI_IO_CHECK_WE=23,
				ST_CI_READ_STATUS=24
				;

always @(posedge clk) begin
	cnt <= cnt + 1;
	
	// update milliseconds counter
	if (ms_cnt == 60240) // for 60MHz clock, 16.6ns tick
	begin
		ms_cnt <= 0;
		ms <= ms + 1;
	end else begin
		ms_cnt <= ms_cnt + 1;
	end
	
	case(ci_state)
	ST_CI_PREPARE:
	begin
		cam_address <= 0;
		ci_command <= 8'h0;
		ci_command_rw <= 8'h0;
		ci_off <= 0;
		ci_size <= 0;		
		ci_state <= ST_CI_IDLE;
		ack_o <= 0;
		cam_read <= 0;
		cam_write <= 0;
		ci_len <= 0;
		processed <= 0;
		ms <= 0;
		ms_cnt <= 0;
		ci_result <= 8'h2; // 2 - OK, 1 - ERROR, 3 - TIMEOUT
	end
	
	ST_CI_IDLE:
	begin
		if(j_cmd == J_CMD_CI_RW)
		begin
			/* process CI rw */
			cnt <= 0;
			ci_state <= ST_CI_READ_COMMAND;
			buf_out_addr <= 1; /* read command */
		end
	end
	ST_CI_READ_COMMAND:
	begin
		if (cnt > 2)
		begin
			usb_in_wren <= 0;
			ci_command[7:0] <= buf_out_q[7:0];
			ci_command_rw[7:0] <= buf_out_q[7:0];
			ci_state <= ST_CI_READ_SIZE_HIGH;
			cnt <= 0;
			buf_out_addr <= 2; /* read size HIGH */
		end
	end
	ST_CI_READ_SIZE_HIGH:
	begin
		if (cnt > 2)
		begin
			ci_size[15:8] <= buf_out_q[7:0];
			ci_state <= ST_CI_READ_SIZE_LOW;
			cnt <= 0;
			buf_out_addr <= 3; /* read size LOW */
		end
	end
	ST_CI_READ_SIZE_LOW:
	begin
		if (cnt > 2)
		begin
			ci_size[7:0] <= buf_out_q[7:0];
			ci_state <= ST_CI_READ_OFFSET_HIGH;
			cnt <= 0;
			buf_out_addr <= 4; /* read offset HIGH */
		end
	end	
	ST_CI_READ_OFFSET_HIGH:
	begin
		if (cnt > 2)
		begin
			ci_off[15:8] <= buf_out_q[7:0];
			ci_state <= ST_CI_READ_OFFSET_LOW;
			cnt <= 0;
			buf_out_addr <= 5; /* read off LOW */
		end
	end
	ST_CI_READ_OFFSET_LOW:
	begin
		if (cnt > 2)
		begin
			ci_off[7:0] <= buf_out_q[7:0];
			ci_state <= ST_CI_PROCESS;
			cnt <= 0;
		end
	end
	ST_CI_PROCESS:
	begin
		if (ci_command[4]) begin
			// this is "bulk" rw
			ci_state <= ST_CI_IO_CYCLE;
		end else begin
			processed <= 0;
			ci_state <= ST_CI_CYCLE; 			
		end
		cnt <= 0;
		usb_in_addr <= 3; // we send data back to host starting from offset 4
		buf_out_addr <= 6; // we read data from offset 6
	end
	// mem/io access: simple read/write to offsets
	ST_CI_CYCLE:
	begin
		if (processed < ci_size) begin
			// do actual IO in cycle starting from offset
			cam_address[14:0] <= ci_off[14:0];
			ci_off <= ci_off + 1;
			ci_state <= ST_CI_DO_RW;
			ci_next_state_rw <= ST_CI_CYCLE;
			processed <= processed + 1;
			usb_in_addr <= usb_in_addr + 1;
			buf_out_addr <= buf_out_addr + 1;
		end else begin
			// all data processed
			ci_len <= ci_size;
			ci_result <= 2; // 2 - OK, 1 - ERROR
			ci_state <= ST_CI_WRITE_RESULT;			
		end
	end
	
	/****** io access: write bulk amount of data ******/
	// Full io write sequence	
	// * wait FR (free) bit
	// * set HC bit
	// * wait FR (free) bit
	// * write size HIGH/LOW first
	// * write all data to offset 0
	// * check if WE bit set ?
	ST_CI_IO_CYCLE:
	begin
		waitfor <= 8'h40; // wait FREE bit
		cam_readdata_store <= 0;
		// start timer
		ms_cnt <= 0;
		ms <= 0;
		ci_state <= ST_CI_WAITFOR;
		ci_next_state_waitfor <= ST_CI_IO_SET_HC;
	end
	ST_CI_IO_SET_HC:
	begin
		if (ci_result == 3) begin
			ci_state <= ST_CI_WRITE_RESULT; // exit because timeout
		end else begin
			// write HC bit to command reg
			// io access	
			cam_address[15] <= 1'b1; // io	
			cam_address[14:0] <= 1; // command reg offset
			ci_command_rw <= 8'h6; // WRITE | IO
			cam_write <= 1;
			cam_read <= 0;
			cam_writedata[7:0] <= 8'h81; // HC bit + interrupt bit
			ci_state <= ST_CI_DO_RW_WAIT;
			ci_next_state_rw <= ST_CI_IO_WAIT_FR;			
		end
	end
	ST_CI_IO_WAIT_FR:
	begin
		waitfor <= 8'h40; // wait FREE bit
		// start timer
		ms_cnt <= 0;
		ms <= 0;
		ci_state <= ST_CI_WAITFOR;
		ci_next_state_waitfor <= ST_CI_IO_WRITE_SIZE_HIGH;
	end
	ST_CI_IO_WRITE_SIZE_HIGH:
	begin
		if (ci_result == 3) begin
			ci_state <= ST_CI_WRITE_RESULT; // exit because timeout
		end else begin
			// io access	
			cam_address[15] <= 1'b1; // io	
			cam_address[14:0] <= 3; // size HIGH reg offset
			ci_command_rw <= 8'h6; // WRITE | IO 
			cam_write <= 1;
			cam_read <= 0;
			cam_writedata[7:0] <= ci_size[15:8];
			ci_state <= ST_CI_DO_RW_WAIT;
			ci_next_state_rw <= ST_CI_IO_WRITE_SIZE_LOW;	
		end
	end
	ST_CI_IO_WRITE_SIZE_LOW:
	begin
			// io access	
			cam_address[15] <= 1'b1; // io	
			cam_address[14:0] <= 2; // size LOW reg offset
			ci_command_rw <= 8'h2; // signal write 
			cam_write <= 1;
			cam_read <= 0;
			cam_writedata[7:0] <= ci_size[7:0];
			processed <= 0;
			cnt <= 0;
			usb_in_addr <= 3; // we send data back to host starting from offset 4
			buf_out_addr <= 6; // we read data from offset 6			
			ci_state <= ST_CI_DO_RW_WAIT;
			ci_next_state_rw <= ST_CI_IO_WRITE_DATA;
	end
	ST_CI_IO_WRITE_DATA:
	begin
		if (processed < ci_size) begin
			// do actual IO
			cam_address[14:0] <= 0; // all data goes to offset 0 (data reg)
			ci_command_rw <= 8'h6; // WRITE | IO
			ci_state <= ST_CI_DO_RW;
			ci_next_state_rw <= ST_CI_IO_WRITE_DATA;
			processed <= processed + 1;
			usb_in_addr <= usb_in_addr + 1;
			buf_out_addr <= buf_out_addr + 1;
		end else begin
			// all data processed
			ci_len <= ci_size;
			ci_result <= 2; // 2 - OK, 1 - ERROR
			ci_state <= ST_CI_READ_STATUS;	
			ci_next_state_status <= ST_CI_IO_CHECK_WE;
		end		
	end
	ST_CI_IO_CHECK_WE:
	begin
		if (cam_readdata_store[1] /* WE bit */) begin
			ci_result <= 4; // 2 - OK, 1 - ERROR, 4 - WE bit detected
		end else begin
			ci_len <= ci_size;		
			ci_result <= 2; // 2 - OK, 1 - ERROR
		end
		ci_state <= ST_CI_WRITE_RESULT;	
	end
	
	/****** this is 'sub-function' to wait specific bit in status reg ******/
	ST_CI_WAITFOR:
	begin
		if (cam_readdata_store == waitfor) begin
			ci_result <= 2; // OK
			ci_state <= ci_next_state_waitfor; // FOUND
		end else if (ms > 200) begin
			ci_result <= 3; // timeout
			ci_state <= ci_next_state_waitfor;
		end else begin
			ci_state <= ST_CI_READ_STATUS;
			ci_next_state_status <= ST_CI_WAITFOR;
		end
	end
	
	/****** this is 'sub-function' to status reg read ******/
	ST_CI_READ_STATUS:
	begin
		// io access	
		cam_address[15] <= 1'b1; // io	
		cam_address[14:0] <= 1; // status reg offset
		ci_command_rw <= 8'h5; // READ | IO
		cam_write <= 0;
		cam_read <= 1;			
		ci_state <= ST_CI_DO_RW_WAIT;
		ci_next_state_rw <= ci_next_state_status;
	end
	
	/****** this is 'sub-function' to do actual rw to CAM ******/
	ST_CI_DO_RW:
	begin
		if (ci_command_rw[3]) begin
			// mem access
			cam_address[16] <= 1'b0; // REG# always low (active) ? 
			cam_address[15] <= 1'b0; // mem 	
		end else if (ci_command_rw[2]) begin
			// io access	
			cam_address[16] <= 1'b0; // REG# always low (active) ? 
			cam_address[15] <= 1'b1; // io	
		end
		
		if (ci_command_rw[0]) begin
			// read
			cam_write <= 0;
			cam_read <= 1;		
		end else if (ci_command_rw[1]) begin
			// write
			cam_write <= 1;
			cam_read <= 0;	
			// set data
			cam_writedata[7:0] <= buf_out_q[7:0];
		end
		ci_state <= ST_CI_DO_RW_WAIT;
	end
	ST_CI_DO_RW_WAIT:
	begin
		if (~cam_waitreq) begin
			cam_write <= 0;
			cam_read <= 0;
			if (ci_command_rw[0]) begin
				//read result if this read op
				usb_in_data <= cam_readdata;
				cam_readdata_store <= cam_readdata;
				usb_in_wren <= 1;
			end
			ci_state <= ST_CI_DO_RW_DONE;
		end
	end
	ST_CI_DO_RW_DONE:
	begin
		usb_in_wren <= 0;
		ci_state <= ci_next_state_rw; // go back
	end
	
	/***** FINISH here. return back ******/
	ST_CI_WRITE_RESULT:
	begin
		usb_in_addr <= 1;
		usb_in_data <= ci_result;
		usb_in_wren <= 1;
		// clear HC Bit
		if (ci_command[4]) begin
			// this was a "bulk" rw
			// clear HC bit from command reg
			// io access	
			cam_address[15] <= 1'b1; // io	
			cam_address[14:0] <= 1; // command reg offset
			ci_command_rw <= 8'h6; // WRITE | IO 
			cam_write <= 1;
			cam_read <= 0;
			cam_writedata[7:0] <= 8'h80; // only interrupt bit
			ci_state <= ST_CI_DO_RW_WAIT;
			ci_next_state_rw <= ST_CI_WRITE_LEN_HIGH;			
		end else begin
			ci_state <= ST_CI_WRITE_LEN_HIGH;
		end
	end
	ST_CI_WRITE_LEN_HIGH:
	begin
		usb_in_addr <= 2;
		usb_in_data <= ci_len[15:8];
		ci_state <= ST_CI_WRITE_LEN_LOW;
	end
	ST_CI_WRITE_LEN_LOW:
	begin
		usb_in_addr <= 3;
		usb_in_data <= ci_len[7:0];
		ci_state <= ST_CI_FINISH;
	end
	ST_CI_FINISH:
	begin
		ack_o <= 1;
		usb_in_wren <= 0;
		usb_in_commit_len <= ci_size + 4;
		if (j_cmd != J_CMD_CI_RW) /* upper layer accept our ack */
			ci_state <= ST_CI_PREPARE;
	end
	default: ci_state <= ST_CI_IDLE;
	endcase
	
	if (reset)
	begin
		ci_state <= ST_CI_PREPARE;
	end
end

endmodule
