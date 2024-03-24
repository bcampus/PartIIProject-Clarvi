`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_RegFile (
   input logic clock, 
   input logic [2:0] fetch_part,
   input logic [4:0] fetch_register_1,
   input logic [4:0] fetch_register_2,

   input logic [2:0] write_part,
   input logic [4:0] write_register,
   input logic [7:0] data_in,
   input logic write_enable,

   output logic [7:0] data_out_1,
   output logic [7:0] data_out_2,
   output logic [63:0] debug_register28);

    
    reg [63:0] registers [0:31]; // register file - register zero is hardcoded to 0 when fetching
    // however range starts at zero to allow for BRAM inference
    logic [55:0] alt_part;
    
    always_comb begin
        data_out_1 = get_register_part(fetch_register_1, fetch_part);
        data_out_2 = get_register_part(fetch_register_2, fetch_part);
        alt_part = get_reg_write_unwritten_part(write_register, write_part);
        debug_register28 = registers[28];
    end

    always_ff @(posedge clock) 
        if (write_enable) begin
            registers[write_register] <= get_reg_write_value(write_part, data_in);
        end

    function automatic logic [63:0] get_reg_write_value(logic [2:0] part, logic [7:0] value);
        case (part)
            3'b000: return { alt_part, value };
            3'b001: return { alt_part[55:8], value, alt_part[7:0] };
            3'b010: return { alt_part[55:16], value, alt_part[15:0] };
            3'b011: return { alt_part[55:24], value, alt_part[23:0] };
            3'b100: return { alt_part[55:32], value, alt_part[31:0] };
            3'b101: return { alt_part[55:40], value, alt_part[39:0] };
            3'b110: return { alt_part[55:48], value, alt_part[47:0] };
            3'b111: return { value, alt_part };
        endcase
    endfunction
    
    function automatic logic [55:0] get_reg_write_unwritten_part(logic [4:0] register, logic [2:0] part);
        logic [63:0] value = register == zero ? '0 : registers[register];
        case (part)
            3'b000: return value[63:8];
            3'b001: return { value[63:16], value[7:0] };
            3'b010: return { value[63:24], value[15:0] };
            3'b011: return { value[63:32], value[23:0] };
            3'b100: return { value[63:40], value[31:0] };
            3'b101: return { value[63:48], value[39:0] };
            3'b110: return { value[63:56], value[47:0] };
            3'b111: return value[55: 0];
        endcase
    endfunction

    function automatic logic [8:0] get_register_part(logic [4:0] register, logic [2:0] part);
        logic [63:0] value = register == zero ? '0 : registers[register];
        case (part)
            3'b000: return value[ 7:  0];
            3'b001: return value[15:  8];
            3'b010: return value[23: 16];
            3'b011: return value[31: 24];
            3'b100: return value[39: 32];
            3'b101: return value[47: 40];
            3'b110: return value[55: 48];
            3'b111: return value[63: 56];
        endcase
    endfunction

endmodule

