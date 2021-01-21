

module uart(
	input clk,
	input rst_i,
	input [3:0] adr_i,
	input [31:0] dat_i,
	input [3:0] sel_i,
	input we_i,
	input stb_i,
	input rxd,
	output ack_o,
	output reg [31:0] dat_o,
	output txd
);
	reg [31:0] regs[0:3];
	reg [31:0] rxfifo[0:127];
	reg [6:0] rxfill, rxempty;
	reg [31:0] txclkcount, rxclkcount;
	reg [3:0] txbitcount, rxbitcount;
	reg [2:0] txstate, rxstate;
	reg [9:0] txshiftreg, rxshiftreg;
	reg txstart, rxstart, rxvalid, rxdec;

	assign ack_o = stb_i;
	assign txd = txshiftreg[0];

	always @(posedge clk) begin
		if (rst_i) begin
			rxstate <= 3'b000;
			txstate <= 3'b000;
			regs[0] <= 32'h00000000; // TX data
			regs[1] <= 32'h00000000; // RX data
			regs[2] <= 32'h00000000; // Status
			regs[3] <= 32'h000000d7; // divider
			rxclkcount <= 32'h00000000;
			txclkcount <= 32'h00000000;
			rxbitcount <= 4'b0000;
			txbitcount <= 4'b0000;
			rxshiftreg <= 10'b1111111111;
			txshiftreg <= 10'b1111111111;
			rxfill <= 7'b0000000;
			rxempty <= 7'b0000000;
			rxstart <= 0;
			txstart <= 0;
			rxvalid <= 0;
			rxdec <= 0;
		end else begin
			// Register access
			if (stb_i) begin
				if (we_i) begin
					regs[adr_i[3:2]] <= dat_i;
					if (adr_i[3:2] == 2'b00)
						regs[2][0] <= 1;
				end else begin
					if (adr_i[3:2] == 2'b01) begin
						if (rxempty != rxfill) begin
							dat_o <= rxfifo[rxempty];
							rxdec <= 1;
						end
					end else begin
						dat_o <= regs[adr_i[3:2]];
					end
				end
			end else begin
				if (rxdec) begin
					rxempty <= rxempty + 1;
					rxdec <= 0;
				end
			end

			regs[2][1] <= (rxempty != rxfill);

			// TXD state machine
			if (txstart) begin
				if (txclkcount >= regs[3]) begin
					txclkcount <= 32'h00000000;
					txbitcount <= txbitcount + 1;
					txshiftreg <= {1'b1, txshiftreg[9:1]};
				end else begin
					txclkcount <= txclkcount + 1;
				end
			end
			case (txstate)
				3'b000: begin
					if (regs[2][0]) begin
						txclkcount <= 32'h00000000;
						txbitcount <= 4'b0000;
						txshiftreg <= {1'b1, regs[0][7:0], 1'b0};
						txstate <= 3'b001;
						txstart <= 1;
					end
				end
				3'b001: begin
					if (txbitcount == 4'b1011) begin
						txstart <= 0;
						txstate <= 3'b010;
					end
				end
				3'b010: begin
					regs[2][0] <= 0;
					txstate <= 3'b000;
				end
				default: txstate <= 3'b000;
			endcase

			// RXD state machine
			if (rxclkcount >= regs[3]) begin
				rxclkcount <= 32'h00000000;
				if (rxstart) begin
					// Sample point
					rxshiftreg <= {rxd, rxshiftreg[9:1]};
					if (rxbitcount == 4'b1001) begin
						rxstart <= 0;
						if (rxd) // Stop bit valid?
							rxvalid <= 1'b1;
					end else if ((rxbitcount == 4'b0000) & rxd) begin
						// Start bit not valid --> ignore, it was a glitch.
						rxstart <= 0;
					end else begin
						rxbitcount <= rxbitcount + 1;
					end
				end
			end else begin
				rxclkcount <= rxclkcount + 1;
			end
			if (rxvalid) begin
				rxfifo[rxfill][7:0] <= rxshiftreg[8:1];
				rxfill <= rxfill + 1;
				rxvalid <= 0;
			end
			if (!rxstart & !rxd) begin
				// Detected start or start bit
				rxbitcount <= 4'b0000;
				rxclkcount <= {1'b0, regs[3][31:1]}; // Sample point at 50%
				rxstart <= 1;
			end
		end
	end
endmodule
