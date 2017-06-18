// testbench

`timescale 1 ns / 100 ps

module ts_proxy_tb ();
	reg clk;
	reg phy_clk;
	reg reset;
	reg [7:0] indata;
	wire [7:0] ep3_usb_in_data;
	wire [10:0]           ep3_usb_in_addr;
	wire	ep3_usb_in_wren;
	wire	ep3_usb_in_commit;
	wire	[10:0]           ep3_usb_in_commit_len;
	wire	buf_out_hasdata;
	wire	ep3_usb_in_ready;
	wire	ep3_usb_in_commit_ack;
	reg [7:0] i;
	reg [11:0] bytes_sent;

	/* demod */
	reg	atsc_clock;
	reg	atsc_start;
	reg	atsc_valid;
	reg	atsc_data;

	/* ULPI from PHY */
	reg	phy_ulpi_dir;
	reg	phy_ulpi_nxt;


	ts_proxy DUT (
		.clk(phy_clk /* clk */),
		.atsc_clock(atsc_clock),
		.atsc_start(atsc_start),
		.atsc_valid(atsc_valid),
		.atsc_data(atsc_data),
		.dvb_clock(atsc_clock),
		.dvb_start(atsc_start),
		.dvb_valid(atsc_valid),
		.dvb_data(atsc_data),
		.ep3_usb_in_data(ep3_usb_in_data),
		.ep3_usb_in_addr(ep3_usb_in_addr),
		.ep3_usb_in_wren(ep3_usb_in_wren),
		.ep3_usb_in_commit(ep3_usb_in_commit),
		.ep3_usb_in_commit_len(ep3_usb_in_commit_len),
		.ep3_usb_in_ready(ep3_usb_in_ready),
		.ep3_usb_in_commit_ack(ep3_usb_in_commit_ack),
		.commit_len(11'd1020),
		// .insel(2'b10),
		.insel(2'b11), // TSGEN
		.reset(reset)
	);


	usb2_top USBTOP (
		.ext_clk          ( phy_clk /* clk */ ),
		.reset_n          ( ~reset ),

		.opt_disable_all  ( 1'b0 ),
		.opt_enable_hs    ( 1'b1 ),
		.opt_ignore_vbus  ( 1'b1 ),

		.phy_ulpi_clk     ( phy_clk ),

		/* ULPI */
		.phy_ulpi_dir		(phy_ulpi_dir),

		/* EP3 TS */
		.ep3_ext_clk				( /* lg_clk */ /* clk_50 */ phy_clk),
		.ep3_buf_in_addr         ( ep3_usb_in_addr ),
		.ep3_buf_in_data         ( ep3_usb_in_data ),
		.ep3_buf_in_wren         ( ep3_usb_in_wren ),
		.ep3_buf_in_ready        ( ep3_usb_in_ready ),
		.ep3_buf_in_commit       ( ep3_usb_in_commit ),
		.ep3_buf_in_commit_len   ( ep3_usb_in_commit_len ),
		.ep3_buf_in_commit_ack   ( ep3_usb_in_commit_ack )
	);


	/* usb2_ep USBEP (
		.phy_clk(phy_clk),
		.rd_clk(phy_clk),
		.reset_n(~reset),
		.wr_clk(clk),
		.buf_in_addr(ep3_usb_in_addr),
		.buf_in_data(ep3_usb_in_data),
		.buf_in_wren(ep3_usb_in_wren),
		.buf_in_commit(ep3_usb_in_commit),
		.buf_in_commit_len(ep3_usb_in_commit_len),
		.buf_in_commit_ack(ep3_usb_in_commit_ack),
		.buf_in_ready(ep3_usb_in_ready),
		.fast_commit(0),
		.buf_out_hasdata(buf_out_hasdata)
	); */

	// create clock
	always
		// #5 clk = ~clk;  // 100mhz
		// #3.8 clk = ~clk; // every ten nanoseconds invert
		#10 clk = ~clk; // every ten nanoseconds invert

	always
		#3.8 atsc_clock = ~atsc_clock; // 3.8ns => 130 MHz
		// #10 atsc_clock = ~atsc_clock; // every ten nanoseconds invert

	always
		#8.33 phy_clk = ~phy_clk; // 60MHz ULPI

	always @(posedge clk ) begin
		if (ts_proxy_tb.DUT.almost_full)
		begin
			// simulate buffer cleanup
			// force ts_proxy_tb.USBTOP.ipr.sel_endp = 2'b10;
			force ts_proxy_tb.USBTOP.ipr.ep3_buf_out_arm = 1;
		end
		else begin
			force ts_proxy_tb.USBTOP.ipr.ep3_buf_out_arm = 0;
		end
	end


	/* serialize data from TS and write it to USB EP */
	initial
	begin
		/* set all signals initial values */
		clk = 1'b0; // at time 0
		atsc_clock = 1'b0; // at time 0
		phy_clk = 1'b0; // at time 0
		atsc_data = 1'b0; // at time 0
		atsc_valid = 1'b0; // at time 0
		atsc_start = 1'b0; // at time 0
		phy_ulpi_dir = 1'b0; // at time 0
		indata = 8'h00;
		i = 0;
		reset = 1; // reset is active
		#40 reset = 1'b0; // disable reset

		@(negedge atsc_clock);
		@(negedge atsc_clock);
		@(negedge atsc_clock);
		@(negedge atsc_clock);
		@(negedge atsc_clock);
		indata = 8'h47;
		for( i = 0; i < 8; i=i+1 )
		begin
			atsc_start <= 1;
			atsc_valid <= 1;
			atsc_data <= indata[7-i];
			@(negedge atsc_clock);
			atsc_valid <= 0;
			// @(negedge atsc_clock);
		end
		atsc_start <= 0;

		@(negedge atsc_clock);
		indata = 8'h55;
		for( i = 0; i < 8; i=i+1 )
		begin
			atsc_valid <= 1;
			atsc_data <= indata[7-i];
			@(negedge atsc_clock);
			atsc_valid <= 0;
			// @(negedge atsc_clock);
		end

		bytes_sent <= 2;

		for( bytes_sent = 0; bytes_sent < 4096; bytes_sent=bytes_sent+1 )
		begin
		// @(negedge atsc_clock);
		indata = 8'hAA;
		for( i = 0; i < 8; i=i+1 )
		begin
			atsc_start <= 0;
			atsc_valid <= 1;
			atsc_data <= indata[7-i];
			@(negedge atsc_clock);
			// atsc_valid <= 0;
			// @(negedge atsc_clock);
		end

		/* TODO:read usb isoc from EP3 */
		phy_ulpi_dir <= 1'b1;
		phy_ulpi_nxt <= 1'b1;
		end
	end

	/* reading data from usb ep */
	/* 
	initial
	begin
		always @(posedge clk ) begin
			if (buf_out_hasdata)
			begin
			end
		end
	end
	*/
endmodule
