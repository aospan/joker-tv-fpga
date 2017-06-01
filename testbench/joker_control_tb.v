// testbench

`timescale 1 ns / 100 ps

module joker_control_tb ();
	reg clk;
	reg phy_clk;
	reg reset;
	reg [7:0] indata;
	reg [7:0] i;
	reg [11:0] bytes_sent;

	/* EP1 IN */
	wire	[10:0]	ep1_buf_in_addr;
	wire	[7:0]	ep1_buf_in_data;
	wire	ep1_buf_in_wren;
	wire ep1_buf_in_ready;
	wire	ep1_buf_in_commit;
	wire	[10:0]	ep1_buf_in_commit_len;
	wire ep1_buf_in_commit_ack;

	/* EP2 OUT */
	reg [10:0]	buf_in_addr;
	reg [7:0]	buf_in_data;
	reg buf_in_wren;
	wire buf_in_ready;
	reg buf_in_commit;
	reg [10:0]	buf_in_commit_len;
	wire buf_in_commit_ack;

	wire  buf_out_hasdata;
	wire	[9:0] buf_out_len;
	wire	[7:0] buf_out_q;
	wire	[10:0] buf_out_addr;
	wire	buf_out_arm_ack;
	wire	buf_out_arm;

	wire	io_scl;
	wire	io_sda;
	reg	io_scl_val;
	reg	io_sda_val;

	joker_control DUT (
		.clk(phy_clk /* clk */),
		.reset(reset),

		/* EP1 IN */
		.usb_in_addr(ep1_buf_in_addr),
		.usb_in_data(ep1_buf_in_data),
		.usb_in_wren(ep1_buf_in_wren),
		.usb_in_ready(ep1_buf_in_ready),
		.usb_in_commit(ep1_buf_in_commit),
		.usb_in_commit_len(ep1_buf_in_commit_len),
		.usb_in_commit_ack(ep1_buf_in_commit_ack),


		/* EP2 OUT */
		.buf_out_hasdata(buf_out_hasdata), 
		.buf_out_len(buf_out_len), 
		.buf_out_q(buf_out_q),
		.buf_out_addr(buf_out_addr),
		.buf_out_arm_ack(buf_out_arm_ack),
		.buf_out_arm(buf_out_arm),
		.io_scl(io_scl),
		.io_sda(io_sda)
	);


	/* EP2 OUT */
	usb2_ep USBEP (
		.phy_clk(phy_clk),
		.rd_clk(phy_clk),
		.reset_n(~reset),
		.wr_clk(phy_clk),
		.fast_commit(0),

		.buf_in_addr(buf_in_addr),
		.buf_in_data(buf_in_data),
		.buf_in_wren(buf_in_wren),
		.buf_in_ready(buf_in_ready),
		.buf_in_commit(buf_in_commit),
		.buf_in_commit_len(buf_in_commit_len),
		.buf_in_commit_ack(buf_in_commit_ack),

		.buf_out_hasdata(buf_out_hasdata),
		.buf_out_addr(buf_out_addr),
		.buf_out_q(buf_out_q),
		.buf_out_len(buf_out_len),
		.buf_out_arm(buf_out_arm),
		.buf_out_arm_ack(buf_out_arm_ack)
		);


	/* EP1 IN */
	usb2_ep USBEP_IN (
		.phy_clk(phy_clk),
		.rd_clk(phy_clk),
		.reset_n(~reset),
		.wr_clk(phy_clk),
		.fast_commit(0),

		.buf_in_addr(ep1_buf_in_addr),
		.buf_in_data(ep1_buf_in_data),
		.buf_in_wren(ep1_buf_in_wren),
		.buf_in_ready(ep1_buf_in_ready),
		.buf_in_commit(ep1_buf_in_commit),
		.buf_in_commit_len(ep1_buf_in_commit_len),
		.buf_in_commit_ack(ep1_buf_in_commit_ack)
		);

		assign io_scl = io_scl_val;
		assign io_sda = io_sda_val;
	// create clock
	always
		#10 clk = ~clk; // every ten nanoseconds invert

	always
		#8.33 phy_clk = ~phy_clk; // 60MHz ULPI

	/* serialize data from TS and write it to USB EP */
	initial
	begin
		/* set all signals initial values */
		reset = 1; // reset is active
		clk = 1'b0; // at time 0
		phy_clk = 1'b0; // at time 0
		indata = 8'h00;
		i = 0;
		buf_in_commit = 0;
		buf_in_commit_len = 0;
		buf_in_addr = 0;
		buf_in_data = 0;
		buf_in_wren = 0;
		io_scl_val = 1;
		io_sda_val = 1;
		#40 reset = 1'b0; // disable reset


		@(negedge phy_clk);
		@(negedge phy_clk);

		/** opencores i2c init **/
		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* i2c clock HI/LO */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0a; /* I2C write jcmd */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h00;
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'h18;
		@(negedge phy_clk);
		buf_in_commit_len <= 3;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		buf_in_addr <= 0;
		buf_in_data <= 8'h0a; /* I2C write jcmd */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h01;
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'h00;
		@(negedge phy_clk);
		buf_in_commit_len <= 3;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* enable core and interrupts */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0a; /* I2C write jcmd */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h02;
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'hc0;
		@(negedge phy_clk);
		buf_in_commit_len <= 3;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* prepare TX */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0a; /* I2C write jcmd */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h03;
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'h60; /* chip addr on i2c bus */
		@(negedge phy_clk);
		buf_in_commit_len <= 3;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* actual TX */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0a; /* I2C write jcmd */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h04;
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'hd0;
		@(negedge phy_clk);
		buf_in_commit_len <= 3;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* jcmd: read i2c */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0b; /* I2C read jcmd */
		@(negedge phy_clk);
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h00; /* prer lo*/
		// buf_in_data <= 8'h04; /* status reg */
		@(negedge phy_clk);
		buf_in_commit_len <= 2;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* jcmd: read i2c */
		buf_in_addr <= 0;
		buf_in_data <= 8'h0b; /* I2C read jcmd */
		@(negedge phy_clk);
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h04; /* status reg */
		@(negedge phy_clk);
		buf_in_commit_len <= 2;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

	end

endmodule
