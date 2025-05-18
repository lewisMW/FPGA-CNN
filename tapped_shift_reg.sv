// To implement the line buffer
module tapped_shift_reg #(
    parameter LEN, WIDTH, TAPS
) 
(
    input clk,
    input enable,
    input [WIDTH-1:0] in,
    output [TAPS-1:0][WIDTH-1:0] out
);

    logic [LEN-1:0][WIDTH-1:0] registers;
	 
    // No reset to optimise routing.
    always_ff @(posedge clk) begin
		// Shift the register data down.
        if (enable) begin
            registers[0] <= in;
            for (int i=1; i<LEN; i++) registers[i] <= registers[i-1];
        end
    end

    // Assign outputs:
    genvar i;
    generate
        for (i = 0; i < TAPS; i++) assign out[i] = registers[LEN-TAPS+i];
    endgenerate
	 
endmodule
