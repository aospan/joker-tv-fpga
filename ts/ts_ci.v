/* TS streams
 * CI input/output
 *
 * data flow:
 * in FIFO    -> ts_ci_fifo -> CI bus -> ci_sync FIFO -> out FIFO
 * 
 * (c) Abylay Ospan, 2017
 * Joker Systems Inc.
 * aospan@jokersys.com
 */

module ts_ci (
	input	wire		clk,
	input	wire		clk_9,
	input	wire		reset,
	
	/* export CI FIFO 
	* bytes written to this FIFO will be redirected to CI bus
	*/
	input	wire	[7:0]	ts_ci_in_d,
	input	wire		ts_ci_wrreq,
	output	wire		ts_ci_almost_full,
	input	wire	pkt_start,
	
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
	input		wire	CI_MOVAL,
	
	output	reg[23:0]	pkts,
	output	reg[23:0]	pkts_out
);

wire	[8:0]	fifo_q;
reg	fifo_rdreq;
reg	CI_MCLKO_prev;
reg	CI_MOSTRT_prev;

reg [8:0] c_data;
assign c_data = {pkt_start, ts_ci_in_d};
wire	[7:0]  wrusedw;
wire	wrfull;
assign ts_ci_almost_full = (wrusedw >= 8'd250) ? 1 : 0;

ts_ci_fifo ts_ci_fifo_inst (
	.wrclk(clk),
	.wrreq(ts_ci_wrreq),
	.wrusedw(wrusedw),
	.wrfull(wrfull),
	.data(c_data),
	
	.rdclk(clk_9),
	.aclr(fifo_aclr),
	.rdempty(ts_ci_rdempty),
	.rdreq(fifo_rdreq),
	.q(fifo_q)
);

reg [7:0] sync_data;
wire [7:0] sync_wrusedw;
wire [7:0] sync_q;
reg sync_wrreq;

// synchronize CAM clock (may be any according to en50221)
// with our clk
ts_ci_sync ts_ci_sync_inst (
	.wrclk(CI_MCLKO),
	.wrreq(sync_wrreq),
	.wrusedw(sync_wrusedw),
	.wrfull(sync_wrfull),
	.data(sync_data),
	.rdclk(clk),
	.aclr(sync_aclr),
	.rdempty(sync_rdempty),
	.rdreq(sync_rdreq),
	.q(sync_q)
);

// copy sync FIFO to upstream FIFO
assign ts_ci_out_d = sync_q;
assign sync_rdreq = ~sync_rdempty ? 1 : 0;
assign ts_ci_out_wrreq = (~ts_ci_out_almost_full && 
	sync_rdreq) ? 1 : 0;

/* state machine */
reg [3:0] ts_ci_state;
parameter ST_TS_CI_IDLE=0,
			 ST_TS_CI_READ_FIFO=1,
			 ST_TS_CI_WRITE_CI=2,
			 ST_TS_CI_WAIT_NEXT_CLK=3;

assign CI_MCLKI = clk_9;
assign	CI_MDI = fifo_q[7:0];
assign CI_MISTRT = fifo_q[8] && CI_MIVAL;
reg reset_prev;
reg reset_prev_out;

// send TS to CAM
always @(posedge clk_9) begin;
	reset_prev <= reset;
	
	if (CI_MISTRT)
		pkts <= pkts + 1;
	
	/*** Process CAM IN traffic ***/
	case(ts_ci_state)
	ST_TS_CI_IDLE:
	begin
		if (~ts_ci_rdempty) begin
			fifo_rdreq <= 1;
			ts_ci_state <= ST_TS_CI_WRITE_CI;
		end
	end
	ST_TS_CI_WRITE_CI:
	begin
		if (ts_ci_rdempty) begin
			ts_ci_state <= ST_TS_CI_IDLE;
			fifo_rdreq <= 0;
			CI_MIVAL <= 0;
		end else 
			CI_MIVAL <= 1;
	end
	endcase
	
	if(~reset && reset_prev) begin
		CI_MIVAL <= 0;
		ts_ci_state <= ST_TS_CI_IDLE;
		pkts <= 0;
		fifo_rdreq <= 0;
	end	
end

// receive TS from CAM
always @(posedge CI_MCLKO ) begin;
	reset_prev_out <= reset;
	
	if (CI_MOSTRT)
		pkts_out <= pkts_out + 1;
	
	if (CI_MOVAL && sync_wrusedw < 8'd250) begin
		sync_data <= CI_MDO;
		sync_wrreq <= 1;
	end else begin
		sync_wrreq <= 0;
	end
		
	if(~reset && reset_prev_out) begin
		pkts_out <= 0;
		sync_wrreq <= 0;
		sync_data <= 0;
	end	
end

endmodule
