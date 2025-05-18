
#VERILOG_FILES = $(shell find . -type f -name "*.v")
#TB_MODULE = "conv_tb";

conv:
	verilator --Wno-fatal --trace --exe --main --top conv_tb neural_network_pkg.sv conv_tb.sv --timing;
	$(MAKE) -C obj_dir -f Vconv_tb.mk;
	./obj_dir/Vconv_tb;


fc:
	verilator --Wno-fatal --trace --exe --main --top fully_connected_tb neural_network_pkg.sv fully_connected_tb.sv --timing;
	$(MAKE) -C obj_dir -f Vfully_connected_tb.mk;
	./obj_dir/Vfully_connected_tb;

