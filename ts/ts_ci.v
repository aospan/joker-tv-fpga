/* TS streams
 * CI input/output
 *
 * data flow:
 * in FIFO    -> ci_ts_in -> CI bus ->	ci_ts_out -> out FIFO
 * 
 * (c) Abylay Ospan, 2017
 * Joker Systems Inc.
 * aospan@jokersys.com
 */

module ts_ci (
	input	wire		clk,
	input	wire		reset,

	/* export CI FIFO 
	* bytes written to this FIFO will be redirected to CI bus
	*/
	input	wire	[7:0]	ts_ci_in_d,
	input	wire		ts_ci_wrreq,
	output	wire		ts_ci_almost_full,
	
	input	wire		ts_ci_rdreq,
	output	wire	[7:0]	ts_ci_q,
	output	wire		ts_ci_rdempty,


	/* data read from CI bus will appear here */
	output	reg	[7:0]	ts_ci_out_d,
	output	reg		ts_ci_out_wrreq,
	input	wire		ts_ci_out_almost_full,

	/* CI bus pins */
	output	reg	[7:0]	CI_MDI,
	output	reg	CI_MCLKI,
	output	reg	CI_MISTRT,
	output	reg	CI_MIVAL,

	input		wire	[7:0]	CI_MDO,
	input		wire	CI_MCLKO,
	input		wire	CI_MOSTRT,
	input		wire	CI_MOVAL	
);

wire	[7:0]	fifo_q;
wire	fifo_rdreq;
wire	CI_MCLKO_prev;

ts_ci_fifo ts_ci_fifo_inst (
	.clock(clk),
	.aclr(fifo_aclr),
	.data(ts_ci_in_d),
	.empty(ts_ci_rdempty),
	.rdreq(fifo_rdreq),
	.wrreq(ts_ci_wrreq),
	.q(fifo_q),
	.almost_full(ts_ci_almost_full)
);

/* state machine */
reg [3:0] ts_ci_state;
parameter ST_TS_CI_IDLE=0,
			 ST_TS_CI_READ_FIFO=1,
			 ST_TS_CI_WRITE_CI=2,
			 ST_TS_CI_WAIT_NEXT_CLK=3;

reg [3:0] ts_ci_out_state;
parameter ST_TS_CI_OUT_IDLE=0;

reg	[3:0]	clk_cnt;
reg	[4:0] ts_dc;
reg	[7:0]	ci_data;
reg	[15:0] sync_cnt;
reg	in_sync;

always @(posedge clk ) begin
	ts_dc <= ts_dc + 1;
	clk_cnt <= clk_cnt + 1;
	CI_MCLKO_prev <= CI_MCLKO;
	
	/*** Process CAM IN traffic ***/
	case(ts_ci_state)
	ST_TS_CI_IDLE:
	begin
		/* input clock 60 MHZ (16.6ns cycle)
		* ci (parallel) clock 9Mhz (111ns cycle)
		* div is ~ 7 */
		if (clk_cnt >= 3) begin
			clk_cnt <= 0;
			CI_MCLKI <= ~CI_MCLKI;
		end
		
		/* no more data in fifo */
		if (ts_ci_rdempty && ~CI_MCLKI && clk_cnt == 2 /* hold data on bus after fall edge */) begin
			CI_MIVAL <= 0;
			CI_MISTRT <= 0;
		end
		
		/* set next byte to bus if available */
		if (~ts_ci_rdempty && ~CI_MCLKI && clk_cnt == 1) begin
			fifo_rdreq <= 1;
			ts_ci_state <= ST_TS_CI_WRITE_CI;
		end
	end
	ST_TS_CI_WRITE_CI:
	begin
		CI_MDI <= fifo_q;
		if (fifo_q == 8'h47 && sync_cnt >= 8'hBB) begin
			// all is ok, we are in sync
			CI_MISTRT <= 1;
			sync_cnt <= 0;
		end else begin
			sync_cnt <= sync_cnt + 1;
			CI_MISTRT <= 0;
		end
		
		CI_MIVAL <= 1;
		fifo_rdreq <= 0;	
		ts_ci_state <= ST_TS_CI_IDLE;
	end
	endcase
	
	/*** Process CAM OUT traffic ***/
	case(ts_ci_out_state)
	ST_TS_CI_OUT_IDLE:
	begin
		if (~CI_MCLKO_prev && CI_MCLKO) begin
			/* clock rise detected */
			if (CI_MOVAL && ~ts_ci_out_almost_full) begin
				ts_ci_out_d <= CI_MDO;
				ts_ci_out_wrreq <= 1;
			end else begin
				ts_ci_out_wrreq <= 0;
			end
		end else begin
			ts_ci_out_wrreq <= 0;
		end
	end
	endcase

	if(reset) begin
		clk_cnt <= 0;
		sync_cnt <= 0;
		in_sync <= 0;
		ts_dc	<= 5'h00;
		CI_MDI <= 8'h0;
		CI_MIVAL <= 0;
		CI_MISTRT <= 0;
		CI_MCLKI <= 0;
		ts_ci_state <= ST_TS_CI_IDLE;
		ts_ci_out_state <= ST_TS_CI_OUT_IDLE;
	end
end

endmodule
