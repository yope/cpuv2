
module video(
	input clk_25mhz,
	input rst_i,
	input [13:0] adr_i,
	input [31:0] dat_i,
	input [3:0] sel_i,
	input we_i,
	input stb_i,
	output ack_o,
	output reg [31:0] dat_o,
	output [3:0] gpdi_dp, gpdi_dn
);
	reg [7:0] chargen[0:4095];
	reg [7:0] ram[0:4799];
	reg [7:0] colorram[0:4799];
	reg [23:0] palette[0:15];
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
	wire [23:0] fgcolor, bgcolor;
	reg [3:0] fgcidx, bgcidx;
	reg [7:0] charcode;

	assign col = x[9:3];
	assign row = y[8:3];
	assign ramidx = {row, 6'b000000} + {2'b00, row, 4'b0000} + {5'b00000, col};
	assign cidx = {1'b1, charcode};
	assign cx = 7 - x[2:0];
	assign cy = y[2:0];
	assign cgenaddr = {cidx, cy};
	assign ack_o = stb_i;
	assign fgcolor = palette[fgcidx];
	assign bgcolor = palette[bgcidx];

	function [7:0] f_datbi(input [1:0] seladr, input [31:0] dat);
		case (seladr)
			2'b00: f_datbi = dat[7:0];
			2'b01: f_datbi = dat[15:8];
			2'b10: f_datbi = dat[23:16];
			2'b11: f_datbi = dat[31:24];
		endcase
	endfunction

	function [31:0] f_datbo(input [1:0] seladr, input [7:0] dat);
		case (seladr)
			2'b00: f_datbo = {24'h000000, dat};
			2'b01: f_datbo = {16'h0000, dat, 8'h00};
			2'b10: f_datbo = {8'h00, dat, 16'h0000};
			2'b11: f_datbo = {dat, 24'h000000};
		endcase
	endfunction

	integer i;

	initial begin
		$readmemh("chargen.hex", chargen);
		palette[0] = 24'h000000;
		palette[1] = 24'hffffff;
		palette[2] = 24'hff0000;
		palette[3] = 24'h00ff00;
		palette[4] = 24'h0000ff;
		palette[5] = 24'hffff00;
		palette[6] = 24'h00ffff;
		palette[7] = 24'hff00ff;
		palette[8] = 24'h888888;
		palette[9] = 24'hcccccc;
		palette[10] = 24'hff8888;
		palette[11] = 24'h88ff88;
		palette[12] = 24'h8888ff;
		palette[13] = 24'h88ffff;
		palette[14] = 24'hff88ff;
		palette[15] = 24'hffff88;
	end

	assign color = chargen[cgenaddr][cx] ? fgcolor : bgcolor;

	hdmi_video hdmi_video
	(
		.clk_25mhz(clk_25mhz),
		.x(x),
		.y(y),
		.color(color),
		.gpdi_dp(gpdi_dp),
		.gpdi_dn(gpdi_dn),
	);

	always @(posedge clk_25mhz) begin
		if (stb_i) begin
			if (we_i) begin
				if (adr_i[13])
					colorram[adr_i[12:0]] <= f_datbi(adr_i[1:0], dat_i);
				else
					ram[adr_i[12:0]] <= f_datbi(adr_i[1:0], dat_i);
			end else begin
				if (adr_i[13])
					dat_o <= f_datbo(adr_i[1:0], colorram[adr_i[12:0]]);
				else
					dat_o <= f_datbo(adr_i[1:0], ram[adr_i[12:0]]);
			end
		end
	end

	always @(negedge clk_25mhz) begin
		fgcidx <= colorram[ramidx[12:0]][3:0];
		bgcidx <= colorram[ramidx[12:0]][7:4];
		charcode <= ram[ramidx[12:0]];
	end
endmodule
