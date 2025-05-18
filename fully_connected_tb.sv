`timescale 1ns / 1ps
`define BITS_N 16
`define INPUT_STRIDE 4
`define INPUT_NEURONS 100
`define OUTPUT_NEURONS 10

import neural_network_pkg::*;

module fully_connected_tb;

    parameter CLK_PERIOD = 10;

    //logic [`INPUT_STRIDE-1:0][`BITS_N-1:0]   data_in;
    //logic [`INPUT_STRIDE-1:0]                i_valid;
    logic                                    clk;
    logic                                    rst;

    logic  [`BITS_N-1:0]                     neuron_in;
    logic                                    i_valid;
    logic                                    i_ready;

    logic [`OUTPUT_NEURONS-1:0][`BITS_N-1:0] out_neurons;
    logic                                    o_valid;
    logic                                    o_ready;

    fully_connected_improved #(
        .BITS_N(`BITS_N),
        .INPUT_NEURONS(`INPUT_NEURONS),
        .OUTPUT_NEURONS(`OUTPUT_NEURONS)
        //,.INPUT_STRIDE(`INPUT_STRIDE),
        //.WEIGHTS_FILE(),
        //.BIAS_FILE()
    ) DUT (.*);

    always #(CLK_PERIOD/2) clk = !clk;
    
    initial begin
        $dumpfile("fc.vcd");
        $dumpvars();
        rst       = 1'b1;
        clk       = 1'b0;
        neuron_in = '0;
        i_valid   = '0;
        #CLK_PERIOD;
        rst       = 1'b0;
        repeat (`INPUT_NEURONS) begin
            neuron_in = $random(); // Will this fill all strides?
            i_valid   = 1'b1;
            //while (!(i_valid && i_ready)) #CLK_PERIOD;
            #CLK_PERIOD;
        end      
        #(400*CLK_PERIOD);
        $finish();  
    end
    
    // task check_expected();
    //     // Need to 
    // endtask
    
endmodule
