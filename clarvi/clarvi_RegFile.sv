`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_RegFile (
   input logic clock, 
   input logic fetch_part,
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
    
    always_comb begin
        data_out_1 = fetch(fetch_register_1, fetch_part);
        data_out_2 = fetch(fetch_register_2, fetch_part);
        debug_register28 = registers[28];
    end

    always_ff @(posedge clock) 
        if (write_enable)
            case (write_part)
                1'b0: registers[write_register][31: 0] <= data_in;
                1'b1: registers[write_register][63:32] <= data_in;
            endcase

    function automatic logic [31:0] fetch(logic[4:0] register, logic instr_part);
        // register zero is wired to constant 0.
        if (register == zero) return '0;
        else begin
            logic [63:0] value = registers[register];
            unique case (instr_part)
                1'b0: return value[31:0];
                1'b1: return value[63:32];
            endcase
        end
    endfunction

endmodule

