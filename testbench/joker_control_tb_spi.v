// testbench

`timescale 1 ns / 100 ps

module joker_control_tb_spi ();
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

	/* SPI flash pins */
	wire	FLASH_SCLK;
	wire	FLASH_MOSI;
	wire	FLASH_MISO;
	wire	FLASH_nCS;

	// SPI slave model
	spi_slave_model i_spi_slave (
		.rst(reset), .ss(FLASH_nCS), .sclk(FLASH_SCLK), .mosi(FLASH_MOSI), .miso(FLASH_MISO)
	);

	joker_control DUT (
		.clk(phy_clk /* clk */),
		.reset(reset),

		/* SPI flash pins */
		.FLASH_SCLK(FLASH_SCLK),
		.FLASH_MOSI(FLASH_MOSI),
		.FLASH_MISO(FLASH_MISO),
		.FLASH_nCS(FLASH_nCS),


		/* EP1 IN */
		.usb_in_addr_o(ep1_buf_in_addr),
		.usb_in_data_o(ep1_buf_in_data),
		.usb_in_wren_o(ep1_buf_in_wren),
		.usb_in_ready(ep1_buf_in_ready),
		.usb_in_commit(ep1_buf_in_commit),
		.usb_in_commit_len(ep1_buf_in_commit_len),
		.usb_in_commit_ack(ep1_buf_in_commit_ack),


		/* EP2 OUT */
		.buf_out_hasdata(buf_out_hasdata), 
		.buf_out_len(buf_out_len), 
		.buf_out_q(buf_out_q),
		.buf_out_addr_o(buf_out_addr),
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
	begin
		#8.33 phy_clk = ~phy_clk; // 60MHz ULPI
		// FLASH_MISO = ~FLASH_MISO;
	end

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
		i_spi_slave.rx_negedge = 1'b0;
		i_spi_slave.tx_negedge = 1'b0;
		// FLASH_MISO = 0; // emulate 0xFF data
		#40 reset = 1'b0; // disable reset

		@(negedge phy_clk);
		@(negedge phy_clk);

		/** opencores SPI init **/
		if(~buf_in_ready)
			@(posedge buf_in_ready);
		/* SPI cmd */
		buf_in_addr <= 0;
		buf_in_data <= 8'd30; /* J_CMD_SPI */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h02; /* page program */
		// buf_in_data <= 8'h9F; /* JEDEC read  READ IDENTIFICATION */
		@(negedge phy_clk);
		buf_in_addr <= 2;
		buf_in_data <= 8'h11; /* read back Manufacturer Identification */
		@(negedge phy_clk);
		buf_in_addr <= 3;
		buf_in_data <= 8'h22; /* read back Memory Type */
		@(negedge phy_clk);
		buf_in_addr <= 4;
		buf_in_data <= 8'h33; /* read back Memory Capacity */
		@(negedge phy_clk);
		buf_in_commit_len <= 5;
		buf_in_commit <= 1;
		@(negedge buf_in_commit_ack)
		buf_in_commit <= 0;
		buf_in_wren <= 0;
		@(negedge phy_clk);

		if(~buf_in_ready)
			@(posedge buf_in_ready);
		buf_in_addr <= 0;
		buf_in_data <= 8'd30; /* J_CMD_SPI */
		buf_in_wren <= 1;
		@(negedge phy_clk);
		buf_in_addr <= 1;
		buf_in_data <= 8'h05; /* read status */
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


	end

endmodule
