
module pls(
	input clk_20mhz,
	input rst_i,
	input data_enable,
	input txd_in,
	input rxd_in_p,
	input rxd_in_n,
	output rxd_out,
	output txd_out_p,
	output txd_out_n
);
	reg [28:0] counter;
	reg [2:0] state;
	reg lit, txd, txen;
	reg [7:0] txbuf[0:4096];
	reg [11:0] txbufidx;
	reg [7:0] txbyte;
	reg [2:0] txbitidx;

	initial $readmemh("enetframe.hex", txbuf);

	always @(posedge clk_20mhz) begin
		if (rst_i) begin
			counter <= 29'b0;
			state <= 3'b000;
		end else begin
			case (state)
				3'b000: begin
					txen <= 1'b0;
					if (counter >= 29'd320000) begin
						counter <= 29'b0;
						lit <= 1'b1;
					end else if (data_enable) begin
						counter <= 29'b0;
						state <= 3'b001;
						lit <= 1'b0;
					end else begin
						counter <= counter + 1;
						lit <= 1'b0;
					end
				end
				3'b001: begin
					// Silence
					if (counter >= 128) begin
						state <= 3'b010;
						counter <= 29'b0;
						txbitidx <= 3'b0;
						txbufidx <= 12'h001;
						txbyte <= txbuf[0];
					end else begin
						counter <= counter + 1;
					end
				end
				3'b010: begin
					// Clocking data
					case (counter[0])
						1'b0: begin
							txen <= 1'b1;
							txd <= !txbyte[0];
							counter <= counter + 1;
						end
						1'b1: begin
							txbyte <= {1'b0, txbyte[7:1]};
							if (txbitidx < 3'b111) begin
								txd <= txbyte[0];
								txbitidx <= txbitidx + 1;
								counter <= counter + 1;
							end else if (txbufidx < 12'd72) begin
								txd <= txbyte[0];
								txbitidx <= 3'b0;
								txbyte <= txbuf[txbufidx];
								txbufidx <= txbufidx + 1;
								counter <= counter + 1;
							end else begin
								txd <= 1'b1;
								state <= 3'b011;
								counter <= 29'b0;
							end
						end
						default: begin
						end
					endcase
				end
				3'b011: begin
					// 6 bit IDL as etd.
					if (counter >= 29'b1011) begin
						state <= 3'b000;
						counter <= 29'b0;
						txd <= 1'b1;
						txen <= 1'b0;
					end else begin
						counter <= counter + 1;
						txd <= 1'b1;
					end
				end
				default: begin
					state <= 3'b000;
				end
			endcase
		end
	end

	assign txd_out_p = txen ? txd : lit;
	assign txd_out_n = txen & !txd;
endmodule
