.PHONY: all clean

all: ulx3s.bit

.PHONY: clean
clean:
	rm -rf cpuv2.json ulx3s_out.config ulx3s.bit

ulx3s.bit: ulx3s_out.config
	ecppack ulx3s_out.config ulx3s.bit

ulx3s_out.config: cpuv2.json
	nextpnr-ecp5 --85k --json cpuv2.json \
		--lpf ulx3s_v20.lpf \
		--textcfg ulx3s_out.config

cpuv2.json: cpuv2.ys top.v alu.v cpu.v
	yosys cpuv2.ys

prog: ulx3s.bit
	fujprog ulx3s.bit
