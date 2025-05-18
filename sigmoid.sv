// PLAN, from https://www.researchgate.net/publication/228618304_Digital_Implementation_of_The_Sigmoid_Function_for_FPGA_Circuits 
module sigmoid #(
    parameter FRAC_BITS,
    parameter INT_BITS,
    parameter BITS_N = FRAC_BITS + INT_BITS
) (
    input [BITS_N-1:0] in,
    output logic [BITS_N-1:0] out
);

logic [FRAC_BITS-1:0]   frac_data;
logic [INT_BITS-1:0]    int_data; 

 assign frac_data = in[FRAC_BITS-1:0];       
 assign int_data  = in[BITS_N-1:FRAC_BITS];        

always_comb begin
    unique if (int_data >= 5) begin
        out = '0;
        out[FRAC_BITS] = 1'b1; // Set to 1.0
    end
    else if (int_data < 5 & (int_data > 2 | int_data == 2 & (frac_data[FRAC_BITS-1] | &frac_data[FRAC_BITS-1-1-:1])) ) begin
        out = in >> 5 + (5'b11011 << FRAC_BITS-5); // 0.03125 * in + 0.84375
    end
    else if (int_data >= 1 & (int_data < 2 | int_data == 2 & ~frac_data[FRAC_BITS-1] & ~frac_data[FRAC_BITS-1-1-:1])) begin
        out = in >> 3 + (3'b101 << FRAC_BITS-3); // 0.125 * in + 0.625
    end
    else begin // int_data < 1
        out = in >> 2 + (1'b1 << FRAC_BITS-1); // 0.25 * in + 0.5
    end
end

endmodule