package neural_network_pkg;

    typedef enum logic { ReLu, Sigmoid } activation_t;

    function logic signed [4:0][4:0][31:0] get_kernel(input string kernel_name);
        case (kernel_name)
            "conv1_1": return '{'{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}};
            "conv1_2": return '{'{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}, '{1, 1, 1, 1, 1}};
            default: $error("No kernel with name %s!", kernel_name);
        endcase
    endfunction

    function logic signed [31:0] real_to_fixed_point(input real number, input int unsigned frac_bits);
        // Scale the real number by 2^fraction_bits to account for the fractional part
        automatic real scaled_number = number * (2 ** frac_bits);
        //Round the scaled number to the nearest integer
        automatic int signed rounded_number = $rtoi(scaled_number);   
        // Cast the integer to a fixed-width logic vector
        automatic logic signed [31:0] fixed_point_number = rounded_number;
        return fixed_point_number;
    endfunction

endpackage