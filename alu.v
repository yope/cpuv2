

module alu (
	input clk,
	input [31:0] arg_a,
	input [31:0] arg_b,
	input [3:0] op,
	input c_in,
	output [31:0] result,
	output z,
	output c,
	output n
);
	reg [32:0] tmp;
	assign result = tmp[31:0];
	assign z = tmp[31:0] == 0;
	assign n = tmp[31];
	assign c = tmp[32];
	always @(*)
	begin
		case (op)
			0: // ADD
				tmp = arg_a + arg_b;
			1: // SUB
				tmp = arg_a - arg_b;
			2: // ADC
				tmp = arg_a + arg_b + { 31'b0, c_in };
			3: // SBC
				tmp = arg_a - arg_b - { 31'b0, c_in };
			4: // NOT
				tmp = {1'b0, ~arg_a};
			5: // AND
				tmp = {1'b0, arg_a & arg_b};
			6: // OR
				tmp = {1'b0, arg_a | arg_b};
			7: // XOR
				tmp = {1'b0, arg_a ^ arg_b};
			8: // SHL
				tmp = {arg_a, 1'b0};
			9: // SHR
				tmp = {arg_a[0], 1'b00, arg_a[31:1]};
			10: // ASL
				tmp = {arg_a, c_in};
			11: // ASR
				tmp = {arg_a[0], c_in, arg_a[31:1]};
			12: // SL4
				tmp = {arg_a[28:0], 4'b0000};
			13: // SL16
				tmp = {arg_a[16:0], 16'h0000};
			14: // SR4
				tmp = {arg_a[3], 4'b0000, arg_a[31:4]};
			15: // SR16
				tmp = {arg_a[15], 16'h0000, arg_a[31:16]};
			default:
				tmp = {1'b0, arg_a};
		endcase
	end
endmodule

