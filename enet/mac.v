

module mac(
	// Wishbone port
	input clk_i,
`ifdef VERILATOR
	input clk_20mhz,
`endif
	input rst_i,
	input [12:0] adr_i,
	input [31:0] dat_i,
	input [3:0] sel_i,
	input stb_i,
	input we_i,
	output reg [31:0] dat_o,
	output ack_o,

	// Interrupts
	output txempty,
	output rxfull,

	// Phy IO
	input rxd_in_p,
	input rxd_in_n,
	output txd_out_p,
	output txd_out_n
);
	reg [31:0] txbuf[0:511];
	reg [31:0] rxbuf[0:511];
	reg [2:0] txstate;
	reg [2:0] rxstate;
	reg txen;
	reg [31:0] txreg_next, txreg;
	reg [14:0] txbitcount;
	reg [14:0] txbitlen_mac, txbitlen_bus;
	reg [8:0] txbufptr_reg;
	reg [31:0] fcs;
	reg txstart_bus, txend_mac;
	reg bitclk;

	reg txd;

`ifdef VERILATOR
`else
	wire clk_200mhz, clk_100mhz, clk_20mhz;
`endif
	wire [8:0] bufaddr;
	wire [8:0] txbufptr;
	wire [4:0] txbitidx;
	wire txbusy;
	wire [14:0] txbitcount_1;

	initial $readmemh("enetframe.hex", txbuf, 1);

	assign ack_o = stb_i;
	assign bufaddr = adr_i[10:2];
	assign txbitcount_1 = txbitcount + 2;
	assign txbufptr = txbitcount_1[14:5];
	assign txbitidx = txbitcount[4:0];

`ifdef VERILATOR
`else
	clk_25_200_100_20 clk(
		.clki(clk_i),
		.clks1(clk_100mhz),
		.clks2(clk_20mhz),
		.clko(clk_200mhz)
	);
`endif

	pls pls(
		.rst_i(rst_i),
		.clk_20mhz(clk_20mhz),
		.data_enable(txen),
		.txd_in(txd),
		.rxd_in_p(rxd_in_p),
		.rxd_in_n(rxd_in_n),
		.txd_out_p(txd_out_p),
		.txd_out_n(txd_out_n),
		.txbusy(txbusy)
	);

	function [31:0] fcs32_1(input di, input [31:0] ci);
		fcs32_1[0] =  ci[31] ^ di;
		fcs32_1[1] =  ci[0] ^ ci[31] ^ di;
		fcs32_1[2] =  ci[1] ^ ci[31] ^ di;
		fcs32_1[3] =  ci[2];
		fcs32_1[4] =  ci[3] ^ ci[31] ^ di;
		fcs32_1[5] =  ci[4] ^ ci[31] ^ di;
		fcs32_1[6] =  ci[5];
		fcs32_1[7] =  ci[6] ^ ci[31] ^ di;
		fcs32_1[8] =  ci[7] ^ ci[31] ^ di;
		fcs32_1[9] =  ci[8];
		fcs32_1[10] =  ci[9] ^ ci[31] ^ di;
		fcs32_1[11] =  ci[10] ^ ci[31] ^ di;
		fcs32_1[12] =  ci[11] ^ ci[31] ^ di;
		fcs32_1[13] =  ci[12];
		fcs32_1[14] =  ci[13];
		fcs32_1[15] =  ci[14];
		fcs32_1[16] =  ci[15] ^ ci[31] ^ di;
		fcs32_1[17] =  ci[16];
		fcs32_1[18] =  ci[17];
		fcs32_1[19] =  ci[18];
		fcs32_1[20] =  ci[19];
		fcs32_1[21] =  ci[20];
		fcs32_1[22] =  ci[21] ^ ci[31] ^ di;
		fcs32_1[23] =  ci[22] ^ ci[31] ^ di;
		fcs32_1[24] =  ci[23];
		fcs32_1[25] =  ci[24];
		fcs32_1[26] =  ci[25] ^ ci[31] ^ di;
		fcs32_1[27] =  ci[26];
		fcs32_1[28] =  ci[27];
		fcs32_1[29] =  ci[28];
		fcs32_1[30] =  ci[29];
		fcs32_1[31] =  ci[30];
	endfunction

	// BUS clock domain
	always @(posedge clk_i) begin
		if (rst_i) begin
			txbuf[0] <= 32'b0;
			rxbuf[0] <= 32'b0;
			txstart_bus <= 1'b0;
		end else begin
			if (stb_i) begin
				if (we_i) begin
					if (!adr_i[12]) begin
						txbuf[bufaddr] <= dat_i;
						if (adr_i[11:0] == 12'b0) begin
							// TX length register write ==> start TX
							txstart_bus <= 1'b1;
							txbitlen_bus <= {dat_i[11:0], 3'b000};
						end
					end else begin
						rxbuf[bufaddr] <= dat_i;
					end
				end else begin
					if (!adr_i[12])
						dat_o <= txbuf[bufaddr];
					else
						dat_o <= rxbuf[bufaddr];
				end
			end else begin
				// memory free from bus access
				if (txend_mac & txstart_bus) begin
					txstart_bus <= 1'b0;
					txbuf[0] <= 32'b0;
				end
			end

			// Get TX data into the PLS clock domain
			txbufptr_reg <= txbufptr;
			txreg_next <= txbuf[txbufptr_reg + 1];
		end
	end

	// MAC clock domain
	always @(posedge clk_20mhz) begin
		if (rst_i) begin
			txbitcount <= 15'b0;
			txstate <= 3'b000;
			rxstate <= 3'b000;
		end else begin
			txbitlen_mac <= txbitlen_bus;
			case (txstate)
				3'b000: begin
					// Idle
					txend_mac <= 1'b0;
					txbitcount <= 15'b0;
					bitclk <= 1'b0;
					fcs <= 32'hffffffff;
					if (txstart_bus)
						txstate <= 3'b001;
				end
				3'b001: begin
					// Latch first word
					txreg <= txreg_next;
					txen <= 1'b1;
					txd <= 1'b1;
					txstate <= 3'b010;
				end
				3'b010: begin
					// Preamble
					bitclk <= !bitclk;
					if (bitclk) begin
						if (txbitcount == 63) begin
							txd <= 1'b1;
						end else if (txbitcount >= 64) begin
							txd <= txreg[0];
							fcs <= fcs32_1(txreg[0], fcs);
							txbitcount <= 1; // Start at next bit
							txstate <= 3'b011;
						end else begin
							txd <= ~txbitcount[0];
						end
					end else begin
						txbitcount <= txbitcount + 1;
					end
				end
				3'b011: begin
					// Transmitting data
					bitclk <= !bitclk;
					if (bitclk) begin
						txd <= txreg[txbitidx];
						txbitcount <= txbitcount + 1;
						if (txbitcount >= txbitlen_mac) begin
							txstate <= 3'b100;
						end else begin
							fcs <= fcs32_1(txreg[txbitidx], fcs);
						end
						if (txbitcount[4:0] == 5'b11111)
							txreg <= txreg_next;
					end
				end
				3'b100: begin
					// Transmit FCS
					bitclk <= !bitclk;
					if (bitclk) begin
						txd <= ~fcs[31 - txbitidx];
						txbitcount <= txbitcount + 1;
						if (txbitcount[4:0] == 5'b00000) begin
							txstate <= 3'b101;
							txen <= 1'b0;
						end
					end
				end
				3'b101: begin
					// Wait for PLS to finish IDL and mandatory silence
					if (!txbusy) begin
						txend_mac <= 1'b1;
						if (!txstart_bus)
							txstate <= 3'b000;
					end
				end
				default: begin
					txstate <= 3'b000;
				end
			endcase
		end
	end
endmodule
