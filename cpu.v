

module cpu(
	input clk,
	input rst_i,
	input [31:0] dat_i,
	input ack_i,
	input irq,
	output reg we_o,
	output reg stb_o,
	output reg [31:0] adr_o,
	output reg [31:0] dat_o,
	output reg [3:0] sel_o
);
	localparam ST_RESET =   3'b000;
	localparam ST_FETCH =   3'b001;
	localparam ST_DECODE =  3'b010;
	localparam ST_EXECUTE = 3'b011;
	localparam ST_LOAD =    3'b100;
	localparam ST_STORE =   3'b101;
	localparam ST_IRQ =     3'b110;
	localparam ST_RTI =     3'b111;

	wire [31:0] operand_a, operand_b, result;
	wire [3:0] operation;
	wire [3:0] Rs1, Rs2, Rd, opc, cond;
	wire [31:0] load_addr, store_addr;
	wire [31:0] R[0:15];
	wire [31:0] pc, lr, sp;
	wire [11:0] imm12;
	wire [15:0] imm16;
	wire [19:0] imm20;
	wire [23:0] imm24;
	wire [1:0] ls_size;
	wire z, c, n;
	wire lt, gt, lte, gte;

	reg [31:0] Rr[0:1][0:15];
	reg irqmode;
	reg [2:0] state;
	reg [31:0] ir, next_pc;
	reg c_reg;
	reg z_reg;
	reg n_reg;

	assign R = irqmode ? Rr[1] : Rr[0];
	assign pc = R[15];
	assign lr = R[14];
	assign sp = R[13];
	assign opc = ir[31:28];
	assign cond = dat_i[27:24];
	assign Rd = ir[23:20];
	assign Rs1 = ir[19:16];
	assign operation = ir[15:12];
	assign Rs2 = ir[15:12];
	assign imm12 = ir[11:0];
	assign imm20 = ir[19:0];
	assign imm16 = ir[15:0];
	assign imm24 = ir[23:0];

	assign load_addr = R[Rs1] + {16'h0000, imm16};
	assign store_addr = R[Rd] + {16'h0000, imm16};
	assign ls_size = opc[1:0];

	assign operand_a = R[Rs1];
	assign operand_b = (opc == 4'b0000) ? R[Rs2] : {20'h00000, imm12};

	assign lt = n_reg & !z_reg;
	assign gt = !n_reg & !z_reg;
	assign lte = n_reg | z_reg;
	assign gte = !n_reg | z_reg;

	alu alu(.clk(clk), .arg_a(operand_a), .arg_b(operand_b), .op(operation), .c_in(c_reg), .result(result), .z(z), .c(c), .n(n));

	always @(posedge clk) begin
		if (rst_i) begin
			state <= ST_RESET;
		end else begin
			case (state)
				ST_RESET: begin
					Rr[0][0] <= 32'b0;
					Rr[0][1] <= 32'b0;
					Rr[0][2] <= 32'b0;
					Rr[0][3] <= 32'b0;
					Rr[0][4] <= 32'b0;
					Rr[0][5] <= 32'b0;
					Rr[0][6] <= 32'b0;
					Rr[0][7] <= 32'b0;
					Rr[0][8] <= 32'b0;
					Rr[0][9] <= 32'b0;
					Rr[0][10] <= 32'b0;
					Rr[0][11] <= 32'b0;
					Rr[0][12] <= 32'b0;
					Rr[0][13] <= 32'b0;
					Rr[0][14] <= 32'b0;
					Rr[0][15] <= 32'b0;
					Rr[1][0] <= 32'b0;
					Rr[1][1] <= 32'b0;
					Rr[1][2] <= 32'b0;
					Rr[1][3] <= 32'b0;
					Rr[1][4] <= 32'b0;
					Rr[1][5] <= 32'b0;
					Rr[1][6] <= 32'b0;
					Rr[1][7] <= 32'b0;
					Rr[1][8] <= 32'b0;
					Rr[1][9] <= 32'b0;
					Rr[1][10] <= 32'b0;
					Rr[1][11] <= 32'b0;
					Rr[1][12] <= 32'b0;
					Rr[1][13] <= 32'b0;
					Rr[1][14] <= 32'b0;
					Rr[1][15] <= 32'b0;
					irqmode <= 0;
					c_reg <= 0;
					z_reg <= 1;
					n_reg <= 0;
					stb_o <= 0;
					state <= ST_FETCH;
				end

				ST_FETCH: begin
					adr_o <= pc;
					next_pc <= pc + 4;
					we_o <= 0;
					sel_o <= 4'b1111;
					stb_o <= 1;
					if (ack_i) begin
						ir <= dat_i;
						state <= ST_DECODE;
					end
				end

				ST_DECODE: begin
					stb_o <= 0;
					Rr[irqmode][15] <= next_pc;
					casez (cond)
						4'b100?: state <= (z_reg == cond[0]) ? ST_EXECUTE : ST_FETCH;
						4'b1110: state <= lt ? ST_EXECUTE : ST_FETCH;
						4'b1100: state <= gt ? ST_EXECUTE : ST_FETCH;
						4'b1111: state <= lte ? ST_EXECUTE : ST_FETCH;
						4'b1101: state <= gte ? ST_EXECUTE : ST_FETCH;
						4'b101?: state <= (c_reg == cond[0]) ? ST_EXECUTE : ST_FETCH;
						default: state <= ST_EXECUTE;
					endcase
				end

				ST_EXECUTE: begin
					case (opc)
						4'b0000, 4'b0001: begin
							Rr[irqmode][Rd] <= result;
							c_reg <= c;
							z_reg <= z;
							n_reg <= n;
							state <= ST_FETCH;
						end
						4'b0010: begin
							Rr[irqmode][Rd] <= {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b0011: begin
							Rr[irqmode][Rd] <= imm20[19] ? {12'hfff, imm20} : {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b0100, 4'b0101, 4'b0110: begin
							adr_o <= load_addr;
							we_o <= 0;
							case (ls_size) // FIXME: Fix bus alignment
								2'b00: sel_o <= 4'b0001;
								2'b01: sel_o <= 4'b0011;
								2'b10: sel_o <= 4'b1111;
								default: sel_o <= 4'b1111;
							endcase
							stb_o <= 1;
							if (ack_i) begin
								state <= ST_LOAD;
								Rr[irqmode][Rd] <= dat_i;
							end
						end
						4'b1000, 4'b1001, 4'b1010: begin
							adr_o <= store_addr;
							dat_o <= R[Rs1];
							we_o <= 1;
							case (ls_size) // FIXME: Fix bus alignment
								2'b00: sel_o <= 4'b0001;
								2'b01: sel_o <= 4'b0011;
								2'b10: sel_o <= 4'b1111;
								default: sel_o <= 4'b1111;
							endcase
							stb_o <= 1;
							if (ack_i) begin
								state <= ST_STORE;
							end
						end
						4'b1100: begin
							Rr[irqmode][15] <= pc + {{8{imm24[23]}}, imm24};
							state <= ST_FETCH;
						end
						4'b1101: begin
							if (R[Rd] != 32'b0) begin
								Rr[irqmode][15] <= pc + {{12{imm20[19]}}, imm20};
								Rr[irqmode][Rd] <= R[Rd] - 1;
							end
							state <= ST_FETCH;
						end
						4'b1110: begin
							Rr[irqmode][14] <= next_pc;
							Rr[irqmode][15] <= R[Rd] + {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b1111: begin
							case (Rd)
								4'b0000: Rr[irqmode][15] <= R[14]; // RTS
								4'b0001: irqmode <= 0; // RTI
								default: begin
								end
							endcase
							state <= ST_FETCH;
						end
						default: begin
							state <= ST_FETCH;
						end
					endcase
				end

				ST_LOAD: begin
					stb_o <= 0;
					state <= ST_FETCH;
				end

				ST_STORE: begin
					stb_o <= 0;
					state <= ST_FETCH;
				end

				default: begin
					state <= ST_FETCH;
				end
			endcase
		end
	end
endmodule
