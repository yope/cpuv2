
module video(
	input clk_25mhz,
	input rst_i,
	input [12:0] adr_i,
	input [31:0] dat_i,
	input [3:0] sel_i,
	input we_i,
	input stb_i,
	output reg ack_o,
	output reg [31:0] dat_o,
	output [3:0] gpdi_dp, gpdi_dn
);
	reg [7:0] chargen[0:4095];
	reg [7:0] ram0[0:4799];
	reg [7:0] ram1[0:4799];
	wire [23:0] color;
	wire [9:0] x;
	wire [9:0] y;
	wire [8:0] cidx;
	wire [2:0] cx;
	wire [2:0] cy;
	wire [11:0] cgenaddr;
	wire [6:0] col;
	wire [5:0] row;
	wire [12:0] ramidx;
	reg write, read;
	reg [7:0] wdata;
	reg [12:0] waddr, raddr;
	reg [2:0] state;

	assign col = x[9:3];
	assign row = y[8:3];
	assign ramidx = {row, 6'b000000} + {2'b00, row, 4'b0000} + {5'b00000, col};
	assign cidx = {1'b1, ram0[ramidx[12:0]]};
	assign cx = 7 - x[2:0];
	assign cy = y[2:0];
	assign cgenaddr = {cidx, cy};

	integer i;

	initial begin
		$readmemh("chargen.hex", chargen);
		for (i = 0; i < 4800; i = i + 1) begin
			ram0[i] = 8'h00;
			ram1[i] = 8'h00;
		end
	end

	assign color = chargen[cgenaddr][cx] ? 24'hffffff : 24'h000000;

	hdmi_video hdmi_video
	(
		.clk_25mhz(clk_25mhz),
		.x(x),
		.y(y),
		.color(color),
		.gpdi_dp(gpdi_dp),
		.gpdi_dn(gpdi_dn)
	);

	always @(posedge clk_25mhz) begin
		if (rst_i) begin
			state <= 3'b000;
		end else begin
			case (state)
				3'b000: begin
					if (stb_i) begin
						if (we_i & sel_i[0]) begin
							wdata <= dat_i[7:0];
							waddr <= adr_i;
							ack_o <= 1;
							state <= 3'b001;
						end else if (sel_i[0]) begin
							raddr <= adr_i;
							state <= 3'b100;
						end
					end
				end
				3'b001: begin
					ram0[waddr] <= wdata;
					ram1[waddr] <= wdata;
					state <= 3'b010;
				end
				3'b010: begin
					ack_o <= 0;
					state <= 3'b000;
				end
				3'b100: begin
					state <= 3'b101;
					ack_o <= 1;
					dat_o <= ram1[raddr];
				end
				3'b101: begin
					state <= 3'b110;
				end
				3'b110: begin
					ack_o <= 0;
					state <= 3'b000;
				end
				default: begin
					state <= 3'b000;
				end
			endcase
		end
	end
endmodule
