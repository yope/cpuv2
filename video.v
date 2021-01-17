
module video(
	input clk_25mhz,
	input rst_i,
	input [12:0] adr_i,
	input [31:0] dat_i,
	input [3:0] sel_i,
	input we_i,
	input stb_i,
	output ack_o,
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

	assign col = x[9:3];
	assign row = y[8:3];
	assign ramidx = {row, 6'b000000} + {2'b00, row, 4'b0000} + {5'b00000, col};
	assign cidx = {1'b1, ram0[ramidx[12:0]]};
	assign cx = 7 - x[2:0];
	assign cy = y[2:0];
	assign cgenaddr = {cidx, cy};
	assign ack_o = stb_i;

	integer i;

	initial begin
		$readmemh("chargen.hex", chargen);
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
		if (stb_i) begin
			if (we_i & sel_i[0]) begin
				ram0[adr_i] <= dat_i[7:0];
				ram1[adr_i] <= dat_i[7:0];
			end else if (sel_i[0]) begin
				dat_o[7:0] <= ram1[adr_i];
			end
		end
	end
endmodule
