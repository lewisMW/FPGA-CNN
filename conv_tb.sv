import neural_network_pkg::*;

`define FRAC_BITS 10
`define INT_BITS 8
`define N_BITS (`FRAC_BITS+`INT_BITS)
// Size in terms of 1 dimension (assume square input):
`define SRC_SIZE 28
`define OUT_SIZE (`SRC_SIZE - (`KERNEL_SIZE - 1))
`define KERNEL_SIZE 5
`define KERNEL_NAME "conv1_1"
`define ACTIVATION ReLu

// From https://www.chipverify.com/systemverilog/systemverilog-testbench-example-1

interface conv_if (input bit clk);
    //in:
    logic rst;
    logic [`N_BITS-1:0] data_in;
    logic i_valid;
    //out:
    logic i_ready;
    logic [`N_BITS-1:0] out;
    logic o_valid;
endinterface //conv_if

class conv_trans;
    rand bit [`N_BITS-1:0] data;
    constraint data_c { data >= 0; data < 10;}
    function void print(input string tag);
        $display("T=%0t : [%s] data: %0d", $time, tag, data);
    endfunction
    function new();
        data = '0;
    endfunction
endclass

class driver;
    virtual conv_if vif;
    event drv_done;
    mailbox #(.T(conv_trans)) drv_mbx;

    task run();
        $display("Driver starting at T=%0t.", $time);
        @(posedge vif.clk);

        forever begin
            conv_trans item;
            drv_mbx.get(item);
            item.print("Driver");
            vif.data_in <= item.data;
            vif.i_valid <= 1'b1;
            @(posedge vif.clk);
            while (!vif.i_ready) begin
                @(posedge vif.clk);
            end
            vif.i_valid <= 1'b0;
            ->drv_done;            
        end
    endtask //run
endclass

class monitor;
    virtual conv_if vif;
    mailbox #(.T(conv_trans)) scb_mbx; //scoreboard

    task run();
        $display("Monitor starting at T=%0t.", $time);
        
        forever begin
            @(posedge vif.clk);
            if (vif.o_valid) begin
                conv_trans item = new;
                item.data = vif.out;
                item.print("Monitor");
                scb_mbx.put(item);
            end
        end
    endtask //run
endclass

class scoreboard;
    mailbox #(.T(conv_trans)) scb_mbx;

    bit [`N_BITS-1:0] expected_output_data[`OUT_SIZE][`OUT_SIZE];
    int i = 0;

    task run();
        forever begin
            conv_trans item;
            scb_mbx.get(item);
            item.print("Scoreboard");

            $display("Expected: %0d, Actual: %0d", expected_output_data[i/`OUT_SIZE][i%`OUT_SIZE], item.data);

            if (item.data != expected_output_data[i/`OUT_SIZE][i%`OUT_SIZE]) 
                $error("T=%0t output data == %0d, expected %0d. i=%0d. expected_output[%0d][%0d].", $time, item.data, expected_output_data[i/`OUT_SIZE][i%`OUT_SIZE],i,i/`OUT_SIZE,i%`OUT_SIZE);
            i++;
        end
    endtask //run
endclass

class environment;
    driver drv;
    monitor mn;
    scoreboard sb;
    mailbox #(.T(conv_trans)) scb_mbx;
    virtual conv_if vif;

    function new();
        drv = new;
        mn = new;
        sb = new;
        scb_mbx = new();
    endfunction

    virtual task run();
        drv.vif = vif;
        mn.vif = vif;
        mn.scb_mbx = scb_mbx;
        sb.scb_mbx = scb_mbx;
        fork
            sb.run();
            drv.run();
            mn.run();
        join_any
    endtask
endclass 

class test;
    environment env;
    mailbox #(.T(conv_trans)) drv_mbx;

    bit [`N_BITS-1:0] input_stimulus_data[`SRC_SIZE][`SRC_SIZE];

    function new();
        drv_mbx = new();
        env = new();
    endfunction //new()

    virtual task run();
        env.drv.drv_mbx = drv_mbx;
        apply_stim();
        calculate_expected();
        fork
            env.run();
        join_none
    endtask

    virtual task apply_stim();
        for (int i = 0; i < `SRC_SIZE; i++) begin
            for (int j = 0; j < `SRC_SIZE; j++) begin
                conv_trans item;
                item = new;
                `ifdef VERILATOR
                    item.data = $urandom() % 10;
                `else
                    item.randomize();
                `endif
                drv_mbx.put(item);
                input_stimulus_data[i][j] = item.data;
            end
        end
    endtask

    virtual task calculate_expected();
        logic signed [`KERNEL_SIZE-1:0][`KERNEL_SIZE-1:0][31:0] kernel = get_kernel(`KERNEL_NAME);
        $display("Input:");
        for (int i = 0; i < `SRC_SIZE; i++) begin
            for (int j = 0; j < `SRC_SIZE; j++)
                $write("%0d\t", input_stimulus_data[i][j]);
            $write("\n");
        end
        
        for (int row = 0; row < `OUT_SIZE; row++) begin
            for (int col = 0; col < `OUT_SIZE; col++) begin
                int accumulator = 0;
                for (int i = 0; i < `KERNEL_SIZE; i++) begin
                    for (int j = 0; j < `KERNEL_SIZE; j++) begin
                        $display("i: %0d, j: %0d", row + i, col + j);
                        accumulator += signed'(input_stimulus_data[row + i][col + j]) * kernel[i][j];
                        $display("accumulator + %0d = %0d", signed'(input_stimulus_data[row + i][col + j]) * kernel[i][j], accumulator);
                    end
                end
                case (`ACTIVATION)
                    ReLu: env.sb.expected_output_data[row][col] =
                                accumulator[`N_BITS-1:0] > 0 ? accumulator[`N_BITS-1:0] : '0;
                    Sigmoid: begin
                        int accumulator_abs = accumulator[31] ? ~accumulator+1 : accumulator;
                        env.sb.expected_output_data[row][col] = 
                                accumulator_abs >= real_to_fixed_point(5.00 , `FRAC_BITS) ?  real_to_fixed_point(1.00   , `FRAC_BITS)                                                          :
                                accumulator_abs >= real_to_fixed_point(2.375, `FRAC_BITS) ?  real_to_fixed_point(0.03125, `FRAC_BITS) * accumulator + real_to_fixed_point(0.84375, `FRAC_BITS) :
                                accumulator_abs >= real_to_fixed_point(1.00 , `FRAC_BITS) ?  real_to_fixed_point(0.125  , `FRAC_BITS) * accumulator + real_to_fixed_point(0.625  , `FRAC_BITS) :
                              /*accumulator_abs >= real_to_fixed_point(0.00 , `FRAC_BITS) ?*/real_to_fixed_point(0.25   , `FRAC_BITS) * accumulator + real_to_fixed_point(0.5    , `FRAC_BITS) ;
                    end
                endcase                
            end
        end
        $display("Expected:");
        for (int i = 0; i < `OUT_SIZE; i++) begin
            for (int j = 0; j < `OUT_SIZE; j++)
                $write("%0d\t", env.sb.expected_output_data[i][j]);
            $write("\n");
        end
    endtask
endclass //test



module conv_tb;

    logic clk;
    always #10 clk = ~clk;

    conv_if if_(clk);
       
    conv #(
        .SRC_SIZE(`SRC_SIZE),
        .KERNEL_SIZE(`KERNEL_SIZE),
        .FRAC_BITS(`FRAC_BITS),
        .INT_BITS(`INT_BITS),
        .ACTIVATION(`ACTIVATION),
        .KERNEL(get_kernel(`KERNEL_NAME))
    )
    u_conv (
        .clk(if_.clk),
        .rst(if_.rst),
        .data_in(if_.data_in),
        .i_valid(if_.i_valid),
        .i_ready(if_.i_ready),
        .out(if_.out),
        .o_valid(if_.o_valid)
    );

    initial begin
        test t;
        $dumpfile("waveform.vcd");
        $dumpvars();

        clk = 0;
        if_.rst = 1;
        if_.i_valid = 0;
        #20 if_.rst = 0;

        t = new;
        t.env.vif = if_;
        t.run();

        #20000 $finish;
    end

    // SVA:
    //assert property (@);

    max_pool #(
        .SRC_SIZE(`SRC_SIZE),
        .POOL_SIZE(3),
        .BITS_N(4)
    )
    u_max_pool (
        .clk(if_.clk),
        .rst(if_.rst),
        .data_in(if_.data_in),
        .i_valid(if_.i_valid),
        .out(),
        .o_valid()
    );

endmodule