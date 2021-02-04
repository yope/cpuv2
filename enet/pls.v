
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
	reg [28:0] txcounter;
	reg [2:0] txstate;
	reg lit, txd, txen;

	assign txbusy = |txstate;

	always @(posedge clk_20mhz) begin
		if (rst_i) begin
			txcounter <= 29'b0;
			txstate <= 3'b000;
		end else begin
			case (txstate)
				3'b000: begin
					// Idle
					txen <= 1'b0;
					if (txcounter >= 29'd320000) begin
						txcounter <= 29'b0;
						lit <= 1'b1;
					end else if (data_enable) begin
						txcounter <= 29'b0;
						txstate <= 3'b001;
						txen <= 1'b1;
						txd <= !txd_in;
						lit <= 1'b0;
					end else begin
						txcounter <= txcounter + 1;
						lit <= 1'b0;
					end
				end
				3'b001: begin
					// Clocking data
					if (txcounter[0]) begin
						txen <= 1'b1;
						if (data_enable)
							txd <= !txd_in;
						else
							txd <= 1'b1;
						txcounter <= txcounter + 1;
					end else begin
						if (data_enable) begin
							txd <= txd_in;
							txcounter <= txcounter + 1;
						end else begin
							txd <= 1'b1;
							txstate <= 3'b010;
							txcounter <= 29'b0;
						end
					end
				end
				3'b010: begin
					// 6 bit IDL as etd.
					if (txcounter >= 29'b1011) begin
						txstate <= 3'b011;
						txcounter <= 29'b0;
						txd <= 1'b1;
						txen <= 1'b0;
					end else begin
						txcounter <= txcounter + 1;
						txd <= 1'b1;
					end
				end
				3'b011: begin
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
