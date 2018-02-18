//
// Joker TV
// TS traffic from host in USB bulk transfers
//
// (c) Abylay Ospan, 2017
// aospan@jokersys.com
// https://jokersys.com
// GPLv2

module joker_control_ts
(
	input		wire	clk,
	input		wire	reset,
	
	input		wire	[7:0] j_cmd,
	output	reg	ack_o,
	
	/* EP4 OUT, TS from host, bulk  */
   input    wire  ep4_buf_out_hasdata, 
	input		wire	[10:0] ep4_buf_out_len, 
	input		wire	[7:0] ep4_buf_out_q,
	output	reg	[10:0] ep4_buf_out_addr,
	input		wire	ep4_buf_out_arm_ack,
	output	reg	ep4_buf_out_arm,		

	/* EP1 IN */
   input    wire  usb_in_commit_ack,
	input           wire    usb_in_ready,
   output   reg  usb_in_commit,
	output  reg     [ 10:0]   usb_in_addr,
	output  reg     [ 7:0]   usb_in_data,
	output  reg     usb_in_wren,
	output  reg     [ 10:0]   usb_in_commit_len,	

	/* TS traffic from USB bulk transfers */
	output	reg	[7:0]	ts_usb_data,
	output	reg	ts_usb_writereq,
	input		wire	ts_usb_almost_full,
	
	output	reg	[29:0]	total_bytes
);

`include "joker_control.vh"

// CI part (Common Interface)
reg	[10:0] ts_size;
reg	[7:0] ms; // milliseconds
reg	[15:0] ms_cnt;
reg   [15:0] cnt;
reg	[15:0] processed;
reg	ep4_buf_out_arm_ack_prev;

/* state machine */
reg [7:0] ts_state;

parameter	ST_TS_IDLE=0,
				ST_TS_PREPARE=1,
				ST_TS_PROCESS0=6,
				ST_TS_PROCESS=7,
				ST_TS_FINISH=8,
				ST_TS_WRITE_FIFO=9
				;

always @(posedge clk) begin
	cnt <= cnt + 1;
	
	// detect EP4 ack
	ep4_buf_out_arm_ack_prev <= ep4_buf_out_arm_ack;
	
	// update milliseconds counter
	if (ms_cnt == 60240) // for 60MHz clock, 16.6ns tick
	begin
		ms_cnt <= 0;
		ms <= ms + 1;
	end else begin
		ms_cnt <= ms_cnt + 1;
	end
	
	case(ts_state)
	ST_TS_PREPARE:
	begin
		ts_size <= 0;		
		ts_state <= ST_TS_IDLE;
		ack_o <= 0;
		ms <= 0;
		ms_cnt <= 0;
		processed <= 0;
		ts_usb_writereq <= 0;
		ts_usb_data <= 0;
		ep4_buf_out_arm_ack_prev <= 0;
	end
	
	ST_TS_IDLE:
	begin
		if (ep4_buf_out_hasdata) begin
			ep4_buf_out_addr <= 0;
			cnt <= 0;
			processed <= 0;
			ms <= 0;
			ts_size <= ep4_buf_out_len;
			ts_state <= ST_TS_PROCESS0;
		end
	end
	ST_TS_PROCESS0:
	begin
		if (cnt > 2) begin
			ts_state <= ST_TS_PROCESS;
		end
	end
	ST_TS_PROCESS:
	begin
		if (processed < ts_size && ms < 100) begin
			if (~ts_usb_almost_full) begin
				ts_usb_data <= ep4_buf_out_q[7:0];
				ts_usb_writereq <= 1;
				processed <= processed + 1;
				ep4_buf_out_addr <= ep4_buf_out_addr + 1;
				ts_state <= ST_TS_WRITE_FIFO;
				total_bytes <= total_bytes + 1;
			end else
				ts_usb_writereq <= 0;
		end else begin
			ts_usb_writereq <= 0;
			// all done
			ts_state <= ST_TS_FINISH;
		end
	end
	ST_TS_WRITE_FIFO:
	begin
		ts_state <= ST_TS_PROCESS;
		ts_usb_writereq <= 0;
	end
	ST_TS_FINISH:
	begin
		// drop EP4 data now
		ep4_buf_out_arm <= 1;
		if ( ~ep4_buf_out_arm_ack && ep4_buf_out_arm_ack_prev ) begin
			ep4_buf_out_arm <= 0;
			ts_state <= ST_TS_IDLE;
		end
	end
	default: ts_state <= ST_TS_IDLE;
	endcase
	
	if (reset)
	begin
		ts_state <= ST_TS_PREPARE;
	end
end

endmodule
