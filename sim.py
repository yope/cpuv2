
import pyverilator


class AluSim:
	def __init__(self):
		self.sim = pyverilator.PyVerilator.build('alu.v')
		self.sim.start_gtkwave()
		self.sim.send_to_gtkwave(self.sim.internals)

	def clock(self):
		self.sim.io.clk = 0 if self.sim.io.clk else 1
		#self.sim.io.clk = 1

	def reset(self):
		#self.sim.io.reset = 1
		self.clock()
		#self.sim.io.reset = 0

	def run(self):
		self.reset()
		self.sim.io.arg_a = 0x12345678
		self.sim.io.arg_b = 0x23456789
		self.sim.io.c_in = 1
		for i in range(16):
			self.sim.io.op = i
			self.clock()
		self.clock()
		self.clock()

	def make_opcode(self, op, cond, Rd, Rx, Ry, imm):
		w = self.opcodes[op] << 27
		w |= self.conds.get(cond, 0) << 25
		w |= Rd << 16
		w |= Rx << 19
		w |= Ry << 22
		w |= imm & 0xffff
		return w


class CpuSim:
	def __init__(self):
		self.sim = pyverilator.PyVerilator.build('cpu.v')
		self.sim.start_gtkwave()
		self.sim.send_to_gtkwave(self.sim.internals)
		self.mem = [0x10008000] * 1024 # 1 kWord = 4 KiB memory full of NOP
		m = self.mem
		with open("firmware.hex", "r") as f:
			adr = 0
			for l in f.readlines():
				h = l[:8]
				m[adr] = int(h, 16)
				adr += 1

	def clock(self):
		io = self.sim.io
		io.clk = 0
		if io.stb_o and not io.ack_i:
			adr = (io.adr_o >> 2) % len(self.mem)
			data = self.mem[adr]
			sel = io.sel_o
			msk  = 0xff000000 if (sel & 8) else 0
			msk |= 0x00ff0000 if (sel & 4) else 0
			msk |= 0x0000ff00 if (sel & 2) else 0
			msk |= 0x000000ff if (sel & 1) else 0
			nmsk = ~msk
			if io.we_o:
				data = data & nmsk | io.dat_o & msk
				self.mem[adr] = data
				print("MEM W addr: {:08x} data: {:08x} mask: {:08x}".format(adr, data, msk))
			else:
				io.dat_i = data & msk
				print("MEM R addr: {:08x} data: {:08x} mask: {:08x}".format(adr, data, msk))
			io.ack_i = 1
		else:
			io.ack_i = 0
		io.clk = 1

	def reset(self):
		self.sim.io.rst_i = 1
		self.clock()
		self.clock()
		self.sim.io.rst_i = 0

	def run(self, n):
		self.reset()
		for i in range(n):
			self.clock()

if __name__ == "__main__":
	#alu = AluSim()
	#alu.run()
	cpu = CpuSim()
	cpu.run(100)
