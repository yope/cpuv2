
import os
import pyverilator

class CpuSim:
	def __init__(self):
		self.sim = pyverilator.PyVerilator.build('top.v', verilog_path=[".", "hdmi", "enet"])
		#self.sim.start_gtkwave()
		#self.sim.send_to_gtkwave(self.sim.internals)
		self.sim.start_vcd_trace("cpuv2sim.vcd")
		self.dclkp = [
				(0, 0),
				(1, 0),
				(1, 1),
				(0, 1),
				(0, 0),
				(1, 0),
				(1, 1),
				(0, 1),
				(0, 0),
				(1, 0),
				(0, 0),
				(0, 1),
				(1, 1),
				(1, 0),
				(0, 0),
				(0, 1),
				(1, 1)
			]
		self.clkidx = 0

	def clock(self):
		io = self.sim.io
		cs = self.dclkp[self.clkidx]
		io.clk_25mhz = cs[0]
		io.clk_20mhz = cs[1]
		self.clkidx += 1
		if self.clkidx >= len(self.dclkp):
			self.clkidx = 0

	def reset(self):
		self.sim.io.btn = 0x00
		self.clock()
		self.clock()
		self.sim.io.btn = 0x11

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
	cpu.run(2000)
