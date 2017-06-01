module ts_proxy (
	input	wire		clk,
	input	wire		reset,

	/* input selector. 00 - DVB, 01 - DTMB, 10 - ATSC */
	input	wire	[1:0]		insel,

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
reg [3:0] ts_samp_state = 4'b0000;
parameter ST_TS_IDLE=0, ST_TS_WRITE=1, ST_TS_COMMIT=2, ST_TS_WAIT_ACK=3, ST_TS_ROLLOVER=4, ST_TS_COMMIT2=5;
 
/* state machine for FIFO input */
reg [3:0] ts_fifo_state = 4'b0000;
parameter ST_FIFO_IDLE=0, ST_FIFO_WRITE=1;

reg	[4:0] ts_dc	= 5'h00;
reg	[10:0] cnt_p	= 10'h00;
reg	[8:0] tslost_cnt = 8'h00;
reg	[8:0] missed_ack = 8'h00;
// reg	commit;
wire	strt;
wire	dval;
reg	wren;

reg ack_2;
reg ack_1;
wire	[7:0]  fifo_data;

dvb_ts_selector tssel (
	.rst (reset),
	.insel (insel),
	.clk (clk),
	.strt (strt),
	.dval (dval),
	.data ( fifo_data /* ep3_usb_in_data */),
	.atsc_clock (atsc_clock),
	.atsc_start (atsc_start),
	.atsc_valid (atsc_valid),
	.atsc_data (atsc_data),
	.dvb_clock (dvb_clock),
	.dvb_start (dvb_start),
	.dvb_valid (dvb_valid),
	.dvb_data (dvb_data)
);

wire	[7:0]  fifo_q;
reg	fifo_rdreq;
reg	fifo_wrreq;
wire	fifo_rdfull;
wire	fifo_wrfull;
wire	fifo_rdempty;
reg	fifo_aclr;

assign ep3_usb_in_data = fifo_q;

tsfifo tsfifo_inst (
	.rdclk(clk),
	.wrclk(clk),
	.aclr(fifo_aclr),
	.data(fifo_data),
	.rdempty(fifo_rdempty),
	.rdreq(fifo_rdreq),
	.wrreq(fifo_wrreq),
	.q(fifo_q),
	.rdfull(fifo_rdfull),
	.wrfull(fifo_wrfull)
);

assign	ep3_usb_in_addr = cnt_p;
assign	ep3_usb_in_wren = wren;
assign	ep3_usb_in_commit_len = commit_len;
assign	tslost = tslost_cnt;	
assign	missed = missed_ack;	
assign	state = ts_samp_state;
assign	dc = cnt_p[3:0] /* ts_dc */;


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

		{ack_2, ack_1} <= {ack_1, ep3_usb_in_commit_ack };
		wren <= 0;
		fifo_rdreq <= 0;
		fifo_aclr <= 0;
		fifo_wrreq	<= 0;
		ep3_usb_in_commit <= 0;
		
		probe[10:0] <= commit_len;
		probe[12:11] <= insel;

		case (ts_fifo_state)
	       ST_FIFO_IDLE:
	       begin	
	       if (dval) begin
				
		       if (fifo_wrfull) begin
			       tslost_cnt <= tslost_cnt + 1;
		       end
		       else begin
			       fifo_wrreq	<= 1;
			       // ts_fifo_state <= ST_TS_WRITE;
		      end
	      end
      end
		/*  
		ST_FIFO_WRITE:
		begin
	       fifo_wrreq <= 0;
			 ts_fifo_state <= ST_TS_IDLE;
		end */
		endcase
			 
		 
       case (ts_samp_state)
	       ST_TS_IDLE:
	       begin	
				if (fifo_rdfull) begin
					fifo_clean <= fifo_clean + 1;
					fifo_aclr <= 1;
				end
				else if (~fifo_rdempty && ep3_usb_in_ready ) begin
					probe[31] <= ~probe[31];
					fifo_rdreq <= 1;
					pkts_cnt <= pkts_cnt + 1;
					// wren	<= 1;
					ts_samp_state <= ST_TS_WRITE;
				end
			end

       ST_TS_WRITE:
       begin
			probe[30] <= ~probe[30];
	       wren	<= 1;
	       ts_samp_state <= ST_TS_COMMIT;
		end
			
       ST_TS_COMMIT:
       begin
			
			// ts_samp_state <= /* ST_TS_COMMIT */ ST_TS_WRITE;
			
					 
	       /* ts_samp_state <= ST_TS_ROLLOVER;
       end

       ST_TS_ROLLOVER:
       begin */
			// if (cnt_p == 100)
				// ep3_ext_buf_out_arm <= 1; //hack
		 
	       if (cnt_p == commit_len - 1) begin
				probe[29] <= ~probe[29];
	       // if (cnt_p == commit_len) begin
		       cnt_p <= 0;
		       // ts_samp_state <= ST_TS_COMMIT;
				 ep3_usb_in_commit <= 1;
				 ts_samp_state <= ST_TS_WAIT_ACK;
				  ts_dc <= 0;
	       end
	       else begin
				probe[28] <= ~probe[28];
		       cnt_p <= cnt_p + 1;
		       ts_samp_state <= ST_TS_IDLE;
	       end
       end

       /* ST_TS_COMMIT:
       begin
	       ep3_usb_in_commit <= 1;			
	       ts_samp_state <= ST_TS_WAIT_ACK;
	       ts_dc <= 0;
       end */

       /*
       ST_TS_COMMIT2:
       begin
	       if ( ts_dc > 1) begin
		       commit <= 0;
		       ts_dc <= 0;
		       ts_samp_state <= ST_TS_WAIT_ACK;
	       end
       end */

       ST_TS_WAIT_ACK:
       begin
				probe[27] <= ~probe[27];
	       if ( ts_dc > 5 )
		       missed_ack <= missed_ack + 1;

	       if ( ts_dc > 6 || (ack_1 && ~ep3_usb_in_commit_ack )) begin	
		       ep3_usb_in_commit <= 0;
		       acked <= acked + 1;
		       ts_samp_state <= ST_TS_IDLE;
				 probe[26] <= ~probe[26];
	       end
       end
	endcase

	if(reset) begin
		ts_dc	<= 5'h00;
		cnt_p	<= 8'h00;
		wren	<= 0;
		ep3_usb_in_commit <= 0;
		tslost_cnt <= 0;
		fifo_clean <= 0;
		probe <= 0;
	end
end

endmodule
