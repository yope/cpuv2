

module top(
	input clk_25mhz,
`ifdef VERILATOR
	input clk_20mhz,
`endif
	input [6:0] btn,
	input ftdi_txd,
	inout [27:0] gp, gn,
	output [7:0] led,
	output [3:0] gpdi_dp, // gpdi_dn,
	output ftdi_rxd,
	output wifi_gpio0
);
	reg [31:0] ram[0:2047];
	reg [3:0] reset_cnt = 0;
	reg [31:0] ramdat_o;
	reg reset;
	reg [7:0] led_reg;
	reg [3:0] irq, irq0;
	wire ack_i;
	wire [31:0] dat_i;
	wire [31:0] dat_o;
	wire [31:0] adr_o;
	wire [3:0] sel_o;
	wire stb_o;
	wire we_o;
	wire [3:0] irqack;
	wire reset_cnt_stop;
	wire [7:0] bnksel;
	wire [10:0] raddr;
	wire [3:0] unused_gpdi_dn;
	wire video_stb, uart_stb, enet_stb;
	wire [31:0] video_dat_o, uart_dat_o, enet_dat_o;
	wire video_ack, uart_ack, enet_ack;

	wire enet_rxp, enet_rxn, enet_txp, enet_txn;

	initial $readmemh("firmware.hex", ram);

	assign reset_cnt_stop = &reset_cnt;
	assign bnksel = adr_o[31:24];
	assign raddr = adr_o[12:2];

	assign ack_i = (bnksel == 8'h02) ? video_ack : (bnksel == 8'h03) ? uart_ack : (bnksel == 8'h04) ? enet_ack : stb_o;
	assign dat_i = (bnksel == 8'h02) ? video_dat_o : (bnksel == 8'h03) ? uart_dat_o : (bnksel == 8'h04) ? enet_dat_o : ramdat_o;

	// Tie GPIO0, keep board from rebooting
	assign wifi_gpio0 = 1'b1;

	assign led = led_reg;

	assign video_stb = (bnksel == 8'h02) & stb_o;
	assign uart_stb = (bnksel == 8'h03) & stb_o;
	assign enet_stb = (bnksel == 8'h04) & stb_o;

	assign gp[20] = enet_txp;
	assign gn[20] = enet_txn;

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
		.sel_o(sel_o),
		.irqack(irqack)
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

	mac enet(
		.clk_i(clk_25mhz),
`ifdef VERILATOR
		.clk_20mhz(clk_20mhz),
`endif
		.rst_i(reset),
		.adr_i(adr_o[12:0]),
		.dat_i(dat_o),
		.sel_i(sel_o),
		.we_i(we_o),
		.stb_i(enet_stb),
		.ack_o(enet_ack),
		.dat_o(enet_dat_o),
		.rxd_in_p(enet_rxp),
		.rxd_in_n(enet_rxn),
		.txd_out_p(enet_txp),
		.txd_out_n(enet_txn)
	);

	always @(posedge clk_25mhz) begin
		if (btn[0] == 1'b0) begin
			reset_cnt <= 0;
			reset <= 1;
			led_reg <= 8'h00;
			irq <= 4'b0000;
			irq0 <= 4'b0000;
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


		// Edge triggered interrupts
		if (btn_reg[6] & !irq0[0]) begin
			irq <= {irq[3:1], 1'b1};
		end else begin
			irq <= irq & ~irqack;
		end
		irq0 <= {irq0[3:1], btn_reg[6]};
	end
endmodule
