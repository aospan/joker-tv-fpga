/* TS PID filtering
 *
 * data flow:
 * in FIFO    -> ci_filter -> ci_ts_in -> CI bus ->	ci_ts_out -> out FIFO
 * 
 * (c) Abylay Ospan, 2017
 * Joker Systems Inc.
 * aospan@jokersys.com
 */

`timescale 1ns/100ps

module ts_filter (
	input	wire		clk,
	input	wire		reset,

	input	wire [12:0]  table_wr_address,
	input	wire [0:0]  table_data,
	input	wire	table_wren,

	/* filter input FIFO */
	input	wire	[7:0]	ts_filter_in_d,
	input	wire		ts_filter_wrreq,
	output	reg		ts_filter_almost_full,
	
	/* filtered data will appear here */
	output	reg	[7:0]	ts_filter_out_d,
	output	reg		ts_filter_out_wrreq,
	input	wire		ts_filter_out_almost_full,

	/* signal when TS packet starts */
	output	reg	pkt_start,

	input	wire	fifo_aclr
);

reg	fifo_aclr1;
reg	[7:0]	bc /* synthesis noprune */;
reg	[7:0]	dc /* synthesis noprune */;
reg	[7:0]	data5 /* synthesis noprune */;
reg	[7:0]	data4 /* synthesis noprune */;
reg	[7:0]	data3 /* synthesis noprune */;
reg	[7:0]	data2 /* synthesis noprune */;
reg	[7:0]	data1 /* synthesis noprune */;
reg	[7:0]	data0 /* synthesis noprune */;
reg	[15:0] pid/* synthesis noprune */;
reg	allowed;
wire allowed_next/* synthesis noprune */;
// PID table
reg	[12:0]  table_address;
wire	[0:0]  table_q /* synthesis noprune */;

assign table_address = pid[12:0];
assign ts_filter_almost_full = ts_filter_out_almost_full;
assign allowed_next = ~table_q;

/* state machine */
reg [7:0] ts_filter_state;
parameter ST_TS_FILTER_IDLE = 0,
	ST_TS_FILTER_READ_SYNC = 1,
	ST_TS_FILTER_READ_PID = 2,
	ST_TS_FILTER_READ_PID2 = 3,
	ST_TS_FILTER_DECIDE = 4,
	ST_TS_FILTER_PROCESS = 5,
	ST_TS_FILTER_WRITE_SYNC = 6,
	ST_TS_FILTER_WRITE_PID = 7,
	ST_TS_FILTER_WRITE_PID2 = 8,
	ST_TS_FILTER_DECIDE2 = 9
	;
	
ts_filter_table ts_filter_table_inst (
	.clock(clk),
	.rdaddress(table_address),
	.wraddress(table_wr_address),
	.data(table_data),
	.wren(table_wren),
	.q(table_q)
);

always @(posedge clk ) begin
	dc <= dc + 1;
	fifo_aclr1 <= fifo_aclr;
	
	if (ts_filter_wrreq) begin
		bc <= bc + 1;
		{data5, data4, data3, data2, data1, data0} 
		<= {data4, data3, data2, data1, data0, ts_filter_in_d};
		
		if (allowed) begin
			ts_filter_out_d <= data5;
			ts_filter_out_wrreq <= 1;
		end else
			ts_filter_out_wrreq <= 0;
	end else
		ts_filter_out_wrreq <= 0;
	
	case(ts_filter_state)
	ST_TS_FILTER_IDLE:
	begin
		if (ts_filter_wrreq && ts_filter_in_d[7:0] == 8'h47) begin
			ts_filter_state <= ST_TS_FILTER_READ_PID;
			bc <= 1;
		end
	end
	ST_TS_FILTER_READ_PID:
	begin
		if (ts_filter_wrreq) begin
			pid[15:8] <= ts_filter_in_d[7:0];
			ts_filter_state <= ST_TS_FILTER_READ_PID2;
		end
	end
	ST_TS_FILTER_READ_PID2:
	begin
		if (ts_filter_wrreq) begin
			pid[7:0] <= ts_filter_in_d[7:0];
			ts_filter_state <= ST_TS_FILTER_DECIDE;
			dc <= 0;
		end
	end
	ST_TS_FILTER_DECIDE:
	begin
		if (dc >= 2'd1) begin
			ts_filter_state <= ST_TS_FILTER_DECIDE2;
		end
	end
	ST_TS_FILTER_DECIDE2:
	begin
		if (bc == 8'd5 && ts_filter_wrreq) begin
			allowed <= allowed_next;
			ts_filter_state <= ST_TS_FILTER_PROCESS;
		end
	end
	
	ST_TS_FILTER_PROCESS:
	begin
		if (bc == 8'd6 && allowed && ts_filter_wrreq)
				pkt_start <= 1;
		else
			pkt_start <= 0;
			
		if (bc == 8'd187 && ts_filter_wrreq) begin
			bc <= 0;
			ts_filter_state <= ST_TS_FILTER_IDLE;
		end
	end
	endcase

	// reset or FIFO clear
	if(reset || (~fifo_aclr1 && fifo_aclr)) begin
		bc <= 8'd0;
		ts_filter_state <= ST_TS_FILTER_IDLE;
		ts_filter_out_wrreq <= 0;
		data5 <= 0;
		data4 <= 0;
		data3 <= 0;
		data2 <= 0;
		data1 <= 0;
		data0 <= 0;
		pid <= 8'hxx;
		fifo_aclr1 <= 0;
		pkt_start <= 0;
	end
end
endmodule
