//import helper::*;

module conv
    import neural_network_pkg::*;
 #(
    parameter int                                                    SRC_SIZE, // in pixels
    parameter int                                                    KERNEL_SIZE,
    parameter int                                                    FRAC_BITS,
    parameter int                                                    INT_BITS,
    parameter activation_t                                           ACTIVATION,
    parameter logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][31:0]  KERNEL,
    parameter int                                                    BITS_N = FRAC_BITS + INT_BITS
)
(
    input                  clk,
    input                  rst,
    input     [BITS_N-1:0] data_in,
    input                  i_valid,
    output                 i_ready,
    output    [BITS_N-1:0] out,
    output                 o_valid,
    input                  o_ready
);
    localparam int N_PIXELS = SRC_SIZE**2;
    localparam int N_PIXELS_BITS = $clog2(N_PIXELS);

    logic [$clog2(SRC_SIZE):0] row_count, col_count;

    logic valid_d;

    logic line_buf_en;
    assign line_buf_en = i_valid & i_ready | (row_count >= SRC_SIZE);
    // Sequential logic to control valid state:
    always_ff @(posedge clk) begin : valid_state_logic
        if (rst) begin
           row_count   <= '0; 
           col_count   <= '0; 
        end
        else begin
            if (row_count >= SRC_SIZE && o_ready) begin
                col_count <= col_count >= SRC_SIZE - KERNEL_SIZE ? '0 : col_count + 1; 
                row_count <= col_count >= SRC_SIZE - KERNEL_SIZE ? '0 : SRC_SIZE;
            end
            else if (i_valid && i_ready) begin
               //pixel_count <= pixel_count < N_PIXELS-1 ? '0 : pixel_count + 1; 
                col_count <= col_count >= SRC_SIZE-1 ? '0 : col_count + 1; 
                row_count <= col_count  < SRC_SIZE-1 ? row_count : row_count + 1;
               //valid_q <= {valid_d, valid_q[ADD_MULT_CLKS-1:1]}};
            end
        end
    end : valid_state_logic

    assign i_ready = row_count < SRC_SIZE && o_ready;
    assign valid_d = row_count >= KERNEL_SIZE & col_count <= SRC_SIZE - KERNEL_SIZE;
    assign o_valid = valid_d;


    // Wires to connect to line buffers
    logic [BITS_N-1:0]                  line_buf_in  [KERNEL_SIZE-1:0];
    logic [KERNEL_SIZE-1:0][BITS_N-1:0] line_buf_out [KERNEL_SIZE-1:0];

    assign line_buf_in[0] = data_in;
    tapped_shift_reg #(.LEN(SRC_SIZE), .WIDTH(BITS_N), .TAPS(KERNEL_SIZE))
                u0_tapped_shift_reg (.clk(clk), .enable(line_buf_en), .in(line_buf_in[0]), .out(line_buf_out[0]));

    // Instantiate the remaining line buffers
    genvar i, j;
    generate
        for (i = 1; i < KERNEL_SIZE; i++) begin : line_buf_gen
            assign line_buf_in[i] = line_buf_out[i-1][KERNEL_SIZE-1];
            tapped_shift_reg #(.LEN(SRC_SIZE), .WIDTH(BITS_N), .TAPS(KERNEL_SIZE))
                u_tapped_shift_reg (.clk(clk), .enable(line_buf_en), .in(line_buf_in[i]), .out(line_buf_out[i]));
        end : line_buf_gen
    endgenerate

    // Implement the kernel calculations
    logic signed [BITS_N-1:0] temp_val;
    always_comb begin : kernel_calc
        temp_val = '0;
        for (int i = 0; i < KERNEL_SIZE; i++) begin
            for (int j = 0; j < KERNEL_SIZE; j++) begin
                temp_val = temp_val + line_buf_out[i][j] * BITS_N'(KERNEL[i][j]);
            end
        end
    end : kernel_calc

    // Activation:
    generate
       case (ACTIVATION)
            ReLu: begin
               assign out = temp_val < 0 ? '0 : temp_val; 
            end
            Sigmoid : begin
                logic [BITS_N-1:0] sig_out;
                sigmoid #(.FRAC_BITS(FRAC_BITS), .INT_BITS(INT_BITS)) sigmoid_activation (.in(temp_val), .out(sig_out));
                assign out = sig_out;
            end            
       endcase 
    endgenerate

endmodule

