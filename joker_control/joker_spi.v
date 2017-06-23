//
// Joker TV
// SPI interface
// (c) Abylay Ospan, 2017
// aospan@jokersys.com
// https://jokersys.com
// GPLv2

`include "../spi/rtl/verilog/spi_defines.v"

module joker_spi
(
	input		wire	clk,
	input		wire	reset,
	
	input		wire	[7:0] j_cmd,
	output	reg	ack_o,
	
	/* EP2 OUT */
   input    wire  buf_out_hasdata, 
	input		wire	[9:0] buf_out_len, 
	input		wire	[7:0] buf_out_q,
	output	wire	[10:0] buf_out_addr,
	input		wire	buf_out_arm_ack,
	output	reg	buf_out_arm,
	
	/* EP1 IN */
   input    wire  usb_in_commit_ack,
	input		wire	usb_in_ready,
   output   reg  usb_in_commit,
	output	wire	[ 10:0]   usb_in_addr,
	output	reg	[ 7:0]   usb_in_data,
	output	reg	usb_in_wren,
	output	reg	[ 10:0]   usb_in_commit_len,

	/* SPI flash pins */
	output		wire	FLASH_SCLK,
	output		wire	FLASH_MOSI,
	input			wire	FLASH_MISO,
	output		wire	FLASH_nCS
);

`include "joker_control.vh"

// SPI
  reg [31:0] adr;
  wire [31:0] dat_i;
	reg [31:0] dat_o;
  reg        we;
  reg  [3:0] sel;
  reg        stb;
  reg        cyc;
  wire        err;
  wire        s_int;
  wire			ack;
  // reg		[31:0] q;

// SPI master core
spi_top i_spi_top (
	.wb_clk_i(clk), .wb_rst_i(reset),
	.wb_adr_i(adr[4:0]), .wb_dat_i(dat_o), .wb_dat_o(dat_i),
	.wb_sel_i(sel), .wb_we_i(we), .wb_stb_i(stb),
	.wb_cyc_i(cyc), .wb_ack_o(ack), .wb_err_o(err), .wb_int_o(s_int),
	.ss_pad_o(FLASH_nCS), .sclk_pad_o(FLASH_SCLK), .mosi_pad_o(FLASH_MOSI), .miso_pad_i(FLASH_MISO)
);

/* state machine */
reg [3:0] spi_state;
reg [3:0] spi_next_state;
parameter	ST_SPI_IDLE=0, 
				ST_SPI_WRITE=1, 
				ST_SPI_READ=2,
				ST_SPI_READ2=3,
				ST_SPI_READ_USB=4,
				ST_SPI_WAIT_ACK=5,
				ST_SPI_ACK=6,
				ST_SPI_PREPARE=7,
				ST_SPI_CYCLE=8,
				ST_SPI_READ_SPI=9,
				ST_SPI_WRITE_USB=10,
				ST_SPI_CYCLE2=11,
				ST_SPI_CYCLE3=12,
				ST_SPI_CYCLE_WRITE_CS=13,
				ST_SPI_FINISH=14
				;

reg [31:0] source;
reg [511:0] probe;

/*
`ifndef MODEL_TECH
probe	probe_inst(
	.probe( probe ),
	.source(source)
);
`endif
*/

parameter dwidth = 32;
parameter awidth = 32;

reg	[15:0] cnt;
reg	do_read;
reg	[10:0] ep_addr;

assign	buf_out_addr = ep_addr;
assign	usb_in_addr = ep_addr - 1;


always @(posedge clk) begin
	probe[35:32] <= spi_state;
	cnt <= cnt + 1;
	
	case(spi_state)
	ST_SPI_PREPARE:
	begin
		/* set spi divider */
		adr[7:0] <= `SPI_DEVIDE;
		sel <= 2'b01; /* set one octets */
		dat_o[7:0] <= 8'h0; /* about 25mhz. Formula: Fspi = Fclk/((DIVIDER+1)*2) */
		do_read <= 0;
		spi_next_state <= ST_SPI_IDLE;
		spi_state <= ST_SPI_WRITE;
	end
	
	ST_SPI_IDLE:
	begin
		ack_o <= 0;
		if(j_cmd == J_CMD_SPI)
		begin
			/* process SPI data */
			cnt <= 0;
			spi_state <= ST_SPI_READ_USB;
			usb_in_commit_len <= buf_out_len /* + 1 */;
			ep_addr <= 1; /* start read from addr 1 */
		end
	end
	ST_SPI_READ_USB:
	begin
		if (cnt > 2 /* wait ep a little at start*/)
		begin
			usb_in_wren <= 0;
			if(ep_addr < buf_out_len)
			begin
				adr[7:0] <= `SPI_TX_0; /* TX reg */
				sel <= 2'b01; /* set one octets */
				dat_o[7:0] <= buf_out_q[7:0];
				spi_state <= ST_SPI_WRITE;
				spi_next_state <= ST_SPI_CYCLE_WRITE_CS /* ST_SPI_READ_USB */;
				ep_addr <= ep_addr + 1;
				do_read <= 1;
			end else
			begin
				spi_state <= ST_SPI_FINISH /* ST_SPI_ACK */; /* we are done */
			end
		end
	end
	
	ST_SPI_CYCLE_WRITE_CS:
	begin
		/* select chip 1 */
		adr[7:0] <= `SPI_SS; /* CS reg */
		dat_o[31:0] <= 8'd1;
		sel <= 2'b01; /* set one octets */
		spi_state <= ST_SPI_WRITE;
		spi_next_state <= ST_SPI_CYCLE;
	end	
	
	ST_SPI_CYCLE:
	begin
		/* start transfer: set 'GO' bit, length, etc */
		adr[7:0] <= `SPI_CTRL; 
		dat_o[`SPI_CTRL_CHAR_LEN] <= 7'd8;
		dat_o[`SPI_CTRL_GO] <= 1; /* set 'GO' bit */
		dat_o[`SPI_CTRL_RX_NEGEDGE] <= 0;
		dat_o[`SPI_CTRL_TX_NEGEDGE] <= 1;
		dat_o[`SPI_CTRL_RES_1] <= 0;
		sel <= 2'b11; /* set two octets */
		spi_state <= ST_SPI_WRITE;
		spi_next_state <= ST_SPI_CYCLE2;
	end
	
	ST_SPI_CYCLE2:
	begin
		adr[7:0] <= `SPI_CTRL; 
		spi_state <= ST_SPI_READ;
		spi_next_state <= ST_SPI_CYCLE3;
	end
	
	ST_SPI_CYCLE3:
	begin
		/* wait 'GO' bit clear */
		if(dat_i[8])
			spi_state <= ST_SPI_CYCLE2;
		else
			spi_state <= ST_SPI_READ_SPI;
	end
	
	ST_SPI_READ_SPI:
	begin
		adr[7:0] <= `SPI_RX_0;
		spi_state <= ST_SPI_READ;
		spi_next_state <= ST_SPI_WRITE_USB;
	end
	
	ST_SPI_WRITE_USB:
	begin
		usb_in_wren <= 1;
		cnt <= 0;
		usb_in_data <= dat_i;
		spi_state <= ST_SPI_READ_USB; /* process next byte */
	end
	
	ST_SPI_WRITE:
	begin
		cyc <= 1'b1;
		stb <= 1'b1;
		we <= 1'b1;
		spi_state <= ST_SPI_WAIT_ACK;
	end
	ST_SPI_WAIT_ACK:
	begin
		if(ack)
		begin
			cyc <= 1'b0;
			we <= 1'b0;
			stb <= 1'b0;
			spi_state <= spi_next_state;
		end
	end
	ST_SPI_READ:
	begin
		cyc <= 1'b1;
		we <= 1'b0;
		stb <= 1'b1;
		spi_state <= ST_SPI_READ2;
	end
	ST_SPI_READ2:
	begin
		if(ack)
		begin
			cyc <= 1'b0;
			we <= 1'b0;
			stb <= 1'b0;
			spi_state <= spi_next_state;
		end
	end
	
	ST_SPI_FINISH:
	begin
		/* deselect chip 1 */
		adr[7:0] <= `SPI_SS; /* CS reg */
		dat_o[31:0] <= 8'd0;
		sel <= 2'b01; /* set one octets */
		spi_state <= ST_SPI_WRITE;
		spi_next_state <= ST_SPI_ACK;
	end
	
	ST_SPI_ACK:
	begin
		ack_o <= 1;
		if (j_cmd != J_CMD_SPI) /* upper layer accept our ack */
			spi_state <= ST_SPI_IDLE;
	end
	default: spi_state <= ST_SPI_IDLE;
	endcase
	
	if (reset)
	begin
		probe <= 0;
		// go_2 <= 0;
		// go_1 <= 0;
		ack_o <= 0;
		do_read <= 0;
		cyc <= 1'b0;
		we <= 1'b0;
		stb <= 1'b0;		
		dat_o <= 0;
		adr <= 0;
		sel <= 0;
		spi_state <= ST_SPI_PREPARE;
	end
end

endmodule
