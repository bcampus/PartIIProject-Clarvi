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
   input logic [ 7:0] data_in,
   input logic write_enable,

   output logic [ 7:0] data_out_1,
   output logic [ 7:0] data_out_2,
   output logic [63:0] debug_register28);

    
    reg [7:0] registers [255:0]; 
    // register file - register zero is hardcoded to 0 when fetching
    // however range starts at zero to allow for BRAM inference
    // Registers are byte addressable since we only read/write a byte at a time
    
    always_comb begin
        data_out_1 = get_register_part(fetch_register_1, fetch_part);
        data_out_2 = get_register_part(fetch_register_2, fetch_part);
        debug_register28 = '0;
    end

    always_ff @(posedge clock) 
        if (write_enable) begin
            registers[{write_register, write_part}] <= data_in;
        end

    function automatic logic [7:0] get_register_part(logic [4:0] register, logic [2:0] part);
        logic [7:0] value = register == zero ? '0 : registers[{register,part}];
        return value;
    endfunction


endmodule

