/*******************************************************************************
Copyright (c) 2016, Robert Eady
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*******************************************************************************/

/*******************************************************************************

The processor has a 6 stage pipeline, with pipeline registers between stages.
Instruction fetch takes two cycles.

Note that memory accesses are submitted in the execute stage and loaded values
aligned in the memory align stage. Branches are performed in the execute stage.

There are forwarding paths from the output of the execute, memory align and
write back stages into the end of the decode stage.

                 IF/DE      DE/EX       EX/MA            MA/WB
Instruction Fetch --> Decode --> Execute --> Memory Align --> Write Back
                          ^-----------/---------------/---------------/

List of abbreviations/conventions:

instr: instruction              if: instruction fetch
pc:  program counter            de: decode
imm: immediate value            ex: execute
rd:  destination register       alu: arithmetic logic unit
rs1: source register 1          wb: write back
rs2: source register 2
avm: avalon master (memory interface)
inr: interrupt receiver

Pipeline register values are prefixed according to the stages they fall between,
e.g. de_ex_instr is a DE/EX pipeline register storing the decoded instruction.

Combination signals are prefixed with the stage they are used in,
e.g. ex_alu_result is output of the ALU in the execute stage.

The core only supports single cycle latency instruction memory.
Main memory can have arbitrary (>= 1 cycle) latency.

*******************************************************************************/
`ifndef RISCV_SVH
`include "riscv.svh"
`endif

`define MACHINE_MODE    // enable support for machine mode instructions, interrupts and exceptions
`define DEBUG           // enable debug outputs
`ifdef MODEL_TECH
    `define SIMULATION  // enable simulation features
    //`define TRACE       // enable full instruction tracing in simulation.
`endif

`timescale 1ns/10ps

module clarvi #(
    parameter DATA_ADDR_WIDTH = 14,
    parameter INSTR_ADDR_WIDTH = 14,
    parameter INITIAL_PC = 0,
    parameter DEFAULT_TRAP_VECTOR = 0
)(
    input logic clock,
    input logic reset,

    // data memory port (read/write)
    output logic [DATA_ADDR_WIDTH-1:0] main_address,
    output logic [1:0]  main_byte_enable,
    output logic        main_read_enable,
    input  logic [15:0] main_read_data,
    input  logic        main_read_data_valid,
    output logic        main_write_enable,
    output logic [15:0] main_write_data,
    input  logic        main_wait,

    // instruction memory port (read-only)
    output logic [INSTR_ADDR_WIDTH-1:0] instr_address,
    output logic        instr_read_enable,
    input  logic [15:0] instr_read_data,
    input  logic        instr_wait,

    // external interrupt signal, active high
    input  logic        inr_irq,

    // debug ports
    output logic [63:0] debug_register28,
    output logic [63:0] debug_scratch,
    output logic [63:0] debug_pc
);

    localparam TRACE = 1;

    logic [63:0] instret = '0;  // number of instructions retired (completed)
    logic [63:0] cycles  = '0;  // cycle counter
    always_ff @(posedge clock) cycles <= reset ? 0 : cycles + 1;

    // Some CSRs (Control and Status Registers)
    mstatus_t mstatus = '0;  // status
    mie_t mie = '0;          // interrupts enabled
    mip_t mip;               // interrupts pending
    logic [63:0] dscratch;   // debug scratch register, used for debug output
    logic [63:0] mtvec = DEFAULT_TRAP_VECTOR;  // trap handler address

    // traps caused by the instruction being fetched or executed
    logic interrupt, if_exception, ex_exception, ex_mem_address_error;

    logic main_read_pending; //whether we have sent a memory read which has not yet been replied to
    
    // buffer to hold the last valid main memory read response: valid is set iff this data has not yet been used by MA
    logic[15:0] main_read_data_buffer;
    logic main_read_data_buffer_valid = 0;

    // Stage invalidation flags
    logic if_invalid = 1;
    logic if_de_invalid = 1;
    logic de_ex_invalid = 1;
    logic ex_ma_invalid = 1;
    logic ma_wb_invalid = 1;

    logic stall_for_memory_wait;   // stall everything when main memory or instruction memory isn't ready for load/store/IF
    logic stall_for_load_dep; // stall IF, DE and repeat EX for a load followed by dependent instruction
    logic stall_for_memory_pending; //stall IF, DE and EX when a read request is late being answered
    logic stall_for_decode; //Stall IF if decode is splitting the instruction in two to be fed down the pipeline
    logic stall_for_multiple_access; //Stall IF, DE when multiple words of memory require loading
    
    // distribute stall signals to each stage:
    logic stall_if;
    logic stall_de;
    logic stall_ex;
    logic stall_ma;
    logic stall_wb;
    
    always_comb begin
        stall_if = stall_for_memory_wait || stall_for_memory_pending || stall_for_load_dep || stall_for_multiple_access || stall_for_decode ;
        stall_de = stall_for_memory_wait || stall_for_memory_pending || stall_for_load_dep || stall_for_multiple_access;
        stall_ex = stall_for_memory_wait || stall_for_memory_pending;
        stall_ma = stall_for_memory_wait;
        stall_wb = stall_for_memory_wait;
    end

    // === Instruction Fetch ===================================================

    logic [63:0] pc = INITIAL_PC;
    logic [63:0] if_pc, if_de_pc;
    logic [31:0] if_de_instr;
    logic [15:0] instr_read_data_buffer, if_instr_lower; 
    logic if_stall_on_prev;
    logic if_fetch_part = '0;
    logic if_prev_part;//records previous part issued for (and is currently on instr line)

    always_comb begin
        // PC is byte-addressed but our instruction memory is word-addressed
        instr_address = pc[INSTR_ADDR_WIDTH:1] + if_fetch_part;
        // read the next instruction on every cycle
        instr_read_enable = '1;
    end

    always_ff @(posedge clock) begin
        // buffer the last instruction read before a stall.
        if_stall_on_prev <= stall_if;
        if_prev_part <= if_fetch_part;
        if_fetch_part <= !if_fetch_part && !stall_if && !if_invalid;

        if (if_prev_part == 0 && !if_stall_on_prev) 
            if_instr_lower <= instr_read_data;
        if (if_prev_part == 1 && stall_if)
            instr_read_data_buffer <= instr_read_data;

        if (!stall_if && (if_stall_on_prev || if_prev_part == 1)) begin
            // if there was a stall on the last cycle, we read from the instruction buffer not the bus.
            // this allows the PC to 'catch up' on the next cycle.
            if_de_instr <= { if_prev_part == 1 ? instr_read_data : instr_read_data_buffer, if_instr_lower };
            if_de_pc <= if_pc;
        end
    end

    // === Decode ==============================================================

    logic [15:0] de_rs1_fetched, de_rs2_fetched;
    logic [15:0] de_rs1_value, de_rs2_value, de_ex_rs1_value, de_ex_rs2_value;
    logic de_rs2_part_override;
    instr_t      de_instr, de_ex_instr;

    //defined to allow referencing of later defined vars
    instr_t de_ex_ma_instr, de_ma_wb_instr;
    logic [15:0] wb_forward_value, ma_forward_value, ex_forward_value;
    

    clarvi_Decode Decoder (
        .clock                          (clock),
        .in_instr                       (if_de_instr),
        .if_de_pc                       (if_de_pc),
        .stage_invalid                  (if_de_invalid),
        .stall_stage                    (stall_de),

        //Register File Inputs
        .rs1_fetched                    (de_rs1_fetched),
        .rs2_fetched                    (de_rs2_fetched),

        //Later stage inputs
        .ex_invalid                     (de_ex_invalid),
        .ma_invalid                     (ex_ma_invalid),
        .wb_invalid                     (ma_wb_invalid),
        .de_ex_instr                    (de_ex_instr),
        .ex_ma_instr                    (de_ex_ma_instr),
        .ma_wb_instr                    (de_ma_wb_instr),
        .mem_address_error              (ex_mem_address_error),

        //Memory inputs
        .instr_wait                     (instr_wait),
        .instr_read_enable              (instr_wait_enable),
        .main_wait                      (main_wait),
        .main_read_enable               (main_read_enable),
        .main_write_enable              (main_write_enable),
        .main_read_pending              (main_read_pending),
        .main_read_data_buffer_valid    (main_read_data_buffer_valid),
        .main_read_data_valid           (main_read_data_valid),
        
        //Forwarding Inputs
        .wb_forward_value               (wb_forward_value),
        .ma_forward_value               (ma_forward_value),
        .ex_forward_value               (ex_forward_value),

        .decoded_instr                  (de_instr),
        .rs2_part_override              (de_rs2_part_override),
        .rs1_value                      (de_rs1_value),
        .rs2_value                      (de_rs2_value),
        .stall_for_load_dep             (stall_for_load_dep),
        .stall_for_memory_wait          (stall_for_memory_wait),
        .stall_for_memory_pending       (stall_for_memory_pending),
        .stall_for_decode               (stall_for_decode));

    always_ff @(posedge clock) begin
        if (!stall_de) begin
            de_ex_instr <= de_instr;
            de_ex_rs1_value <= de_rs1_value;
            de_ex_rs2_value <= de_rs2_value;
        end
    end

    // === Execute =============================================================

    instr_t      ex_ma_instr;
    logic [15:0] ex_alu_result, ex_ma_result, ex_csr_read;
    logic ex_word_offset, ex_ma_word_offset;
    logic [62 -DATA_ADDR_WIDTH:0] ex_address_high_bits;  // beyond our address width so should be 0
    logic [1:0] ex_access_part;

    assign de_ex_ma_instr = ex_ma_instr;
    assign ex_forward_value = ex_alu_result;
    
    clarvi_ALU ALU(
        .clock (clock),
        .reset (reset),
        .stall (stall_ex),
        .instr (de_ex_instr),
        .rs1_value (de_ex_rs1_value),
        .rs2_value (de_ex_rs2_value),
        .result (ex_alu_result) );

    clarvi_MMU #(.DATA_ADDR_WIDTH(DATA_ADDR_WIDTH), .INSTR_ADDR_WIDTH(INSTR_ADDR_WIDTH)) MMU (
        .clock                      (clock),
        .reset                      (reset),
        .stall                      (stall_ex),
        .interrupt                  (interrupt),
        .stall_for_memory_pending   (stall_for_memory_pending),
        .instr                      (de_ex_instr),
        .stage_invalid              (de_ex_invalid),
        .rs1_value                  (de_ex_rs1_value),
        .rs2_value                  (de_ex_rs2_value),

        .address_high_bits          (ex_address_high_bits),
        .main_address               (main_address),
        .word_offset                (ex_word_offset),
        .main_byte_enable           (main_byte_enable),
        .main_read_enable           (main_read_enable),
        .main_write_enable          (main_write_enable),
        .main_write_data            (main_write_data),

        .mem_address_error          (ex_mem_address_error),
        .main_read_pending          (main_read_pending), //whether we have sent a memory read which has not yet been replied to
        .access_part                (ex_access_part) ,
        .stall_for_multiple_access  (stall_for_multiple_access)
    );

    always_comb begin
        // CSR Read results
        ex_csr_read = read_csr_part(csr_t'(de_ex_instr.funct12), de_ex_instr.instr_part);
    end

    always_ff @(posedge clock)
        if (!reset) begin
            if (!stall_ex) begin
                ex_ma_instr         <= de_ex_instr;
                ex_ma_result        <= (de_ex_instr.op == CSRRW || 
                                        de_ex_instr.op == CSRRS ||
                                        de_ex_instr.op == CSRRC) ? 
                                       ex_csr_read : ex_alu_result;
                ex_ma_word_offset   <= ex_word_offset;

                if (!de_ex_invalid && (de_ex_instr.memory_read || de_ex_instr.memory_write) && de_ex_instr.instr_part == 3) begin
                    ex_ma_instr.instr_part <= ex_access_part;
                end
            end
        end

    // === Branching or Reset ==================================================

    logic ex_branch_taken, ex_branch_state, ex_branch_next_state;
    logic [63:0] ex_branch_target, ex_branch_target_state, ex_next_pc;

    always_comb begin
        ex_branch_next_state = !de_ex_invalid && is_branch_taken(de_ex_instr, de_ex_rs1_value, de_ex_rs2_value, ex_branch_state);
        ex_branch_taken = de_ex_instr.instr_part == 3 && ex_branch_next_state;
        ex_branch_target = target_pc(de_ex_instr, de_ex_rs1_value, ex_branch_target_state);
        ex_next_pc = ex_branch_taken ? ex_branch_target : pc + 4; //note that pc + 4 is actually a prediction for 3 instructions' time
    end

    always_ff @(posedge clock)
        if (reset) begin
            pc <= INITIAL_PC;
            if_invalid <= 1;
            if_de_invalid <= 1;
            de_ex_invalid <= 1;
            ex_ma_invalid <= 1;
            ma_wb_invalid <= 1;
        end else begin
            // logic for stage invalidation upon taking a branch or stalling
            // don't change the registers if the corresponding stage is stalled
            ex_branch_state <= ex_branch_next_state;
            ex_branch_target_state <= ex_branch_target;
            
            if (!stall_if) begin
                // if a trap is taken, go to the handler instead
                if (if_fetch_part == 1) begin
                    pc <= (if_exception || ex_exception) ? mtvec : ex_next_pc;
                    if_pc <= pc;
                end
            
                // invalidate on any exception, interrupt or branch.
                if_invalid <= interrupt || ex_exception || if_exception || ex_branch_taken;
                    
                // invalidate on an EX exception, interrupt or branch.
                // an IF exception can only happen after a branch so this stage would already be invalid.
                if_de_invalid <= if_invalid || interrupt || ex_exception || ex_branch_taken 
                        || (!if_stall_on_prev && if_prev_part != 1);
            end
            else if (ex_branch_taken) begin
                pc <= ex_next_pc;

                if_invalid <= '1;
                if_de_invalid <= '1;
            end else if (if_fetch_part == 1) begin
                pc <= ex_next_pc;
                if_pc <= pc;
            end
         
            // invalidate in an EX exception, interrupt, branch or load dependency stall.
            // an IF exception can only happen after a branch so this stage would already be invalid.
            if (!stall_de)  de_ex_invalid <= if_de_invalid || interrupt || ex_exception || (de_ex_instr.instr_part == 3 && ex_branch_taken);
            // we only stall de but not ex on load dep, so insert a bubble, 
            // ex_access_part distinguishes between load dep and multiple
            // access
            else if (!stall_ex && ex_access_part==3) de_ex_invalid <= 1; 
            
            // invalidate on an interrupt or any EX exception that could be caused by an instruction that writes back.
            // i.e. an exception on a load or an invalid instruction.
            // Also invalidate lower parts of load instructions
            if (!stall_ex)  ex_ma_invalid <= de_ex_invalid 
                        || interrupt 
                        || ex_mem_address_error && de_ex_instr.memory_read 
                        || de_ex_instr.op == INVALID 
                        || (de_ex_instr.memory_read || de_ex_instr.memory_write) && de_ex_instr.instr_part != 3;
            // we only stall ex and not ma when memory pending, so replay (no bubble here)
            
            // if ma received invalid data, insert a bubble into wb
            if (!stall_ma)  ma_wb_invalid <= ex_ma_invalid || stall_for_memory_pending;
        end

    // === Memory Align ========================================================

    instr_t ma_wb_instr;
    logic[15:0] ma_result, ma_load_value, ma_wb_value;
    logic ma_carry;

    assign de_ma_wb_instr = ma_wb_instr;
    assign ma_forward_value = ma_result;

    always_comb begin
        // align the loaded value: if we stalled on last cycle then take buffered data instead
        ma_load_value = load_shift_mask_extend(ex_ma_instr.instr_part,
                                               ex_ma_instr.memory_width,
                                               ex_ma_instr.memory_read_unsigned,
                                               main_read_data_valid ? main_read_data : main_read_data_buffer,
                                               ex_ma_word_offset,
                                               ma_carry);
        // if this isn't a load instruction, pass through the ALU result instead
        ma_result = ex_ma_instr.memory_read ? ma_load_value : ex_ma_result;
    end

    always_ff @(posedge clock)
        if (reset) begin
            main_read_data_buffer_valid <= 0;
        end else begin
            if (!stall_ma) begin
                  ma_carry    <= ma_load_value[15];
                  ma_wb_instr <= ex_ma_instr;
                  ma_wb_value <= ma_result;
                  main_read_data_buffer_valid <= 0;
            end else begin
                  main_read_data_buffer_valid <= main_read_data_buffer_valid || main_read_data_valid;
            end
            //buffer the last data returned in case of stall
            if (main_read_data_valid) begin
                  main_read_data_buffer <= main_read_data;
            end
        end

    // === Write Back ==========================================================

    logic register_write_enable;

    assign wb_forward_value = ma_wb_value;

    clarvi_RegFile RegisterFile (
        .clock              (clock),
        .fetch_part         (de_instr.instr_part),
        .rs2_part_override  (de_rs2_part_override),
        .fetch_register_1   (de_instr.rs1),
        .fetch_register_2   (de_instr.rs2),
        .write_part         (ma_wb_instr.instr_part),
        .write_register     (ma_wb_instr.rd),
        .data_in            (ma_wb_value),
        .write_enable       (register_write_enable),
        .data_out_1         (de_rs1_fetched),
        .data_out_2         (de_rs2_fetched),
        .debug_register28   (debug_register28));


    always_comb register_write_enable = !(stall_wb || ma_wb_invalid)
                               && ma_wb_instr.enable_wb;

    always_ff @(posedge clock) begin
        if (!stall_wb && !ma_wb_invalid) begin
            instret <= instret + 1;
        end
    end


`ifdef MACHINE_MODE

    // === Interrupts and Exceptions ===========================================

    logic [63:0] mcause;        // trap cause
    logic [63:0] mepc;          // return address after handling trap
    logic [63:0] mbadaddr;      // address of instruction which caused an access/misaligned fault
    logic [63:0] mscratch;      // machine mode scratch register
    logic [63:0] timecmp = '0;  // time compare register for triggering timer interrupt

    logic [63:0] trap_pc;       // the address of the instruction that caused the trap or suffered the interrupt
    logic [63:0] potential_mepc;

    always_comb begin
        // wire external interrupt signal to the mip.meip register bit
        mip.meip = inr_irq;
        // raise a timer interrupt when time (cycle count) is less than timecmp
        mip.mtip = cycles >= timecmp;
        // interrupt is only raised if appropriate interrupt enable bits are set
        interrupt = mstatus.mie && (mip.meip && mie.meie || mip.msip && mie.msie || mip.mtip && mie.mtie);
        // instruction fetch fault or misaligned exception
        if_exception = pc[63:INSTR_ADDR_WIDTH+2] != '0 || !is_aligned(pc[1:0], W);
        // any exception or trap raised by the currently executing instruction
        ex_exception = !de_ex_invalid && (ex_mem_address_error && (de_ex_instr.memory_read || de_ex_instr.memory_write)
                    || de_ex_instr.op == INVALID || de_ex_instr.op == ECALL || de_ex_instr.op == EBREAK);

        if (if_exception)
            trap_pc = pc;
        else if (de_ex_invalid)
            // if we get an interrupt while the execute stage is invalid, return to the next valid instruction instead.
            trap_pc = potential_mepc;
        else
            trap_pc = de_ex_instr.pc;
    end

    always_ff @(posedge clock) begin
        // In case an interrupt happens while EX is invalid, we must remember what PC to return to after the handler.
        // EX could be invalidated by (a) an interrupt/exception, (b) a branch, or (c) a load dependency.
        // We needn't worry about (a) because interrupts will first be disabled in this case.
        // So whenever EX is valid, we just remember the branch target if a branch is happening, for case (b),
        // or otherwise the PC of the intruction about to be decoded, which would be next up in case (c).
        if (!de_ex_invalid) begin
            potential_mepc <= ex_branch_taken ? ex_branch_target : if_de_pc;
        end

        if (reset) begin
            // reset the CSR state for interrupts/exceptions
            mtvec <= DEFAULT_TRAP_VECTOR;
            mstatus <= '0;
            mie <= '0;
        end
        
        if ((!stall_if && if_exception) || (!stall_ex && ex_exception) || interrupt) begin
            // Entering a trap handler. Push 0 onto the mstatus interrupts-enabled stack
            mstatus.mpie <= mstatus.mie;
            mstatus.mie <= '0;
            // record the address of the instruction that caused the trap or the instruction that got interrupted
            mbadaddr <= trap_pc;
            mepc <= trap_pc;
            // set the trap cause
            mcause <= get_trap_cause();
         end

         if (!stall_ex && !de_ex_invalid && de_ex_instr.op == MRET) begin
            // Returning from trap handler. Pop the mstatus interrupts-enabled stack.
            mstatus.mie <= mstatus.mpie;
            mstatus.mpie <= '1;
         end
         
         // Do CSR write/set/clear operations if we are executing a CSR instruction
         if (!stall_ex && !de_ex_invalid && !interrupt)
            // CSR operations can't cause a trap because they decode into INVALID instead
            execute_csr(de_ex_instr, de_ex_rs1_value);
    end

`else
    // if machine mode is disabled, there are never any interrupts or exceptions.
    always_comb begin
        interrupt = '0;
        if_exception = '0;
        ex_exception = '0;
    end
`endif

    // === Execute functions ===================================================

    function automatic logic is_branch_taken(instr_t instr, logic [15:0] rs1_value, logic [15:0] rs2_value, logic state);
        unique case (instr.op)
            BEQ:  return rs1_value == rs2_value && (instr.instr_part == 0 || state);
            BNE:  return rs1_value != rs2_value || (instr.instr_part != 0 && state);
            BGEU: return rs1_value > rs2_value || (rs1_value == rs2_value && (instr.instr_part == 0 || state)); 
            BLTU: return rs1_value < rs2_value || (rs1_value == rs2_value && (instr.instr_part != 0 && state));
            BGE: case(instr.instr_part)
                3: return $signed(rs1_value) > $signed(rs2_value) || (rs1_value == rs2_value && state);
                default: return rs1_value > rs2_value || (rs1_value == rs2_value && (instr.instr_part == 0 || state));
            endcase
            BLT:  case(instr.instr_part)
                3: return $signed(rs1_value) < $signed(rs2_value) || (rs1_value == rs2_value && state);
                default: return rs1_value < rs2_value || (rs1_value == rs2_value && (instr.instr_part != 0 && state));
            endcase
            // we implement fence.i (sync instruction and data memory) by doing a branch to reload the next instruction
            JAL, JALR, FENCE_I, MRET: return '1;
            default: return '0;
        endcase
    endfunction


    function automatic logic [63:0] target_pc(instr_t instr, logic [15:0] rs1_value, logic [63:0] state);
        unique case (instr.op)
            JAL, BEQ, BNE, BLT, BGE, BLTU, BGEU: case (instr.instr_part)
                0: return {48'b0, instr.pc[15:0]} + instr.immediate;
                1: return {{32'b0, instr.pc[31:16]} + instr.immediate + state[16], state[15:0] };
                2: return {{16'b0, instr.pc[47:32]} + instr.immediate + state[32], state[31:0] };
                3: return {instr.pc[63:48] + instr.immediate + state[48], state[47:0] };
            endcase
            JALR: case (instr.instr_part)
                0: return ({48'b0, rs1_value} + instr.immediate) & 64'h_ff_ff_ff_ff_ff_ff_ff_fe; // set LSB to 0
                1: return {{32'b0, rs1_value} + instr.immediate + state[16], state[15:0]} ; // set LSB to 0
                2: return {{16'b0, rs1_value} + instr.immediate + state[32], state[31:0]} ; // set LSB to 0
                3: return {rs1_value + instr.immediate + state[48], state[47:0]} ; // set LSB to 0
            endcase
            FENCE_I: return instr.pc + 4;
`ifdef MACHINE_MODE
            MRET:    return mepc;  // return from interrupt handler
`endif
            default: return 'x;
        endcase
    endfunction


    // === Memory Access functions =============================================

    function automatic logic [15:0] load_shift_mask_extend(logic [1:0] part, 
                                                    mem_width_t width, 
                                                    logic is_unsigned, 
                                                    logic [15:0] value, 
                                                    logic word_offset, 
                                                    logic carry);
        logic [15:0] masked_value = load_mask(width, value, word_offset);
        unique case (width)
            B: return part != 0 ? {16{(~is_unsigned) && carry}} : 
                    (is_unsigned
                        ? {24'b0, masked_value[7:0]}
                        : {{24{masked_value[7]}}, masked_value[7:0]});
            H: return part != 0 ? {16{(~is_unsigned) && carry}} : value;
            W: return part > 1 ? {16{(~is_unsigned) && carry}} : value;
            D: return value;
            default: return 'x;
        endcase
    endfunction

    function automatic logic [15:0] load_mask(mem_width_t width, logic [15:0] value, logic word_offset);
        unique case (width)
            B: return (value >> word_offset*8) & 16'h_00_ff;
            default: return 'x;
        endcase
    endfunction



    // === CSR functions =======================================================
    
    function automatic logic [15:0] read_csr_part(csr_t csr_addr, logic [1:0] part);
        logic [63:0] workingResult = read_csr(csr_addr);

        case (part)
            0 : return workingResult[15:0]; 
            1 : return workingResult[31:16]; 
            2 : return workingResult[47:32]; 
            3 : return workingResult[63:48]; 
        endcase
    endfunction

    function automatic logic [63:0] read_csr(csr_t csr_addr);
        case (csr_addr)
`ifdef MACHINE_MODE
            MVENDORID, MARCHID, MIMPID, MHARTID, MEDELEG, MIDELEG: return '0;
            MISA:      return 32'b01000000_00000000_00000001_00000000;
            MTVEC:     return {mtvec[31:2], 2'b0}; // must be aligned on a 4-byte boundary
            MSTATUS:   return {19'b0, 2'b11, 3'b0, mstatus.mpie, 3'b0, mstatus.mie, 3'b0};
            MIP:       return {20'b0, mip.meip, 3'b0, mip.mtip, 3'b0, mip.msip, 3'b0};
            MIE:       return {20'b0, mie.meie, 3'b0, mie.mtie, 3'b0, mie.msie, 3'b0};
            MSCRATCH:  return mscratch;
            MEPC:      return {mepc[31:2], 2'b0}; // must be aligned on a 4-byte boundary
            MCAUSE:    return {mcause[31], 27'b0, mcause[3:0]};
            MBADADDR:  return mbadaddr;
            DSCRATCH, DOUTHEX, DOUTCHAR, DOUTINT:  return dscratch;
            MINSTRET:  return instret[31:0];
            MINSTRETH: return instret[63:32];
            MTIMECMP:  return timecmp[31:0];
            MTIMECMPH: return timecmp[63:32];
            // since we have a fixed frequency, we can say time = cycle count.
            MCYCLE,  MTIME:  return cycles[31:0];
            MCYCLEH, MTIMEH: return cycles[63:32];
`endif
            CYCLE,  TIME:  return cycles[31:0];
            CYCLEH, TIMEH: return cycles[63:32];
            default:   return 'x;
        endcase
    endfunction

`ifdef MACHINE_MODE
        
    `define write_csr(operation, part, value, csr) \
        case (operation)                     \
            CSRRW: case (part) \
                0: csr[15:0] <= value; \
                1: csr[31:16] <= value; \
                2: csr[47:32] <= value; \
                3: csr[63:48] <= value; \
            endcase\
            CSRRS: case (part) \
                0: csr[15:0] <= csr[15:0] | value; \
                1: csr[31:16] <= csr[31:16] | value; \
                2: csr[47:32] <= csr[47:32] | value; \
                3: csr[63:48] <= csr[63:48] | value; \
            endcase\
            CSRRC: case (part) \
                0: csr[15:0] <= csr[15:0] & ~value; \
                1: csr[31:16] <= csr[31:16] & ~value; \
                2: csr[47:32] <= csr[47:32] & ~value; \
                3: csr[63:48] <= csr[63:48] & ~value; \
            endcase\
        endcase

    task automatic execute_csr(instr_t instr, logic [15:0] rs1_value);
        // for immediate versions of the CSR instructions, the rs1 field contains a 5-bit immediate.
        logic[15:0] value = instr.immediate_used ? instr.rs1 : rs1_value;
        logic[11:0] csr_addr = instr.funct12;
        case (csr_addr)
            MTVEC:     `write_csr(instr.op, instr.instr_part, value, mtvec)
            MSTATUS:   `write_csr(instr.op, instr.instr_part, value, mstatus)
            MIE:       `write_csr(instr.op, instr.instr_part, value, mie)
            MSCRATCH:  `write_csr(instr.op, instr.instr_part, value, mscratch)
            MEPC:      `write_csr(instr.op, instr.instr_part, value, mepc)
            MCAUSE:    `write_csr(instr.op, instr.instr_part, value, mcause)
            MBADADDR:  `write_csr(instr.op, instr.instr_part, value, mbadaddr)
            MTIMECMP:  `write_csr(instr.op, instr.instr_part, value, timecmp)
            DSCRATCH,DOUTHEX,DOUTCHAR,DOUTINT:  `write_csr(instr.op, instr.instr_part, value, dscratch)
        endcase
    endtask


    // == Exception functions =======================================================

    function automatic mcause_t get_trap_cause();
        // we return a struct containing a bit indicating whether to trap, then the cause.
        if (mstatus.mie) begin
            if (mip.meip && mie.meie) return MEI;
            if (mip.msip && mie.msie) return MSI;
            if (mip.mtip && mie.mtie) return MTI;
        end

        if (pc[63:INSTR_ADDR_WIDTH+2] != '0)
            return INSTR_FAULT;
        if (!is_aligned(pc[1:0], W))
            return INSTR_MISALIGN;

        unique case (de_ex_instr.op)
            INVALID: return ILLEGAL_INSTR;
            LOAD:
                if (ex_address_high_bits != '0)
                    return LOAD_FAULT;
                else if (!is_aligned(ex_word_offset, de_ex_instr.memory_width))
                    return LOAD_MISALIGN;
            STORE:
                if (ex_address_high_bits != '0)
                    return STORE_FAULT;
                else if (!is_aligned(ex_word_offset, de_ex_instr.memory_width))
                    return STORE_MISALIGN;

            ECALL:  return ECALL_M;
            EBREAK: return BREAK;
            default: ;
        endcase

        return mcause_t'('x);
    endfunction


    function automatic logic is_aligned(logic [1:0] word_offset, mem_width_t width);
        unique case (width)
            W: return word_offset == '0;
            H: return word_offset[0] == '0;
            default: return '1;
        endcase
    endfunction
`endif

    // === Simluation and Debugging ============================================

    // debug output from the MA stage
    always_comb begin
        debug_scratch = dscratch;
        debug_pc = ex_ma_instr.pc;
    end

`ifdef SIMULATION
`include "clarvi_debug.sv"
`endif

endmodule
