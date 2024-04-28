`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_RegFile (
   input logic clock, 
   input logic fetch_part,
   input logic rs2_part_override,
   input logic [4:0] fetch_register_1,
   input logic [4:0] fetch_register_2,

   input logic write_part,
   input logic [4:0] write_register,
   input logic [31:0] data_in,
   input logic write_enable,

   output logic [31:0] data_out_1,
   output logic [31:0] data_out_2,
   output logic [63:0] debug_register28);

    
    reg [63:0] registers [0:31]; // register file - register zero is hardcoded to 0 when fetching
    // however range starts at zero to allow for BRAM inference
    logic [31:0] alt_part;
    
    always_comb begin
        data_out_1 = get_register_part(fetch_register_1, fetch_part);
        data_out_2 = get_register_part(fetch_register_2, rs2_part_override ? 0 : fetch_part);
        alt_part = get_register_part(write_register, !write_part);
        debug_register28 = registers[28];
    end

    always_ff @(posedge clock) 
        if (write_enable) begin
            registers[write_register] <= get_reg_write_value(write_part, data_in);
        end

    function automatic logic [63:0] get_reg_write_value(logic part, logic [31:0] value);
        case (part)
            1'b0: return { alt_part, value };
            1'b1: return { value, alt_part };
        endcase
    endfunction

    function automatic logic [31:0] get_register_part(logic [4:0] register, logic part);
        logic [63:0] value = register == zero ? '0 : registers[register];
        case (part)
            1'b0: return value[31:0];
            1'b1: return value[63:32];
        endcase
    endfunction

endmodule

