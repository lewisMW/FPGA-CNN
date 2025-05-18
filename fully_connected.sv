module fully_connected
    import neural_network_pkg::*;
#(
    parameter int                          BITS_N=0,
    parameter int                          INPUT_NEURONS=0,
    parameter int                          OUTPUT_NEURONS=0,
    parameter string                       WEIGHTS_FILE="fc_weights.hex",
    parameter string                       BIAS_FILE="fc_bias.hex"
) (
    input  wire                                      clk,
    input  wire                                      rst,

    input  wire  [BITS_N-1:0]                        neuron_in,
    input  wire                                      i_valid,
    output logic                                     i_ready,

    output logic [OUTPUT_NEURONS-1:0][BITS_N-1:0]    out_neurons,
    output logic                                     o_valid,
    input  wire                                      o_ready
);

    typedef logic signed [BITS_N-1:0]       neuron_t;
    typedef logic [$clog2(INPUT_NEURONS):0] neuron_count_t;
    typedef logic signed [BITS_N-1:0]       weights_t;
    typedef logic signed [BITS_N-1:0]       bias_t;

    localparam N_PIPELINE = 2;
    localparam N_CYCLES   = INPUT_NEURONS + N_PIPELINE;

    neuron_t                                neuron_in_q;
    neuron_t        [OUTPUT_NEURONS-1:0]    out_neurons_c;

    neuron_count_t                          neuron_count, neuron_count_q;
    weights_t       [OUTPUT_NEURONS-1:0]    neuron_weights_q;

    weights_t       [OUTPUT_NEURONS-1:0]    weights_rom [INPUT_NEURONS-1:0]; //TODO check BRAM width can be this large.
    bias_t          [OUTPUT_NEURONS-1:0]    bias_rom    [1];

    logic o_valid_d;
    logic i_handshake, o_handshake;

    assign o_valid_d   = neuron_count >= INPUT_NEURONS && !o_handshake;

    assign i_ready     = neuron_count < INPUT_NEURONS && !rst;
    assign i_handshake = i_ready && i_valid;
    assign o_handshake = o_ready && o_valid;

    logic mac_en;

    initial
    begin : init_rom
        $readmemh(WEIGHTS_FILE, weights_rom);
        $readmemh(BIAS_FILE, bias_rom);
    end

    always_ff @(posedge clk)
    begin : flip_flops
        if (rst)
        begin
            out_neurons       <= '0;
            neuron_count      <= '0;
            o_valid           <= '0;
            mac_en            <= 1'b0;
        end
        else
        begin
            if (i_handshake)
            begin
                if (o_handshake)
                begin
                    neuron_count      <= 0;
                end
                else
                begin
                    neuron_count      <= neuron_count + 1;
                end
                mac_en                <= 1'b1;
                neuron_in_q           <= neuron_in;
                neuron_weights_q      <= weights_rom[neuron_count];
            end
            else mac_en <= 1'b0;
            out_neurons               <= out_neurons_c;
            o_valid                   <= o_valid_d;
        end
    end
    
    always_comb
    begin : neuron_calculation
        out_neurons_c = out_neurons;
        unique if (o_handshake) begin
            out_neurons_c = '0;
        end else if (mac_en) begin
            for (int i = 0; i < OUTPUT_NEURONS; i++) 
            begin
                out_neurons_c[i] = out_neurons[i] + neuron_in_q * neuron_weights_q[i] + bias_rom[0][i];
            end
        end
    end
 
    // SVA
    // handshake_out : assert property @(posedge clk) (o_valid && o_ready) |-> !i_ready ##1 !o_valid;
    // handshake_in  : assert property @(posedge clk) (i_valid && i_ready)[=INPUT_NEURONS] |-> ##N_PIPELINE o_valid;

endmodule