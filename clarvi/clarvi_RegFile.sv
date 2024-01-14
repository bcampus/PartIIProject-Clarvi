`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_RegFile (
   input logic clock, 
   input logic [4:0] fetch_register_1,
   input logic [4:0] fetch_register_2,

   input logic [4:0] write_register,
   input logic [63:0] data_in,
   input logic write_enable,

   output logic [63:0] data_out_1,
   output logic [63:0] data_out_2,
   output logic [63:0] debug_register28);

    
    reg [63:0] registers [0:31]; // register file - register zero is hardcoded to 0 when fetching
    // however range starts at zero to allow for BRAM inference
    
    always_comb begin
        data_out_1 = fetch_register_1 == zero ? '0 : registers[fetch_register_1];
        data_out_2 = fetch_register_2 == zero ? '0 : registers[fetch_register_2];
        debug_register28 = registers[28];
    end

    always_ff @(posedge clock) 
        if (write_enable)
            registers[write_register] <= data_in;

endmodule

