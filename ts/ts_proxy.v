/* TS streams processing module 
 *
 * MUX TS traffic
 * TS source  -> CAM modules -> TS FIFO
 *
 * (c) Abylay Ospan, 2017
 * Joker Systems Inc.
 * aospan@jokersys.com
 */

module ts_proxy (
	input	wire		clk,
	input	wire		reset,

	/* input selector. 
		000 - DVB, 
		001 - DTMB,
		010 - ATSC  
		011 - TSGEN 
		100 - USB bulk OUT transfers */
	input	wire	[2:0]		insel,

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
	output	reg		ep3_ext_buf_out_arm,
	
	/* TS data from usb bulk transactions */
	input	wire	[7:0]	ts_usb_data,
	input	wire	ts_usb_writereq,
	output	wire		ts_usb_almost_full,
	
	/* CI fifo to CAM (IN direction) */
	output	wire	[7:0]	ts_ci_in_d,
	output	wire	ts_ci_wrreq,
	input	wire		ts_ci_almost_full,
	
	/* CI fifo from CAM (OUT direction
	 * data read from CI bus will appear here */
	input	wire	[7:0]	ts_ci_out_d,
	input	wire		ts_ci_out_wrreq,
	output	wire		ts_ci_out_almost_full,
	input	wire		ts_ci_enable,
	
	output	wire	fifo_rdempty,
	input		wire	fifo_aclr,
	
	output	reg	[29:0]	total_bytes_send2usb
);

/* state machine */
reg [3:0] ts_samp_state;
parameter ST_TS_IDLE=0, ST_TS_WRITE=1, ST_TS_COMMIT=2, ST_TS_WAIT_ACK=3, ST_TS_ROLLOVER=4, ST_TS_COMMIT2=5;

reg [3:0] fifo_state;
parameter FIFO_IDLE=0, FIFO_WAIT=1;

dvb_ts_selector tssel (
	.rst (reset),
	.insel (insel[1:0]),
	.clk (clk),
	.strt (strt),
	.dval (dval),
	.data ( ts_demods_data ),
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

/* mux TS fifo and CI TS fifo
 * we should use CI TS fifo if ts_ci_enable
 */

 /* data to CAM (IN direction) */
/* assign almost_full = (ts_ci_enable) ? ts_ci_almost_full : ts_almost_full;
assign ts_usb_almost_full = ts_almost_full;
assign ts_ci_out_almost_full = ts_almost_full;
assign ts_ci_wrreq = (ts_ci_enable) ? fifo_wrreq : 1'b0;
assign ts_fifo_wrreq = (ts_ci_enable) ? ts_ci_out_wrreq : 
					(insel == 3'b100) ? ts_usb_writereq : fifo_wrreq;
assign ts_ci_in_d = fifo_data;
assign ts_fifo_data = (ts_ci_enable) ? ts_ci_out_d : fifo_data;
assign fifo_data = (insel == 3'b011) ? tsgen_data : 
							(insel == 3'b100) ? ts_usb_data : ts_data;

assign ep3_usb_in_data = (insert_marker) ? 8'h33 : fifo_q;
*/

reg	[4:0] ts_dc;
reg	[4:0]	fifo_dc;
reg	[10:0] cnt_p;
reg	[8:0] tslost_cnt;
reg	[8:0] missed_ack;
wire	strt;
wire	dval;
reg	wren;
reg ack_2;
reg ack_1;

/* big TS FIFO signals */
reg	fifo_rdreq;
wire	[7:0]	fifo_q;
wire	ts_fifo_wrreq;
wire	[7:0]	ts_fifo_data;
reg	ts_fifo_almost_full;

/* selected TS source */
wire	[7:0]	selected_ts_data;
wire	selected_ts_wrreq;

/* TS generator */
reg	tsgen_wrreq;
reg	[7:0]	tsgen_data;
reg	[7:0]	tsgen_pattern;
reg	[7:0]	tsgen_pos;
reg	[3:0]	tsgen_counter;

/* TS demods */
reg	ts_demods_wrreq;
reg	[7:0]	ts_demods_data;


/* MUX ts sources:
	000 - DVB, 
	001 - DTMB,
	010 - ATSC  
	011 - TSGEN 
	100 - USB bulk OUT transfers
*/
assign selected_ts_data = (insel == 3'b011) ? tsgen_data : 
									(insel == 3'b100) ? ts_usb_data : ts_demods_data;
assign selected_ts_wrreq = (insel == 3'b011) ? tsgen_wrreq : 
									(insel == 3'b100) ? ts_usb_writereq : ts_demods_wrreq;
							
/* Route TS traffic to CAM if enabled */
assign ts_ci_in_d = (ts_ci_enable) ? selected_ts_data : 1'b0;
assign ts_ci_wrreq = (ts_ci_enable) ? selected_ts_wrreq : 1'b0;
assign selected_almost_full = (ts_ci_enable) ? ts_ci_almost_full : ts_fifo_almost_full;

/* Receive TS traffic from CAM if enabled */
assign ts_fifo_data = (ts_ci_enable) ? ts_ci_out_d : selected_ts_data;
assign ts_fifo_wrreq = (ts_ci_enable) ? ts_ci_out_wrreq : selected_ts_wrreq;

/* other signals mux */
assign ts_usb_almost_full = selected_almost_full;
assign ts_ci_out_almost_full = ts_fifo_almost_full;
assign ep3_usb_in_data = fifo_q;

tsfifo tsfifo_inst (
	.clock(clk),
	.aclr(fifo_aclr),
	.data(ts_fifo_data),
	.empty(fifo_rdempty),
	.rdreq(fifo_rdreq),
	.wrreq(ts_fifo_wrreq),
	.q(fifo_q),
	.almost_full(ts_fifo_almost_full)
);

assign	ep3_usb_in_addr = cnt_p;
assign	ep3_usb_in_wren = wren;
assign	ep3_usb_in_commit_len = commit_len;
assign	tslost = tslost_cnt;	
assign	missed = missed_ack;	
assign	state = ts_samp_state;
assign	dc = cnt_p[3:0];


always @(posedge clk ) begin
	ts_dc <= ts_dc + 1;
	fifo_dc <= fifo_dc + 1;
	{ack_2, ack_1} <= {ack_1, ep3_usb_in_commit_ack };
	wren <= 0;
	fifo_rdreq <= 0;
	tsgen_wrreq	<= 0;
	ts_demods_wrreq <= 0;
	
	case(fifo_state)
	FIFO_IDLE:
		case (insel)
		3'b011: /* TSGEN selected */
		begin
			/* always keep FIFO almost full ! */
			if (~selected_almost_full) begin			
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
				tsgen_wrreq	<= 1;
				
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
				if (selected_almost_full) begin
					tslost_cnt <= tslost_cnt + 1;
				end
				else begin
					ts_demods_wrreq <= 1;
				end
			end
		end
		endcase
	endcase
		
		 
	case (ts_samp_state)
		ST_TS_IDLE:
		begin	
			if (~fifo_rdempty && ep3_usb_in_ready ) begin
				fifo_rdreq <= 1;
				pkts_cnt <= pkts_cnt + 1;
				ts_samp_state <= ST_TS_WRITE;
			end
		end
		ST_TS_WRITE:
		begin
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
				total_bytes_send2usb <= total_bytes_send2usb + 1;
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
		missed_ack <= 0;
		ts_samp_state <= 0;
		fifo_state <= FIFO_IDLE;
		tsgen_pattern <= 0;
		tsgen_counter <= 0;
		tsgen_pos <= 0;
		tsgen_data <= 0;
	end
end

endmodule
