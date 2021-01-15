
module video(
	input clk_25mhz,
	output [3:0] gpdi_dp, gpdi_dn
);
	wire [23:0] color;
	wire [9:0] x;
	wire [9:0] y;

	assign color = x[4] ^ y[4] ? 24'hffffff : {x[7:0], y[7:0], x[9:2]};

	hdmi_video hdmi_video
	(
		.clk_25mhz(clk_25mhz),
		.x(x),
		.y(y),
		.color(color),
		.gpdi_dp(gpdi_dp),
		.gpdi_dn(gpdi_dn)
	);
endmodule
