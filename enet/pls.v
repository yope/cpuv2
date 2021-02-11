
module pls(
	input clk_20mhz,
	input rst_i,
	input data_enable,
	input txd_in,
	input rxd_in_p,
	input rxd_in_n,
	output rxd_out,
	output txd_out_p,
	output txd_out_n,
	output txbusy
);
	reg [19:0] txcounter;
	reg [2:0] txstate;
	reg lit, txd, txen;

	assign txbusy = |txstate;

	always @(posedge clk_20mhz) begin
		if (rst_i) begin
			txcounter <= 20'b0;
			txstate <= 3'b000;
			txen <= 1'b0;
		end else begin
			case (txstate)
				3'b000: begin
					// Idle
					if (txcounter >= 20'd320000) begin
						txcounter <= 20'b0;
						lit <= 1'b1;
					end else if (data_enable) begin
						txcounter <= 20'b0;
						txstate <= 3'b010;
						txen <= 1'b1;
						txd <= !txd_in;
						lit <= 1'b0;
					end else begin
						txcounter <= txcounter + 1;
						lit <= 1'b0;
					end
				end
				3'b001: begin
					// Clocking data, first half bit
					if (data_enable) begin
						txd <= !txd_in;
						txstate <= 3'b010;
					end else begin
						txd <= 1'b1;
						txstate <= 3'b011;
					end
				end
				3'b010: begin
					// Clocking data, second half bit
					txd <= txd_in;
					txstate <= 3'b001;
				end
				3'b011: begin
					// 6 bit IDL as etd.
					if (txcounter >= 20'b1011) begin
						txstate <= 3'b100;
						txcounter <= 20'b0;
						txd <= 1'b1;
						txen <= 1'b0;
					end else begin
						txcounter <= txcounter + 1;
						txd <= 1'b1;
					end
				end
				3'b100: begin
					//  Mandatory silence
					if (txcounter >= 47) begin
						// Let txcounter continue in idle state
						txstate <= 3'b000;
					end else begin
						txcounter <= txcounter + 1;
					end
				end
				default: begin
					txstate <= 3'b000;
				end
			endcase
		end
	end

	assign txd_out_p = txen ? txd : lit;
	assign txd_out_n = txen & !txd;
endmodule
