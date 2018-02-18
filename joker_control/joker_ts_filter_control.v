//
// Joker TV
// (c) Abylay Ospan, 2017
// aospan@jokersys.com
// https://jokersys.com
// GPLv2

module joker_ts_filter_control
(
	input		wire	clk,
	input		wire	reset,
	input		wire	[7:0] j_cmd,
	output	reg	ack_o,
	
	/* EP2 OUT */
	input		wire	[7:0] buf_out_q,
	output	reg	[10:0] buf_out_addr,
	
	output	reg [12:0]  table_wr_address,
	output	reg [0:0]  table_data,
	output	reg table_wren
);

`include "joker_control.vh"

reg [12:0] pid;
reg pattern;
reg [7:0] cmd;
reg [7:0] dc;
reg [7:0] offset;
reg [7:0] ts_filter_control_state;

parameter	ST_TS_FILTER_CONTROL_IDLE=0,
		ST_TS_FILTER_CONTROL_PROCESS=1,
		ST_TS_FILTER_CONTROL_CMD=2,
		ST_TS_FILTER_CONTROL_CMD_PROCESS=3,
		ST_TS_FILTER_CONTROL_UPDATE_BULK=4,
		ST_TS_FILTER_CONTROL_READ_PID_HI=5,
		ST_TS_FILTER_CONTROL_READ_PID_LO=6,
		ST_TS_FILTER_CONTROL_UPDATE_ONE=7,
		ST_TS_FILTER_CONTROL_DONE=8,
		ST_TS_FILTER_CONTROL_UPDATE_BULK1=9;

always @(posedge clk) begin
	dc <= dc + 1;
	
	case(ts_filter_control_state)
	ST_TS_FILTER_CONTROL_IDLE:
	begin
		ack_o <= 0;
		if(j_cmd == J_CMD_TS_FILTER)
		begin
			/* process CI rw */
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_CMD;
			buf_out_addr <= 1; /* read cmd */
			dc <= 0;
		end
	end
	ST_TS_FILTER_CONTROL_CMD:
	begin
		if (dc > 2) begin
			cmd <= buf_out_q;
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_CMD_PROCESS;
		end
	end
	ST_TS_FILTER_CONTROL_CMD_PROCESS:
	begin
		case (cmd)
		8'h0: // all pid allow
		begin
			pattern <= 0;
			table_wr_address <= 0;
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_UPDATE_BULK;
		end
		8'h1: // all pid block
		begin
			pattern <= 1;
			table_wr_address <= 0;
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_UPDATE_BULK;
		end
		8'h2: // allow one pid
		begin
			pattern <= 0;
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_READ_PID_HI;
		end
		8'h3: // block one pid
		begin
			pattern <= 1;
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_READ_PID_HI;
		end
		default:
		begin
			// unknown sub-cmd
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_DONE;
		end
		endcase
		buf_out_addr <= 2; /* read pid hi */
		dc <= 0;
	end
	ST_TS_FILTER_CONTROL_READ_PID_HI:
	begin
		if (dc > 2) begin
			pid[12:8] <= buf_out_q[4:0];
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_READ_PID_LO;
			buf_out_addr <= 3; /* read pid lo */
			dc <= 0;
		end
	end
	ST_TS_FILTER_CONTROL_READ_PID_LO:
	begin
		if (dc > 2) begin
			pid[7:0] <= buf_out_q[7:0];
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_UPDATE_ONE;
		end
	end
	
	ST_TS_FILTER_CONTROL_UPDATE_ONE:
	begin
		table_wr_address <= pid;
		table_data <= pattern;
		table_wren <= 1;
		ts_filter_control_state <= ST_TS_FILTER_CONTROL_DONE;
	end
	
	ST_TS_FILTER_CONTROL_UPDATE_BULK:
	begin
		table_wr_address <= 13'd8191;
		table_wren <= 1;
		table_data <= pattern;
		ts_filter_control_state <= ST_TS_FILTER_CONTROL_UPDATE_BULK1;
	end	
	ST_TS_FILTER_CONTROL_UPDATE_BULK1:
	begin
		if (table_wr_address == 0)
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_DONE;
		table_wr_address <= table_wr_address - 1;
	end
	
	ST_TS_FILTER_CONTROL_DONE:
	begin
		table_wren <= 0;
		ack_o <= 1;
		if (j_cmd != J_CMD_TS_FILTER) /* upper layer accept our ack */
			ts_filter_control_state <= ST_TS_FILTER_CONTROL_IDLE;
	end
	
	default: ts_filter_control_state <= ST_TS_FILTER_CONTROL_IDLE;
	endcase
	
	if (reset)
	begin
		ack_o <= 0;
		dc <= 0;
		pattern <= 0;
		table_wr_address <= 0;
		pid <= 0;
		table_wren <= 0;
		table_data <= 0;
		ts_filter_control_state <= ST_TS_FILTER_CONTROL_IDLE;
	end
end

endmodule
