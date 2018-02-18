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
	wire	phy_ulpi_stp;
	wire	[7:0]   phy_ulpi_d;
	reg	phy_ulpi_wr_en;
	reg	[7:0]   phy_ulpi_wr_d;

	parameter [3:0]	PID_TOKEN_OUT		= 4'hE,
		PID_TOKEN_IN		= 4'h6,
		PID_TOKEN_SOF		= 4'hA,
		PID_TOKEN_SETUP		= 4'h2,
		PID_TOKEN_PING		= 4'hB,
		PID_DATA_0			= 4'hC,
		PID_DATA_1			= 4'h4,
		PID_DATA_2			= 4'h8,
		PID_DATA_M			= 4'h0,
		PID_HAND_ACK		= 4'hD,
		PID_HAND_NAK		= 4'h5,
		PID_HAND_STALL		= 4'h1,
		PID_HAND_NYET		= 4'h9,
		PID_SPEC_PREERR		= 4'h3,
		PID_SPEC_SPLIT		= 4'h7,
		PID_SPEC_LPM		= 4'hF;


	ts_proxy DUT (
		.clk(phy_clk ),
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
		.ts_ci_enable(0),
		.commit_len(11'd1024), // isoc packet size
		// .commit_len(11'd8), // isoc packet size
		.insel(3'b010), // ATSC
		// .insel(3'b101), // TSGEN mode 2
		// .insel(3'b011), // TSGEN mode 1
		.reset(reset)
	);

	wire	[4:0]	next_crc5;
	reg		[10:0]	crc5_data;

	usb2_crc5 ic5 (
		.c			( 5'h1F ),
		.data		( crc5_data ),
		.next_crc	( next_crc5 )
	);

	usb2_top USBTOP (
		.ext_clk          ( phy_clk ),
		.reset_n          ( ~reset ),

		.opt_disable_all  ( 1'b0 ),
		.opt_enable_hs    ( 1'b1 ),
		.opt_ignore_vbus  ( 1'b1 ),

		.phy_ulpi_clk     ( phy_clk ),

		/* ULPI */
		.phy_ulpi_dir		(phy_ulpi_dir),
		.phy_ulpi_d		(phy_ulpi_d),
		.phy_ulpi_nxt		(phy_ulpi_nxt),
		.phy_ulpi_stp		(phy_ulpi_stp),

		/* EP3 TS */
		.ep3_ext_clk		( phy_clk),
		.ep3_buf_in_addr         ( ep3_usb_in_addr ),
		.ep3_buf_in_data         ( ep3_usb_in_data ),
		.ep3_buf_in_wren         ( ep3_usb_in_wren ),
		.ep3_buf_in_ready        ( ep3_usb_in_ready ),
		.ep3_buf_in_commit       ( ep3_usb_in_commit ),
		.ep3_buf_in_commit_len   ( ep3_usb_in_commit_len ),
		.ep3_buf_in_commit_ack   ( ep3_usb_in_commit_ack )
	);

	assign phy_ulpi_d = (phy_ulpi_wr_en) ? phy_ulpi_wr_d : 8'bz;

	reg	[3:0]	pid;
	reg	[6:0]	addr; // device usb addr
	reg	[3:0]	endp; // device usb endpoint

	reg	[7:0]	bc;
	reg	[7:0]	recv_data;
	reg	[7:0]	send_data;
	reg	[7:0]	send_data_link;
	reg	[7:0]   ulpi_state;
	reg	[7:0]   ulpi_state_next;
	reg	[7:0]   ulpi_state_next_saved;
	reg	[7:0]   ulpi_state_next_saved_token;
	parameter [7:0]
		ST_ULPI_RST = 8'd0,
		ST_ULPI_RST_1 = 8'd1,
		ST_ULPI_RST_2 = 8'd2,
		ST_ULPI_IDLE = 8'd5,
		ST_ULPI_RX = 8'd10,
		ST_ULPI_TX = 8'd20,
		ST_ULPI_TX_1 = 8'd21,
		ST_ULPI_TX_LINK = 8'd30,
		ST_ULPI_TX_LINK_1 = 8'd31,
		ST_ULPI_TOKEN = 8'd40,
		ST_ULPI_TOKEN_1 = 8'd41,
		ST_ULPI_TOKEN_2 = 8'd42,
		ST_ULPI_TOKEN_3 = 8'd43,
		ST_ULPI_TOKEN_4 = 8'd44,
		ST_ULPI_SEND_TOKEN = 8'd45,
		ST_ULPI_ISOC = 8'd50,
		ST_ULPI_ISOC_1 = 8'd51,
		ST_ULPI_ISOC_RECV = 8'd52;

	// create clock
	always
		#10 clk = ~clk; // every ten nanoseconds invert

	always begin
		#16 atsc_clock = ~atsc_clock; 
		// #2.7 atsc_clock = ~atsc_clock; // 2.7ns => 180 MHz
		// #3.8 atsc_clock = ~atsc_clock; // 3.8ns => 130 MHz
	end

	always
		#8.33 phy_clk = ~phy_clk; // 60MHz ULPI

	/* USB transfers */
	always @(posedge phy_clk ) begin
		bc <= bc + 1'b1;

		case(ulpi_state)
			ST_ULPI_RST:
			begin
				addr <= 0;
				endp <= 3; // isoc
				ulpi_state <= ST_ULPI_RX;
				ulpi_state_next <= ST_ULPI_RST_1;
			end
			ST_ULPI_RST_1:
			begin
				// send cmd to link
				send_data <= 8'h0;
				ulpi_state <= ST_ULPI_TX;
				ulpi_state_next <= ST_ULPI_RST_2;
			end
			ST_ULPI_RST_2:
			begin
				ulpi_state <= ST_ULPI_RX;
				ulpi_state_next <= ST_ULPI_ISOC;
			end

			ST_ULPI_IDLE:
			begin
			end

			ST_ULPI_ISOC:
			begin
				// send SOF token
				pid <= PID_TOKEN_SOF;
				ulpi_state <= ST_ULPI_SEND_TOKEN;
				ulpi_state_next <= ST_ULPI_ISOC_1;
			end
			ST_ULPI_ISOC_1:
			begin
				// send IN token
				pid <= PID_TOKEN_IN;
				ulpi_state <= ST_ULPI_SEND_TOKEN;
				ulpi_state_next <= ST_ULPI_ISOC_RECV;
			end
			ST_ULPI_ISOC_RECV:
			begin
				// recv data from link
				ulpi_state <= ST_ULPI_RX;
				ulpi_state_next <= ST_ULPI_ISOC /* ST_ULPI_IDLE */;
			end

			/*** send token to link ***/
			ST_ULPI_SEND_TOKEN:
			begin
				ulpi_state_next_saved_token <= ulpi_state_next;
				// enable rxactive
				send_data <= {2'b00,
					2'b01 /* rx_event */,
					2'b11 /* vbus */,
					2'b00 /* linestate */};
				ulpi_state <= ST_ULPI_TX_LINK;
				ulpi_state_next <= ST_ULPI_TOKEN;
			end

			ST_ULPI_TOKEN:
			begin
				phy_ulpi_dir <= 1'b1;
				phy_ulpi_nxt <= 1'b1;
				phy_ulpi_wr_d <= {pid, ~pid};
				phy_ulpi_wr_en <= 1'b1;
				ulpi_state <= ST_ULPI_TOKEN_1;
			end
			ST_ULPI_TOKEN_1:
			begin
				crc5_data <= {endp[3], endp[2], endp[1], endp[0], addr};
				phy_ulpi_wr_d <= {endp[0], addr};
				ulpi_state <= ST_ULPI_TOKEN_2;
			end
			ST_ULPI_TOKEN_2:
			begin
				phy_ulpi_wr_d <= {next_crc5, endp[3], endp[2], endp[1]};
				ulpi_state <= ST_ULPI_TOKEN_3;
			end
			ST_ULPI_TOKEN_3:
			begin
				phy_ulpi_dir <= 1'b0;
				// disable rxactive
				send_data <= {2'b00,
					2'b00 /* rx_event */,
					2'b11 /* vbus */,
					2'b00 /* linestate */};
				ulpi_state <= ST_ULPI_TX_LINK;
				ulpi_state_next <= ST_ULPI_TOKEN_4;
			end
			ST_ULPI_TOKEN_4:
			begin
				ulpi_state <= ulpi_state_next_saved_token;
			end

			/*** RX data on ULPI and save to recv_data reg ***/
			ST_ULPI_RX:
			begin
				phy_ulpi_dir <= 1'b0;
				phy_ulpi_nxt <= 1'b1;
				recv_data <= phy_ulpi_d;
				if (phy_ulpi_stp) begin
					ulpi_state <= ulpi_state_next;
					phy_ulpi_dir <= 1'b0;
				end
			end

			/*** TX data on link layer ***/
			ST_ULPI_TX_LINK:
			begin
				// notify link about link layer data
				// using rx_event field in rx cmd
				send_data <= {2'b00,
					2'b01 /* rx_event */,
					2'b11 /* vbus */,
					2'b00 /* linestate */};
				ulpi_state_next_saved <= ulpi_state_next;
				ulpi_state <= ST_ULPI_TX;
				ulpi_state_next <= ST_ULPI_TX_LINK_1;
				bc <= 0;
			end
			ST_ULPI_TX_LINK_1:
			begin
				// send actual data to link
				// send_data <= send_data_link;
				// ulpi_state <= ST_ULPI_TX;
				// ulpi_state_next <= ulpi_state_next_saved;
				ulpi_state <= ulpi_state_next_saved;
			end

			/*** TX data on ULPI from send_data reg ***/
			ST_ULPI_TX:
			begin
				phy_ulpi_dir <= 1'b1;
				phy_ulpi_nxt <= 1'b0;
				/* link state:
				* line_state  = [1:0];
				vbus_state  = [3:2];
				rx_event = [5:4]; */
				phy_ulpi_wr_d <= send_data;
				phy_ulpi_wr_en <= 1'b1;
				ulpi_state <= ST_ULPI_TX_1;
				bc <= 8'h0;
			end
			ST_ULPI_TX_1:
			begin
				if (bc == 3) begin
					// hold data on line for 2-3 cycles
					// transmission to link done
					// phy_ulpi_dir left as high
					ulpi_state <= ulpi_state_next;
				end
			end
		endcase
	end

	reg	[1:0]	ts_pid;
	reg	[7:0]	ts_dc;
	reg	[7:0]	ts_bc;
	reg	[7:0]	pattern;
	reg	[3:0]	counter;
	reg	[7:0]   ts_state;
	reg	[7:0]   ts_state_next;
	parameter [7:0]
		ST_TS_SEND_SYNC = 8'd0,
		ST_TS_SEND_PID = 8'd1,
		ST_TS_SEND_PID2 = 8'd2,
		ST_TS_SEND_COUNTER = 8'd5,
		ST_TS_SEND_PAYLOAD = 8'd10,
		ST_TS_SEND = 8'd11,
		ST_TS_DELAY = 8'd12;

	/* TS transfers */
	always @(posedge phy_clk ) begin
		ts_dc <= ts_dc + 1;

		case(ts_state)
			ST_TS_SEND_SYNC:
			begin
				indata <= 8'h47;
				i <= 0;
				ts_state <= ST_TS_SEND;
				ts_state_next <= ST_TS_SEND_PID;
				// atsc_start <= 1;
			end

			ST_TS_SEND_PID:
			begin
				// atsc_start <= 0;
				indata <= 8'h01;
				i <= 0;
				ts_state <= ST_TS_SEND;
				ts_state_next <= ST_TS_SEND_PID2;
			end

			ST_TS_SEND_PID2:
			begin
				indata <= 8'hfe + ts_pid;
				ts_pid <= ts_pid + 1;
				i <= 0;
				ts_state <= ST_TS_SEND;
				ts_state_next <= ST_TS_SEND_COUNTER;
			end

			ST_TS_SEND_COUNTER:
			begin
				indata <= {4'h0, counter};
				i <= 0;
				counter <= counter + 1;
				ts_state <= ST_TS_SEND;
				ts_state_next <= ST_TS_SEND_PAYLOAD;
				ts_bc <= 8'd184;
				pattern <= pattern + 1;
				// pattern <= 0;
			end

			ST_TS_SEND_PAYLOAD:
			begin
				if (ts_bc == 0)
				begin
					ts_state <= ST_TS_SEND_SYNC; // next TS packet
					// delay
				end else
				begin
					indata <= pattern;
					// pattern <= pattern + 1;
					i <= 0;
					ts_state <= ST_TS_SEND;
					ts_state_next <= ST_TS_SEND_PAYLOAD;
					ts_bc <= ts_bc - 1;
				end
			end

			// send 8 bit data
			ST_TS_SEND:
			begin
				@(negedge atsc_clock);
				atsc_valid <= 1;
				atsc_data <= indata[7-i];
				@(negedge atsc_clock);
				atsc_valid <= 0;
				i <= i + 1;
				if (i == 7) begin
					// ts_state <= ST_TS_DELAY;
					ts_state <= ts_state_next;
					ts_dc <= 0;
				end
			end

			ST_TS_DELAY:
			begin
				if (ts_dc > 4)
					ts_state <= ts_state_next;
			end
		endcase
	end

	/* serialize data from TS and write it to USB EP */
	initial
	begin
		/* set all signals initial values */
		reset = 1; // reset is active
		ulpi_state = ST_ULPI_RST;
		clk = 1'b0; // at time 0
		atsc_clock = 1'b0; // at time 0
		phy_clk = 1'b0; // at time 0
		atsc_data = 1'b0; // at time 0
		atsc_valid = 1'b0; // at time 0
		atsc_start = 1'b0; // at time 0
		phy_ulpi_dir = 1'b0; // at time 0
		phy_ulpi_nxt = 1'b0; // at time 0
		phy_ulpi_wr_en = 1'b0;
		phy_ulpi_wr_d = 8'h0;
		indata = 8'h00;
		ts_dc = 0;
		i = 0;
		ts_state = ST_TS_SEND_SYNC;
		ts_bc = 8'h0;
		counter = 8'h0;
		pattern = 8'h45;
		ts_pid = 1'b0;
		// go !
		#40 reset = 1'b0; // disable reset

		// decrease waitime in ulpi from 10msec to 0usec
		// this allows us to simulate smaller time range
		force ts_proxy_tb.USBTOP.ia.reset_waittime = 0;

		// block PID
		// @(negedge phy_clk);
		force ts_proxy_tb.DUT.ts_filter_inst.table_wr_address = 13'h176;
		force ts_proxy_tb.DUT.ts_filter_inst.table_data = 1'b1;
		force ts_proxy_tb.DUT.ts_filter_inst.table_wren = 1'b1;
		@(negedge phy_clk);
		force ts_proxy_tb.DUT.ts_filter_inst.table_wr_address = 13'h1ff;
		force ts_proxy_tb.DUT.ts_filter_inst.table_data = 1'b1;
		force ts_proxy_tb.DUT.ts_filter_inst.table_wren = 1'b1;
		@(negedge phy_clk);
		force ts_proxy_tb.DUT.ts_filter_inst.table_wren = 1'b0;
		// force ts_proxy_tb.DUT.ts_filter_inst.table_wr_address = 13'h178;
		// force ts_proxy_tb.DUT.ts_filter_inst.table_data = 1'b1;
		// force ts_proxy_tb.DUT.ts_filter_inst.table_wren = 1'b1;
		// @(negedge atsc_clock);
		// @(negedge atsc_clock);

		force ts_proxy_tb.DUT.ts_filter_inst.table_wren = 1'b0;

	end
endmodule
