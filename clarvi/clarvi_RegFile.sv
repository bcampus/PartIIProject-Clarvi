`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_RegFile (
   input logic clock, 
   input logic [1:0] fetch_part,
   input logic [4:0] fetch_register_1,
   input logic [4:0] fetch_register_2,

   input logic [1:0] write_part,
   input logic [4:0] write_register,
   input logic [15:0] data_in,
   input logic write_enable,

   output logic [15:0] data_out_1,
   output logic [15:0] data_out_2,
   output logic [63:0] debug_register28);

    
    reg [63:0] registers [0:31]; // register file - register zero is hardcoded to 0 when fetching
    // however range starts at zero to allow for BRAM inference
    logic [47:0] alt_part;
    
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

    function automatic logic [63:0] get_reg_write_value(logic [1:0] part, logic [15:0] value);
        case (part)
            2'b00: return { alt_part, value };
            2'b01: return { alt_part[47:16], value, alt_part[15:0] };
            2'b10: return { alt_part[47:32], value, alt_part[31:0] };
            2'b11: return { value, alt_part };
        endcase
    endfunction
    
    function automatic logic [47:0] get_reg_write_unwritten_part(logic [4:0] register, logic [1:0] part);
        logic [63:0] value = register == zero ? '0 : registers[register];
        case (part)
            2'b00: return value[63:16];
            2'b01: return { value[63:32], value[15:0] };
            2'b10: return { value[63:48], value[31:0] };
            2'b11: return value[47: 0];
        endcase
    endfunction

    function automatic logic [31:0] get_register_part(logic [4:0] register, logic [1:0] part);
        logic [63:0] value = register == zero ? '0 : registers[register];
        case (part)
            2'b00: return value[15: 0];
            2'b01: return value[31:16];
            2'b10: return value[47:32];
            2'b11: return value[63:48];
        endcase
    endfunction

endmodule

