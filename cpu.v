

module cpu(
	input clk,
	input rst_i,
	input [31:0] dat_i,
	input ack_i,
	input [3:0] irq,
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
	//wire [31:0] R[0:15];
	wire [31:0] pc, lr, sp;
	wire [11:0] imm12;
	wire [15:0] imm16;
	wire [19:0] imm20;
	wire [23:0] imm24;
	wire [1:0] ls_size;
	wire z, c, n;
	wire lt, gt, lte, gte;
	wire [3:0] selbo, selbi, selho, selhi;
	wire [31:0] datbo, datbi, datho, dathi;
	wire [2:0] irqaddr;

	reg [31:0] Rr[0:15];
	reg irqmode;
	reg [3:0] irqreg;
	reg [2:0] state;
	reg [31:0] ir, next_pc, epc, elr;
	reg [2:0] estatus;
	reg c_reg;
	reg z_reg;
	reg n_reg;

	//assign R = R[irqmode];
	assign pc = Rr[15];
	assign lr = Rr[14];
	assign sp = Rr[13];
	assign opc = ir[31:28];
	assign cond = dat_i[27:24];
	assign Rd = ir[23:20];
	assign Rs1 = ir[19:16];
	assign operation = ir[15:12];
	assign Rs2 = ir[11:8];
	assign imm12 = ir[11:0];
	assign imm20 = ir[19:0];
	assign imm16 = ir[15:0];
	assign imm24 = ir[23:0];

	assign load_addr = Rr[Rs1] + {16'h0000, imm16};
	assign store_addr = Rr[Rd] + {16'h0000, imm16};
	assign ls_size = opc[1:0];

	assign operand_a = Rr[Rs1];
	assign operand_b = (opc == 4'b0000) ? Rr[Rs2] : {20'h00000, imm12};

	assign lt = n_reg & !z_reg;
	assign gt = !n_reg & !z_reg;
	assign lte = n_reg | z_reg;
	assign gte = !n_reg | z_reg;

	assign selbo = f_selb(store_addr[1:0]);
	assign selbi = f_selb(load_addr[1:0]);
	assign selho = store_addr[1] ? 4'b1100 : 4'b0011;
	assign selhi = load_addr[1] ? 4'b1100 : 4'b0011;

	assign irqaddr = irqreg[3] ? 3'b001 : irqreg[2] ? 3'b010 : irqreg[1] ? 3'b011 : 3'b100;

	function [3:0] f_selb(input [1:0] seladr);
		case (seladr)
			2'b00: f_selb = 4'b0001;
			2'b01: f_selb = 4'b0010;
			2'b10: f_selb = 4'b0100;
			2'b11: f_selb = 4'b1000;
		endcase
	endfunction

	function [31:0] f_datbi(input [1:0] seladr, input [31:0] dat);
		case (seladr)
			2'b00: f_datbi = {24'h000000, dat[7:0]};
			2'b01: f_datbi = {24'h000000, dat[15:8]};
			2'b10: f_datbi = {24'h000000, dat[23:16]};
			2'b11: f_datbi = {24'h000000, dat[31:24]};
		endcase
	endfunction

	function [31:0] f_datbo(input [1:0] seladr, input [31:0] dat);
		case (seladr)
			2'b00: f_datbo = {24'h000000, dat[7:0]};
			2'b01: f_datbo = {16'h0000, dat[7:0], 8'h00};
			2'b10: f_datbo = {8'h00, dat[7:0], 16'h0000};
			2'b11: f_datbo = {dat[7:0], 24'h000000};
		endcase
	endfunction

	alu alu(.clk(clk), .arg_a(operand_a), .arg_b(operand_b), .op(operation), .c_in(c_reg), .result(result), .z(z), .c(c), .n(n));

	always @(posedge clk) begin
		if (rst_i) begin
			state <= ST_RESET;
		end else begin
			case (state)
				ST_RESET: begin
					Rr[0] <= 32'b0;
					Rr[1] <= 32'b0;
					Rr[2] <= 32'b0;
					Rr[3] <= 32'b0;
					Rr[4] <= 32'b0;
					Rr[5] <= 32'b0;
					Rr[6] <= 32'b0;
					Rr[7] <= 32'b0;
					Rr[8] <= 32'b0;
					Rr[9] <= 32'b0;
					Rr[10] <= 32'b0;
					Rr[11] <= 32'b0;
					Rr[12] <= 32'b0;
					Rr[13] <= 32'b0;
					Rr[14] <= 32'b0;
					Rr[15] <= 32'b0;
					irqmode <= 0;
					c_reg <= 0;
					z_reg <= 1;
					n_reg <= 0;
					stb_o <= 0;
					next_pc <= 0;
					estatus <= 3'b010;
					elr <= 32'b0;
					epc <= 32'b0;
					state <= ST_FETCH;
				end

				ST_FETCH: begin
					if (|irqreg & !irqmode) begin
						// IRQ
						adr_o <= {27'b0, irqaddr, 2'b00};
						Rr[15] <= {27'b0, irqaddr, 2'b00};
						epc <= next_pc; // Store next_pc
						elr <= lr;
						estatus <= {c_reg, z_reg, n_reg};
					end else begin
						// Normal or interrupt mode
						adr_o <= next_pc;
						Rr[15] <= next_pc;
					end
					we_o <= 0;
					sel_o <= 4'b1111;
					stb_o <= 1;
					if (ack_i) begin
						if (|irqreg & !irqmode)
							irqmode <= 1;
						state <= ST_DECODE;
					end
				end

				ST_DECODE: begin
					irqreg <= irq; // Latch IRQ for next FETCH cycle
					ir <= dat_i;
					stb_o <= 0;
					next_pc <= pc + 4;
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
							Rr[Rd] <= result;
							c_reg <= c;
							z_reg <= z;
							n_reg <= n;
							state <= ST_FETCH;
						end
						4'b0010: begin
							Rr[Rd] <= {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b0011: begin
							Rr[Rd] <= imm20[19] ? {12'hfff, imm20} : {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b0111: begin
							Rr[Rd] <= {imm20, 12'h000};
							state <= ST_FETCH;
						end
						4'b0100, 4'b0101, 4'b0110: begin
							adr_o <= load_addr;
							we_o <= 0;
							case (ls_size)
								2'b00: sel_o <= selbi;
								2'b01: sel_o <= selhi;
								2'b10: sel_o <= 4'b1111;
								default: sel_o <= 4'b1111;
							endcase
							stb_o <= 1;
							if (ack_i) begin
								if (Rs1 == 4'b1101) // R13 == Stack pointer
									Rr[13] <= Rr[13] + 4; // POP
								state <= ST_LOAD;
							end
						end
						4'b1000, 4'b1001, 4'b1010: begin
							adr_o <= store_addr;
							we_o <= 1;
							case (ls_size)
								2'b00: begin sel_o <= selbo; dat_o <= f_datbo(store_addr[1:0], Rr[Rs1]); end
								2'b01: begin sel_o <= selho; dat_o <= store_addr[1] ? {Rr[Rs1][15:0], 16'h0000} : {16'h0000, Rr[Rs1][15:0]}; end
								2'b10: begin sel_o <= 4'b1111; dat_o <= Rr[Rs1]; end
								default: begin sel_o <= 4'b1111; dat_o <= Rr[Rs1]; end
							endcase
							stb_o <= 1;
							if (ack_i) begin
								if (Rd == 4'b1101) // R13 == Stack pointer
									Rr[13] <= Rr[13] - 4; // PUSH
								state <= ST_STORE;
							end
						end
						4'b1100: begin
							next_pc <= pc + {{6{imm24[23]}}, imm24, 2'b00};
							state <= ST_FETCH;
						end
						4'b1101: begin
							if (Rr[Rd] != 32'b0) begin
								next_pc <= pc + {{10{imm20[19]}}, imm20, 2'b00};
								Rr[Rd] <= Rr[Rd] - 1;
							end
							state <= ST_FETCH;
						end
						4'b1110: begin
							Rr[14] <= next_pc;
							next_pc <= Rr[Rd] + {12'h000, imm20};
							state <= ST_FETCH;
						end
						4'b1111: begin
							case (Rd)
								4'b0000: next_pc <= Rr[14]; // RTS
								4'b0001: begin
									irqmode <= 0; // RTI
									next_pc <= epc; // next_pc was stored here when IRQ entered.
									Rr[14] <= elr;
									c_reg <= estatus[2];
									z_reg <= estatus[1];
									n_reg <= estatus[0];
								end
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
					case (ls_size)
						2'b00: Rr[Rd] <= f_datbi(load_addr[1:0], dat_i);
						2'b01: Rr[Rd] <= load_addr[1] ? {16'h0000, dat_i[31:16]} : {16'h0000, dat_i[15:0]};
						2'b10: Rr[Rd] <= dat_i;
						default: Rr[Rd] <= dat_i;
					endcase
					state <= ST_FETCH;
				end

				ST_STORE: begin
					stb_o <= 0;
					we_o <= 0;
					state <= ST_FETCH;
				end

				default: begin
					state <= ST_FETCH;
				end
			endcase
		end
	end
endmodule
