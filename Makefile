.PHONY: all clean

all: ulx3s.bit

.PHONY: clean prog sim
clean:
	rm -rf cpuv2.json ulx3s_out.config ulx3s.bit obj_dir firmware.hex

ulx3s.bit: ulx3s_out.config
	ecppack ulx3s_out.config ulx3s.bit

ulx3s_out.config: cpuv2.json
	nextpnr-ecp5 --85k --json cpuv2.json \
		--lpf ulx3s_v20.lpf \
		--textcfg ulx3s_out.config

cpuv2.json: cpuv2.ys top.v alu.v cpu.v video.v uart.v enet/clk_25_200_100_20.v enet/pls.v firmware.hex
	yosys cpuv2.ys

firmware.hex: monitor.s
	python3 assemble.py $< > $@

prog: ulx3s.bit
	fujprog ulx3s.bit

sim: top.v alu.v cpu.v video.v firmware.hex
	python3 simtop.py
