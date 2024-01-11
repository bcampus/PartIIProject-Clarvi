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
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,

    output logic [61 -DATA_ADDR_WIDTH:0] address_high_bits,  // beyond our address width so should be 0
    // data memory port (read/write)
    output logic [DATA_ADDR_WIDTH-1:0] main_address,
    output logic [1:0]  word_offset,
    output logic [3:0]  main_byte_enable,
    output logic        main_read_enable,
    output logic        main_write_enable,
    output logic [31:0] main_write_data,

    output logic mem_address_error,
    output logic main_read_pending, //whether we have sent a memory read which has not yet been replied to
    output logic access_part,
    output logic stall_for_multiple_access
);
    logic [63:0] mem_address;
    logic [32:0] mem_addr_state;
    logic [31:0] write_data_lower;

    always_comb begin
        main_read_enable  = !stage_invalid && !interrupt && !mem_address_error && instr.memory_read && !stall_for_memory_pending && instr.instr_part == 1;
        main_write_enable = !stage_invalid && !interrupt && !mem_address_error && instr.memory_write && !stall_for_memory_pending && instr.instr_part == 1;

        // do address calculation, using bit 32 to propagate carry between
        // adds
        case (instr.instr_part)
            1'b0: mem_address = {32'b0, rs1_value} + instr.immediate;
            1'b1: mem_address = {rs1_value + instr.immediate + mem_addr_state[32],
                                    mem_addr_state[31:0]}; 
        endcase
        // our memory is word addressed, so cut off the bottom two bits (this becomes the word offset),
        // and the higher bits beyond our address range which should be 0.
        {address_high_bits, main_address, word_offset} = mem_address + access_part * 4;

        // set byte_enable mask according to whether we are loading/storing a word, half word or byte.
        main_byte_enable = compute_byte_enable(instr.memory_width, word_offset, access_part);

        // shift the store value into the correct position in the 64-bit word
        main_write_data = ({rs2_value, write_data_lower} << word_offset*8) >> access_part * 32;

        // Stall earlier stages if not the last read
        stall_for_multiple_access = (main_read_enable || main_write_enable) && access_part != 1;
`ifdef MACHINE_MODE
        // load/store fault or misaligned exception
        mem_address_error = 0 && (address_high_bits != '0 || !is_aligned(word_offset, instr.memory_width)); 
`else
        mem_address_error = '0;
`endif
    end

    always_ff @(posedge clock)
        if (reset) begin
            main_read_pending <= 0;
        end else begin
            if (!stall) begin
                //To prevent calculated address from changing after it is
                //accumulated.
                if (instr.instr_part != 1) begin
                    mem_addr_state   <= mem_address;
                    write_data_lower <= rs2_value; 
                end

                main_read_pending   <= main_read_enable;
                
                if (!stage_invalid && (instr.memory_read || instr.memory_write) && instr.instr_part == 1) begin
                    access_part <= access_part + 1;
                end
                else
                    access_part <= 0;
            end
        end
       
    // === Memory Access functions =============================================

    function automatic logic [3:0] compute_byte_enable(mem_width_t width, logic [1:0] word_offset, logic access_part);
        //right shift to handle the case that we are loading the upper bits
        unique case (width)
            B: return (8'b00000001 << word_offset) >> access_part * 4;
            H: return (8'b00000011 << word_offset) >> access_part * 4;
            W: return (8'b00001111 << word_offset) >> access_part * 4;
            D: return (8'b11111111 << word_offset) >> access_part * 4;
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
