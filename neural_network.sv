//import helper::*;

// Fixed point: assume < 255, precesion of 10 bits (for 3dp).

module neural_network 
    import neural_network_pkg::*;
#(
   parameter BITS_N = 8,
   parameter OUT_N  = 10
) (
    input clk,
    input rst,
    input [BITS_N-1] data_in,,
    input i_valid,
    output i_ready;
    output [OUT_N][BITS_N-1] data_out,
    output o_valid
);       

    assign i_ready = 1'b1;

    logic [BITS_N-1:0] conv1_out[2:1],       conv2_out[4:1];
    logic              conv1_valid[2:1],     conv2_valid[4:1];

    logic [BITS_N-1:0] max_pool1_out[2:1],   max_pool2_out[4:1];
    logic              max_pool1_valid[2:1], max_pool2_valid[4:1];

    // Layer 1:
    conv #(.SRC_SIZE(28), .KERNEL_SIZE(5), .BITS_N(BITS_N), .ACTIVATION(ReLu), .KERNEL(get_kernel("conv1_1")))
        conv1_1 (.clk(clk), .rst(rst), .data_in(data_in), .i_valid(i_valid), .out(conv1_out[1]), .o_valid(conv1_valid[1]));
    
    conv #(.SRC_SIZE(28), .KERNEL_SIZE(5), .BITS_N(BITS_N), .ACTIVATION(ReLu), .KERNEL(get_kernel("conv1_2")))
        conv1_2 (.clk(clk), .rst(rst), .data_in(data_in), .i_valid(i_valid), .out(conv1_out[2]), .o_valid(conv1_valid[2]));
    
    max_pool #(.SRC_SIZE(24), .POOL_SIZE(2), .BITS_N(BITS_N), .STRIDE(2))
        max_pool1_1 (.clk(clk), .rst(rst), .data_in(conv1_out[1]), .i_valid(conv1_valid[1]), .out(max_pool1_out[1]), .o_valid(max_pool1_valid[1])),
        max_pool1_2 (.clk(clk), .rst(rst), .data_in(conv1_out[2]), .i_valid(conv1_valid[2]), .out(max_pool1_out[2]), .o_valid(max_pool1_valid[2]));

    // Layer 2:
    conv_x2 #(.SRC_SIZE(12), .KERNEL_SIZE(3), .BITS_N(BITS_N), .ACTIVATION(Sigmoid), .KERNEL(get_kernel("conv2_1")))
        conv2_1 (.clk(clk), .rst(rst), .data_in1(max_pool1_out[1]), .data_in2(max_pool1_out[2]) .i_valid1(max_pool1_valid[1]), .i_valid2(max_pool1_valid[2]), .out(conv2_out[1]), .o_valid(conv2_valid[1]));

    conv_x2 #(.SRC_SIZE(12), .KERNEL_SIZE(3), .BITS_N(BITS_N), .ACTIVATION(Sigmoid), .KERNEL(get_kernel("conv2_2")))
        conv2_2 (.clk(clk), .rst(rst), .data_in1(max_pool1_out[1]), .data_in2(max_pool1_out[2]) .i_valid1(max_pool1_valid[1]), .i_valid2(max_pool1_valid[2]), .out(conv2_out[2]), .o_valid(conv2_valid[2]));
  
    conv_x2 #(.SRC_SIZE(12), .KERNEL_SIZE(3), .BITS_N(BITS_N), .ACTIVATION(Sigmoid), .KERNEL(get_kernel("conv2_3")))
        conv2_3 (.clk(clk), .rst(rst), .data_in1(max_pool1_out[1]), .data_in2(max_pool1_out[2]) .i_valid1(max_pool1_valid[1]), .i_valid2(max_pool1_valid[2]), .out(conv2_out[3]), .o_valid(conv2_valid[3]));

    conv_x2 #(.SRC_SIZE(12), .KERNEL_SIZE(3), .BITS_N(BITS_N), .ACTIVATION(Sigmoid), .KERNEL(get_kernel("conv2_4")))
        conv2_4 (.clk(clk), .rst(rst), .data_in1(max_pool1_out[1]), .data_in2(max_pool1_out[2]) .i_valid1(max_pool1_valid[1]), .i_valid2(max_pool1_valid[2]), .out(conv2_out[4]), .o_valid(conv2_valid[4]));

    max_pool #(.SRC_SIZE(10), .POOL_SIZE(2), .BITS_N(BITS_N))
        max_pool2_1 (.clk(clk), .rst(rst), .data_in(conv2_out[1]), .i_valid(conv2_valid[1]), .out(max_pool2_out[1]), .o_valid(max_pool2_valid[1])),
        max_pool2_2 (.clk(clk), .rst(rst), .data_in(conv2_out[2]), .i_valid(conv2_valid[2]), .out(max_pool2_out[2]), .o_valid(max_pool2_valid[2])),
        max_pool2_3 (.clk(clk), .rst(rst), .data_in(conv2_out[3]), .i_valid(conv2_valid[3]), .out(max_pool2_out[3]), .o_valid(max_pool2_valid[3])),
        max_pool2_4 (.clk(clk), .rst(rst), .data_in(conv2_out[4]), .i_valid(conv2_valid[4]), .out(max_pool2_out[4]), .o_valid(max_pool2_valid[4]));

    // Fully Connected Layer:
    logic [OUT_N-1:0][BITS_N-1:0] out_neurons_partial [4];
    logic [OUT_N-1:0][BITS_N-1:0] out_neurons;
    logic [4:1] fc_valid;
    logic [4:1] fc_ready;
    fully_connected #(.BITS_N(BITS_N), .INPUT_NEURONS(100), .OUTPUT_NEURONS(OUT_N)) // ReLu
        fc1 (.clk(clk), .rst(rst), .data_in(max_pool2_out[1]), .i_valid(max_pool2_valid[1]), .out_neurons(out_neurons_partial[1]), .o_valid(fc_valid[1]), .o_ready(fc_ready[1])),

    //TODO implement ready signals

endmodule