

module top(
	input clk_25mhz,
	input [6:0] btn,
	input ftdi_txd,
	output [7:0] led,
	output [3:0] gpdi_dp, // gpdi_dn,
	output ftdi_rxd,
	output wifi_gpio0
);
	reg [31:0] ram[0:1023];
	reg [3:0] reset_cnt = 0;
	reg [31:0] ramdat_o;
	reg reset;
	reg [7:0] led_reg;
	wire ack_i;
	wire [31:0] dat_i;
	wire [31:0] dat_o;
	wire [31:0] adr_o;
	wire [3:0] sel_o;
	wire stb_o;
	wire we_o;
	wire irq;
	wire reset_cnt_stop;
	wire [7:0] bnksel;
	wire [9:0] raddr;
	wire [3:0] unused_gpdi_dn;
	wire video_stb, uart_stb;
	wire [31:0] video_dat_o, uart_dat_o;
	wire video_ack, uart_ack;

	initial $readmemh("firmware.hex", ram);

	assign reset_cnt_stop = &reset_cnt;
	assign bnksel = adr_o[31:24];
	assign raddr = adr_o[11:2];

	assign ack_i = (bnksel == 8'h02) ? video_ack : (bnksel == 8'h03) ? uart_ack : stb_o;
	assign dat_i = (bnksel == 8'h02) ? video_dat_o : (bnksel == 8'h03) ? uart_dat_o : ramdat_o;

    // Tie GPIO0, keep board from rebooting
    assign wifi_gpio0 = 1'b1;

	assign irq = 1'b0;

	assign led = led_reg;

	assign video_stb = (bnksel == 8'h02) & stb_o;
	assign uart_stb = (bnksel == 8'h03) & stb_o;

	cpu cpu(
		.clk(clk_25mhz),
		.rst_i(reset),
		.dat_i(dat_i),
		.ack_i(ack_i),
		.irq(irq),
		.we_o(we_o),
		.stb_o(stb_o),
		.adr_o(adr_o),
		.dat_o(dat_o),
		.sel_o(sel_o)
	);

	video video(
		.clk_25mhz(clk_25mhz),
		.rst_i(reset),
		.adr_i(adr_o[13:0]),
		.dat_i(dat_o),
		.sel_i(sel_o),
		.we_i(we_o),
		.stb_i(video_stb),
		.ack_o(video_ack),
		.dat_o(video_dat_o),
		.gpdi_dp(gpdi_dp),
		.gpdi_dn(unused_gpdi_dn)
	);

	uart uart(
		.clk(clk_25mhz),
		.rst_i(reset),
		.adr_i(adr_o[3:0]),
		.dat_i(dat_o),
		.sel_i(sel_o),
		.we_i(we_o),
		.stb_i(uart_stb),
		.ack_o(uart_ack),
		.dat_o(uart_dat_o),
		.rxd(ftdi_txd),
		.txd(ftdi_rxd)
	);

	always @(posedge clk_25mhz) begin
		if (btn[0] == 1'b0) begin
			reset_cnt <= 0;
			reset <= 1;
			led_reg <= 8'h00;
		end else begin
			reset_cnt <= reset_cnt + {3'b000, !reset_cnt_stop};
			reset <= !reset_cnt_stop;
		end
		if (stb_o == 1'b1) begin
			if (we_o == 1'b1) begin
				case (bnksel)
					8'h00: begin
						if (sel_o[0]) ram[raddr][7:0] <= dat_o[7:0];
						if (sel_o[1]) ram[raddr][15:8] <= dat_o[15:8];
						if (sel_o[2]) ram[raddr][23:16] <= dat_o[23:16];
						if (sel_o[3]) ram[raddr][31:24] <= dat_o[31:24];
					end
					8'h01: begin
						if (sel_o[0])
							led_reg <= dat_o[7:0];
					end
					default: begin
					end
				endcase
			end else begin
				case (bnksel)
					8'h00: begin
						ramdat_o[7:0] <= sel_o[0] ? ram[raddr][7:0] : 8'h00;
						ramdat_o[15:8] <= sel_o[1] ? ram[raddr][15:8] : 8'h00;
						ramdat_o[23:16] <= sel_o[2] ? ram[raddr][23:16] : 8'h00;
						ramdat_o[31:24] <= sel_o[3] ? ram[raddr][31:24] : 8'h00;
					end
					8'h01: begin
						ramdat_o[6:0] <= btn[6:0];
					end
					default: begin
					end
				endcase
			end
		end
	end
endmodule
