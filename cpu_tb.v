`timescale 1 ns / 1 ns

module main;
	reg [31:0] dat_i;
	reg ack_i;
	reg irq;
	reg clk;
	reg rst_i;
	wire [31:0] adr_o;
	wire [31:0] dat_o;
	wire we_o;
	wire stb_o;
	wire [3:0] sel_o;
	integer i;

	cpu cpu(.clk(clk), .rst_i(rst_i), .dat_i(dat_i), .ack_i(ack_i), .irq(irq), .we_o(we_o), .stb_o(stb_o), .adr_o(adr_o), .dat_o(dat_o), .sel_o(sel_o));


	initial
	begin
		dat_i = 32'h10008000;
		rst_i = 1;
		irq = 0;
		ack_i = 0;
		for (i = 0; i < 100; i = i + 1)
		begin
			#5 clk = 0;
			if (i >= 4)
				rst_i = 0;
			if (adr_o == 31'h00000008) dat_i = 32'h10000001;
			if (adr_o == 31'h0000000c) dat_i = 32'h10001000;
			if (adr_o == 31'h00000010) dat_i = 32'h40100101;
			if (adr_o == 31'h00000014) dat_i = 32'h50200102;
			if (adr_o == 31'h00000018) dat_i = 32'h60300103;
			if (adr_o >= 31'h0000001c) dat_i = 32'h10008000;
			#5 clk = 1;
			#2 $display("adr: %h, dat_i: %h, dat_o: %h we_o: %h", adr_o, dat_i, dat_o, we_o);
			if (stb_o == 1) begin
				ack_i = 1;
			end else begin
				ack_i = 0;
			end
		end
	end
endmodule

