// Output: 24-bit RGB bit vector.
module conv(input clk, reset, input [16:0] input_addr, input [23:0] data_in, input data_in_en,
              output [23:0] out);

// Wires to connect to line buffers
wire [23:0] line_buf_out0_0, line_buf_out0_1, line_buf_out0_2, line_buf_out0_3,
            line_buf_out1_0, line_buf_out1_1, line_buf_out1_2, line_buf_out1_3,
            line_buf_out2_0, line_buf_out2_1, line_buf_out2_2, line_buf_out2_3;
				
wire [23:0] line_buf_out0_0a, line_buf_out0_1a, line_buf_out0_2a, line_buf_out0_3a,
            line_buf_out1_0a, line_buf_out1_1a, line_buf_out1_2a, line_buf_out1_3a,
            line_buf_out2_0a, line_buf_out2_1a, line_buf_out2_2a, line_buf_out2_3a;

reg [23:0] temp_out;
integer    temp_R, temp_G, temp_B;
wire write = 1;                     // write enable always set to high because of vga_address always referencing block ram
reg [16:0] temp_addr;

//Decide what type of conv to apply
integer kernel[8:0];
initial
begin
	kernel[0] = -1; kernel[1] = -1; kernel[2] = -1;
	kernel[3] = -1; kernel[4] = 8; kernel[5] = -1;
	kernel[6] = -1; kernel[7] = -1; kernel[8] = -1;
end

// Instatntiate the 6 line buffers
ShiftRegister4Out #(.length(646), .bit_width(24))
                    line_buf0 (.clk(clk),.rst(reset),.in(data_in),         .en(data_in_en),.out0(line_buf_out0_0a),.out1(line_buf_out0_1a),.out2(line_buf_out0_2a),.out3(line_buf_out0_3a)),
					line_buf0b(.clk(clk),.rst(reset),.in(line_buf_out0_3a),.en(data_in_en),.out0(line_buf_out0_0), .out1(line_buf_out0_1), .out2(line_buf_out0_2), .out3(line_buf_out0_3)),
                    line_buf1 (.clk(clk),.rst(reset),.in(line_buf_out0_3), .en(data_in_en),.out0(line_buf_out1_0a),.out1(line_buf_out1_1a),.out2(line_buf_out1_2a),.out3(line_buf_out1_3a)),
                    line_buf1b(.clk(clk),.rst(reset),.in(line_buf_out1_3a),.en(data_in_en),.out0(line_buf_out1_0), .out1(line_buf_out1_1), .out2(line_buf_out1_2), .out3(line_buf_out1_3)),
                    line_buf2 (.clk(clk),.rst(reset),.in(line_buf_out1_3), .en(data_in_en),.out0(line_buf_out2_0a),.out1(line_buf_out2_1a),.out2(line_buf_out2_2a),.out3(line_buf_out2_3a)),
                    line_buf2b(.clk(clk),.rst(reset),.in(line_buf_out2_3a),.en(data_in_en),.out0(line_buf_out2_0), .out1(line_buf_out2_1), .out2(line_buf_out2_2), .out3(line_buf_out2_3));

// Implement the kernel calculations
always @(*) begin

	 // Lowest 8 bits is red
    temp_R         = (line_buf_out0_2a[7:0]*kernel[0]+line_buf_out0_1a[7:0]*kernel[1]+line_buf_out0_0a[7:0]*kernel[2]
                    +line_buf_out1_2a[7:0]*kernel[3]+line_buf_out1_1a[7:0]*kernel[4]+line_buf_out1_0a[7:0]*kernel[5]
                    +line_buf_out2_2a[7:0]*kernel[6]+line_buf_out2_1a[7:0]*kernel[7]+line_buf_out2_0a[7:0]*kernel[8]);
    
	 // Middle 8 bits is green
    temp_G         = (line_buf_out0_2a[15:8]*kernel[0]+line_buf_out0_1a[15:8]*kernel[1]+line_buf_out0_0a[15:8]*kernel[2]
                    +line_buf_out1_2a[15:8]*kernel[3]+line_buf_out1_1a[15:8]*kernel[4]+line_buf_out1_0a[15:8]*kernel[5]
                    +line_buf_out2_2a[15:8]*kernel[6]+line_buf_out2_1a[15:8]*kernel[7]+line_buf_out2_0a[15:8]*kernel[8]);
    
	 // Highest 8 bits is blue
    temp_B         = (line_buf_out0_2a[23:16]*kernel[0]+line_buf_out0_1a[23:16]*kernel[1]+line_buf_out0_0a[23:16]*kernel[2]
                    +line_buf_out1_2a[23:16]*kernel[3]+line_buf_out1_1a[23:16]*kernel[4]+line_buf_out1_0a[23:16]*kernel[5]
                    +line_buf_out2_2a[23:16]*kernel[6]+line_buf_out2_1a[23:16]*kernel[7]+line_buf_out2_0a[23:16]*kernel[8]);
	
	 // Make sure the pixels stay within range 0 - 255
	 temp_out[7:0  ]  = temp_R < 0? 0 : (temp_R > 255? 255 : temp_R);
	 temp_out[15:8 ]  = temp_G < 0? 0 : (temp_G > 255? 255 : temp_G);
	 temp_out[23:16]  = temp_B < 0? 0 : (temp_B > 255? 255 : temp_B);

end

always @(posedge clk, negedge reset) begin

    // If a reset occurs, clear address to write to
    if (~reset) begin
        temp_addr <= 17'b0;
    end
	 
	 // Figure out which pixel address to write to
    else if (data_in_en) begin
		if (input_addr >= 320*3+3) temp_addr <= (input_addr-320*3-3);
		else temp_addr <= (320*240-320*3-3+input_addr);
    end
end


conv_ram fram(.clock(clk), .data(temp_out),.rdaddress(input_addr),.wraddress(temp_addr),.wren(write),.q(out));

endmodule

// To implement the line buffer
module ShiftRegister4Out #(
    parameter length, bit_width
) 

(
    input clk, rst,
    input [bit_width-1:0] in,
	 input en,
    output [bit_width-1:0] out0, out1, out2, out3
);

	 integer i;
    reg [bit_width-1:0] registers [length-1:0];
	 
    always @(posedge clk, negedge rst)
    begin
	 
		  // If there is a reset, set all registers to 0
        if(~rst)
			  begin
					for (i=0; i<length; i=i+1) registers[i] <= 0;
			  end
			  
		  // Otherwise, shift the register data down
        else if (en)
        begin
            registers[0] <= in;
            for (i=1; i<length; i=i+1) registers[i] <= registers[i-1];
        end
    end
    assign out0 = registers[length-1];
    assign out1 = registers[length-3];
    assign out2 = registers[length-5];
    assign out3 = registers[length-7];
	 
endmodule


/*
 * Kernals. See https://en.wikipedia.org/wiki/Kernel_(image_processing) 
 *  
 * Sharpen:
 * | 0 -1  0|
 * |-1  5 -1|
 * | 0 -1  0|
 *
 * Gaussian Blur:
 *   1  |1  2  1|
 *  --- |2  4  2|
 *   16 |1  2  1|
 *
 * Ridge Detection:
 * |-1 -1 -1|
 * |-1  8 -1|
 * |-1 -1 -1|
 *
 * parameter [8:0] kernel is indexed like:
 * |0  1  2|
 * |3  4  5|
 * |6  7  8|
 * 
 */