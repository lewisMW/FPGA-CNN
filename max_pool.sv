module max_pool #(
    parameter int          SRC_SIZE,
    parameter int          POOL_SIZE,
    parameter int          BITS_N,
    parameter int          STRIDE
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

    initial begin
        if (STRIDE != 2 || STRIDE != 1 && SRC_SIZE % 2 == 1) begin
            $error("max_pool: Only STRIDE==1 or STRIDE==2 with even SRC_SIZE implemented!");
        end
    end

    localparam N_PIXELS = SRC_SIZE**2;
    localparam N_PIXELS_BITS = $clog2(N_PIXELS)-1;

    logic [$clog2(SRC_SIZE):0] row_count, col_count;

    logic  valid_d;
    logic  stride_valid;

    logic  line_buf_en;
    assign line_buf_en = i_valid & i_ready | (row_count >= SRC_SIZE);
    // Sequential logic to control valid state:
    always_ff @(posedge clk) begin : valid_state_logic
        if (rst) begin
           row_count   <= '0; 
           col_count   <= '0; 
        end
        else begin
            if (row_count >= SRC_SIZE && o_ready) begin
                col_count <= col_count >= SRC_SIZE - POOL_SIZE ? '0 : col_count + 1; 
                row_count <= col_count >= SRC_SIZE - POOL_SIZE ? '0 : SRC_SIZE;
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
    assign stride_valid = STRIDE == 2 ? (row_count[0] == 0 && col_count[0] == 0) : 1'b1;
    assign valid_d = stride_valid && row_count >= POOL_SIZE && col_count <= SRC_SIZE - POOL_SIZE;
    assign o_valid = valid_d;


    // Wires to connect to line buffers
    logic [BITS_N-1:0]                  line_buf_in  [POOL_SIZE-1:0];
    logic [POOL_SIZE-1:0][BITS_N-1:0]   line_buf_out [POOL_SIZE-1:0];

    assign line_buf_in[0] = data_in;
    tapped_shift_reg #(.LEN(SRC_SIZE), .WIDTH(BITS_N), .TAPS(POOL_SIZE)) u_tapped_shift_reg
                (.clk(clk), .enable(line_buf_en), .in(line_buf_in[0]), .out(line_buf_out[0]));

    // Instantiate the remaining line buffers
    genvar i, j;
    generate
        for (i = 1; i < POOL_SIZE; i++) begin : line_buf_gen
            assign line_buf_in[i] = line_buf_out[i-1][POOL_SIZE-1];
            tapped_shift_reg #(.LEN(SRC_SIZE), .WIDTH(BITS_N), .TAPS(POOL_SIZE)) u_tapped_shift_reg
                (.clk(clk), .enable(line_buf_en), .in(line_buf_in[i]), .out(line_buf_out[i]));
        end
    endgenerate

    integer temp_val;
    // Implement the max calculation:
    always_comb begin
        temp_val = 0;
        for (int i = 0; i < POOL_SIZE; i++) begin
            for (int j = 0; j < POOL_SIZE; j++) begin
                if (line_buf_out[i][j] > temp_val) temp_val = line_buf_out[i][j];
            end
        end
    end

    assign out = temp_val;

endmodule

