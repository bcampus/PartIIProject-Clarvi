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
    input logic [7:0] rs1_value,
    input logic [7:0] rs2_value,

    output logic [63 -DATA_ADDR_WIDTH:0] address_high_bits,  // beyond our address width so should be 0
    // data memory port (read/write)
    output logic [DATA_ADDR_WIDTH-1:0] main_address,
    output logic        main_byte_enable,
    output logic        main_read_enable,
    output logic        main_write_enable,
    output logic [ 7:0] main_write_data,

    output logic mem_address_error,
    output logic main_read_pending, //whether we have sent a memory read which has not yet been replied to
    output logic [2:0] access_part,
    output logic stall_for_multiple_access
);
    logic [63:0] mem_address;
    logic [56:0] mem_addr_state;
    logic [7:0] write_data_lower [0:6];

    always_comb begin
        // do address calculation, using bit 32 to propagate carry between
        // adds
        case (instr.instr_part)
            0: mem_address = {56'b0, rs1_value} + instr.immediate;
            1: mem_address = {{48'b0, rs1_value} + instr.immediate + mem_addr_state[8],
                                    mem_addr_state[7:0]}; 
            2: mem_address = {{40'b0, rs1_value} + instr.immediate + mem_addr_state[16],
                                    mem_addr_state[15:0]}; 
            3: mem_address = {{32'b0, rs1_value} + instr.immediate + mem_addr_state[24],
                                    mem_addr_state[23:0]}; 
            4: mem_address = {{24'b0, rs1_value} + instr.immediate + mem_addr_state[32],
                                    mem_addr_state[31:0]}; 
            5: mem_address = {{16'b0, rs1_value} + instr.immediate + mem_addr_state[40],
                                    mem_addr_state[39:0]}; 
            6: mem_address = {{8'b0, rs1_value} + instr.immediate + mem_addr_state[48],
                                    mem_addr_state[47:0]}; 
            7: mem_address = {rs1_value + instr.immediate + mem_addr_state[56],
                                    mem_addr_state[55:0]}; 
        endcase
        // our memory is word addressed, so cut off the bottom two bits (this becomes the word offset),
        // and the higher bits beyond our address range which should be 0.
        {address_high_bits, main_address} = mem_address + access_part;

        main_read_enable  = !stage_invalid && !interrupt && !mem_address_error && instr.memory_read && !stall_for_memory_pending && instr.instr_part == 7;
        main_write_enable = !stage_invalid && !interrupt && !mem_address_error && instr.memory_write && !stall_for_memory_pending && instr.instr_part == 7 && address_high_bits == 0;

        // set byte_enable mask according to whether we are loading/storing a word, half word or byte.
        main_byte_enable = compute_byte_enable(instr.memory_width, access_part);

        // shift the store value into the correct position in the 64-bit word
        main_write_data = {rs2_value, write_data_lower[6], write_data_lower[5], 
                            write_data_lower[4], write_data_lower[3], 
                            write_data_lower[2], write_data_lower[1], 
                            write_data_lower[0]} >> access_part * 8;

        // Stall earlier stages if not the last read
        stall_for_multiple_access = (main_read_enable || main_write_enable) && access_part != 7;
`ifdef MACHINE_MODE
        // load/store fault or misaligned exception
        mem_address_error = 0 && address_high_bits != '0; 
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
                if (instr.instr_part != 7) begin
                    mem_addr_state   <= mem_address[56:0];
                    write_data_lower[instr.instr_part] <= rs2_value; 
                end

                main_read_pending   <= main_read_enable;
                
                if (!stage_invalid && (instr.memory_read || instr.memory_write) && instr.instr_part == 7) begin
                    access_part <= access_part + 1;
                end
                else
                    access_part <= 0;
            end
        end
       
    // === Memory Access functions =============================================

    function automatic logic compute_byte_enable(mem_width_t width, logic [3:0] access_part);
        //right shift to handle the case that we are loading the upper bits
        unique case (width)
            B: return access_part == 0;
            H: return access_part <  2;
            W: return access_part <  4;
            D: return 1;
            default: return 'x;
        endcase
    endfunction

endmodule
