
import pyverilator

class CpuSim:
	def __init__(self):
		self.sim = pyverilator.PyVerilator.build('top.v', verilog_path=[".", "hdmi"])
		self.sim.start_gtkwave()
		self.sim.send_to_gtkwave(self.sim.internals)

	def clock(self):
		io = self.sim.io
		io.clk_25mhz = 0
		io.clk_25mhz = 1

	def reset(self):
		self.sim.io.btn = 0x00
		self.clock()
		self.clock()
		self.sim.io.btn = 0x01

	def run(self, n):
		self.reset()
		for i in range(n // 2):
			self.clock()
		self.sim.io.btn = 0x41;
		for i in range(10):
			self.clock()
		self.sim.io.btn = 0x01;
		for i in range(n // 2):
			self.clock()

if __name__ == "__main__":
	#alu = AluSim()
	#alu.run()
	cpu = CpuSim()
	cpu.run(380)
