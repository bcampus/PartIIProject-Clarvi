`ifndef RISCV_SVH
`include "riscv.svh"
`endif

`define MACHINE_MODE

module clarvi_MMU #(
    parameter DATA_ADDR_WIDTH = 14,
    parameter INSTR_ADDR_WIDTH = 14
)(
    input logic clock,
    input logic reset,
    input logic stall,
    input logic interrupt,
    input logic stall_for_memory_pending,
    input instr_t instr,
    input logic stage_invalid,
    input logic [63:0] rs1_value,
    input logic [63:0] rs2_value,

    output logic [60 -DATA_ADDR_WIDTH:0] address_high_bits,  // beyond our address width so should be 0
    // data memory port (read/write)
    output logic [DATA_ADDR_WIDTH-1:0] main_address,
    output logic [2:0]  word_offset,
    output logic [7:0]  main_byte_enable,
    output logic        main_read_enable,
    output logic        main_write_enable,
    output logic [63:0] main_write_data,

    output logic mem_address_error,
    output logic main_read_pending //whether we have sent a memory read which has not yet been replied to
);
    logic [63:0] mem_address;

    always_comb begin
        // do address calculation, using bit 32 to propagate carry between
        // adds
        mem_address = rs1_value + instr.immediate;
        // our memory is word addressed, so cut off the bottom two bits (this becomes the word offset),
        // and the higher bits beyond our address range which should be 0.
        {address_high_bits, main_address, word_offset} = mem_address;

        main_read_enable  = !stage_invalid && !interrupt && !mem_address_error && instr.memory_read && !stall_for_memory_pending && instr.instr_part == 7;
        main_write_enable = !stage_invalid && !interrupt && !mem_address_error && instr.memory_write && !stall_for_memory_pending && instr.instr_part == 7 && address_high_bits == 0;

        // set byte_enable mask according to whether we are loading/storing a word, half word or byte.
        main_byte_enable = compute_byte_enable(instr.memory_width, word_offset);

        // shift the store value into the correct position in the 64-bit word
        main_write_data = rs2_value << word_offset*8;

`ifdef MACHINE_MODE
        // load/store fault or misaligned exception
        mem_address_error = 0 && (address_high_bits != '0 || !is_aligned(word_offset, instr.memory_width)); 
`else
        mem_address_error = '0;
`endif

        main_read_enable  = !stage_invalid && !interrupt && !mem_address_error && instr.memory_read && !stall_for_memory_pending;
        main_write_enable = !stage_invalid && !interrupt && !mem_address_error && instr.memory_write && !stall_for_memory_pending;
    end

    always_ff @(posedge clock)
        if (reset) begin
            main_read_pending <= 0;
        end else begin
            if (!stall) begin
                main_read_pending   <= main_read_enable;
            end
        end
       
    // === Memory Access functions =============================================

    function automatic logic [7:0] compute_byte_enable(mem_width_t width, logic [2:0] word_offset);
        //right shift to handle the case that we are loading the upper bits
        unique case (width)
            B: return (8'b00000001 << word_offset);
            H: return (8'b00000011 << word_offset);
            W: return (8'b00001111 << word_offset);
            D: return (8'b11111111 << word_offset);
            default: return 'x;
        endcase
    endfunction

`ifdef MACHINE_MODE
    function automatic logic is_aligned(logic [1:0] word_offset, mem_width_t width);
        unique case (width)
            W: return word_offset == '0;
            H: return word_offset[0] == '0;
            default: return '1;
        endcase
    endfunction
`endif

endmodule
