/* TS streams processing module 
 * 
 * (c) Abylay Ospan, 2017
 * Joker Systems Inc.
 * aospan@jokersys.com
 */

module ts_proxy (
	input	wire		clk,
	input	wire		reset,

	/* input selector. 00 - DVB, 01 - DTMB, 10 - ATSC  11 - TSGEN */
	input	wire	[1:0]		insel,

	/* wires from DTMB demod */
	input	wire		dtmb_clock,
	input	wire		dtmb_start,
	input	wire		dtmb_valid,
	input	wire		dtmb_data,
	
	/* wires from ATSC demod */
	input	wire		atsc_clock,
	input	wire		atsc_start,
	input	wire		atsc_valid,
	input	wire		atsc_data,

	/* wires from DVB demod */
	input	wire		dvb_clock,
	input	wire		dvb_start,
	input	wire		dvb_valid,
	input	wire		dvb_data,

	/* how many bytes commit at once */
	input	wire	[10:0]		commit_len,

	output	wire	[8:0]		tslost,
	output	wire	[8:0]		missed,
	output	reg	[8:0]		acked,
	output	wire	[3:0]		state,
	output	wire	[3:0]		dc,
	output	reg	[3:0]		fifo_clean,
	output	reg	[15:0]	pkts_cnt,

	/* USB Endpoint 3 IN */
	output	wire	[10:0]		ep3_usb_in_addr,
	output	wire	[7:0]		ep3_usb_in_data,
	output	wire			ep3_usb_in_wren,
	output	reg			ep3_usb_in_commit,
	input	wire			ep3_usb_in_ready,
	input	wire			ep3_usb_in_commit_ack,
	output	wire	[10:0]		ep3_usb_in_commit_len,
	output	reg		ep3_ext_buf_out_arm
);

/* state machine */
reg [3:0] ts_samp_state;
parameter ST_TS_IDLE=0, ST_TS_WRITE=1, ST_TS_COMMIT=2, ST_TS_WAIT_ACK=3, ST_TS_ROLLOVER=4, ST_TS_COMMIT2=5;

reg [3:0] fifo_state;
parameter FIFO_IDLE=0, FIFO_WAIT=1;

reg	[4:0] ts_dc;
reg	[4:0]	fifo_dc;
reg	[10:0] cnt_p;
reg	[8:0] tslost_cnt;
reg	[8:0] missed_ack;
// reg	commit;
wire	strt;
wire	dval;
reg	wren;
reg	insert_marker;

reg ack_2;
reg ack_1;
wire	[7:0]		fifo_data;
wire	[7:0]		ts_data;
reg	[7:0]		tsgen_data;
reg	[7:0]		tsgen_pattern;
reg	[7:0]		tsgen_pos;
reg	[3:0]		tsgen_counter;

assign fifo_data = (insel == 2'b11) ? tsgen_data : ts_data;

dvb_ts_selector tssel (
	.rst (reset),
	.insel (insel),
	.clk (clk),
	.strt (strt),
	.dval (dval),
	.data ( ts_data ),
	.atsc_clock (atsc_clock),
	.atsc_start (atsc_start),
	.atsc_valid (atsc_valid),
	.atsc_data (atsc_data),
	.dtmb_clock (dtmb_clock),
	.dtmb_start (dtmb_start),
	.dtmb_valid (dtmb_valid),
	.dtmb_data (dtmb_data),	
	.dvb_clock (dvb_clock),
	.dvb_start (dvb_start),
	.dvb_valid (dvb_valid),
	.dvb_data (dvb_data)
);

wire	[7:0]  fifo_q;
reg	fifo_rdreq;
reg	fifo_wrreq;
wire	fifo_wrfull;
wire	fifo_rdempty;
reg	fifo_aclr;
wire	almost_full;

assign ep3_usb_in_data = (insert_marker) ? 8'h33 : fifo_q;

tsfifo tsfifo_inst (
	.clock(clk),
	.aclr(fifo_aclr),
	.data(fifo_data),
	.empty(fifo_rdempty),
	.rdreq(fifo_rdreq),
	.wrreq(fifo_wrreq),
	.q(fifo_q),
	.almost_full(almost_full)
);

assign	ep3_usb_in_addr = cnt_p;
assign	ep3_usb_in_wren = wren;
assign	ep3_usb_in_commit_len = commit_len;
assign	tslost = tslost_cnt;	
assign	missed = missed_ack;	
assign	state = ts_samp_state;
assign	dc = cnt_p[3:0];


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

always @(posedge clk ) begin
	ts_dc <= ts_dc + 1;
	fifo_dc <= fifo_dc + 1;
	{ack_2, ack_1} <= {ack_1, ep3_usb_in_commit_ack };
	wren <= 0;
	fifo_rdreq <= 0;
	fifo_aclr <= 0;
	fifo_wrreq	<= 0;
	insert_marker <= 0;		
	probe[10:0] <= commit_len;
	probe[12:11] <= insel;

	case(fifo_state)
	FIFO_IDLE:
		case (insel)
		2'b11: /* TSGEN selected */
		begin
			/* always keep FIFO almost full ! */
			if (~almost_full) begin
				
				case(tsgen_pos)
				8'h0: tsgen_data <= 8'h47; // TS sync byte 
				8'h1: tsgen_data <= 8'h01; // PID high 
				8'h2: tsgen_data <= 8'h77; // PID log 
				8'h3:
					begin
						tsgen_data <= {4'h1,tsgen_counter}; // TS counter 
						tsgen_counter <= tsgen_counter + 1; // new TS 
						tsgen_pattern <= tsgen_pattern + 1; // new TS 
					end
				default: tsgen_data <= tsgen_pattern;
				endcase
				tsgen_pos <= tsgen_pos + 1'b1;
				if (tsgen_pos == 8'd187)
					tsgen_pos <= 0;
				fifo_wrreq	<= 1;
				
				/*
				// TODO: another type of traffic generator - sequential bytes 
				if (tsgen_data == 8'h09)
					tsgen_data <= 8'h0b;
				else
					tsgen_data <= tsgen_data + 1;
				fifo_wrreq	<= 1;
				*/
			end
		end
		default:
		begin
			/* write real data from demods into FIFO if available */
			if (dval) begin
				if (almost_full) begin
					tslost_cnt <= tslost_cnt + 1;
				end
				else begin
					fifo_wrreq	<= 1;
				end
			end
		end
		endcase
	endcase
		
		 
	case (ts_samp_state)
		ST_TS_IDLE:
		begin	
			if (~fifo_rdempty && ep3_usb_in_ready ) begin
				probe[31] <= ~probe[31];
				fifo_rdreq <= 1;
				pkts_cnt <= pkts_cnt + 1;
				ts_samp_state <= ST_TS_WRITE;
			end
		end
		ST_TS_WRITE:
		begin
			if (cnt_p == commit_len - 2) begin
				// insert_marker <= 1;
			end
			wren	<= 1;
			ts_samp_state <= ST_TS_COMMIT;
		end
		ST_TS_COMMIT:
		begin
	       if (cnt_p == commit_len - 1) begin
				cnt_p <= 0;
				ep3_usb_in_commit <= 1;
				ts_samp_state <= ST_TS_WAIT_ACK;
				ts_dc <= 0;
	       end
	       else begin
				cnt_p <= cnt_p + 1;
				ts_samp_state <= ST_TS_IDLE;
	       end
		end
		ST_TS_WAIT_ACK:
		begin
			if ( ts_dc > 5 )
				missed_ack <= missed_ack + 1;

			if ( ts_dc > 6 || (ack_2 && ~ack_1 )) begin	
		       ep3_usb_in_commit <= 0;
		       acked <= acked + 1;
		       ts_samp_state <= ST_TS_IDLE;
			end
		end
	endcase

	if(reset) begin
		ts_dc	<= 5'h00;
		fifo_dc	<= 5'h00;
		cnt_p	<= 8'h00;
		wren	<= 0;
		ep3_usb_in_commit <= 0;
		tslost_cnt <= 0;
		fifo_clean <= 0;
		probe <= 0;
		missed_ack <= 0;
		ts_samp_state <= 0;
		insert_marker <= 0;
		fifo_state <= FIFO_IDLE;
		tsgen_pattern <= 0;
		tsgen_counter <= 0;
		tsgen_pos <= 0;
		tsgen_data <= 0;
	end
end

endmodule
