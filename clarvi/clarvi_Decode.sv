`ifndef RISCV_SVH
`include "riscv.svh"
`endif

`define MACHINE_MODE

module clarvi_Decode (
    input logic clock,
    input logic [31:0] in_instr,
    input logic [63:0] if_de_pc,
    input logic stage_invalid,
    input logic stall_stage,

    //Register File Inputs
    input logic [31:0] rs1_fetched,
    input logic [31:0] rs2_fetched,

    //Later Stage Inputs
    input logic ex_invalid,
    input logic ma_invalid,
    input logic wb_invalid,
    input instr_t de_ex_instr,
    input instr_t ex_ma_instr,
    input instr_t ma_wb_instr,
    input logic mem_address_error,

    //Memory inputs
    input logic instr_wait,
    input logic instr_read_enable,
    input logic main_wait,
    input logic main_read_enable,
    input logic main_write_enable,
    input logic main_read_pending,
    input logic main_read_data_buffer_valid,
    input logic main_read_data_valid,
    
    //Forwarding Inputs
    input logic [31:0] wb_forward_value,
    input logic [31:0] ma_forward_value,
    input logic [31:0] ex_forward_value,

    output instr_t decoded_instr,
    output logic [31:0] rs1_value,
    output logic [31:0] rs2_value,
    output logic stall_for_load_dep,
    output logic stall_for_memory_wait,
    output logic stall_for_memory_pending,
    output logic stall_for_decode
);

    logic [31:0] rs1_forward, rs2_forward; // forwarding logic appears later
    logic instr_part = 0;

    assign rs1_value = rs1_forward;
    assign rs2_value = rs2_forward;

    always_comb begin
        decoded_instr = decode_instr(in_instr, if_de_pc, instr_part);

        // if the next instruction is a load and this instruction is dependent on its result,
        // stall for one cycle since the result won't be ready yet - unless the load raises an exception.
        stall_for_load_dep = !stage_invalid && !ex_invalid && de_ex_instr.memory_read && !mem_address_error 
                          && (decoded_instr.rs1 == de_ex_instr.rd && decoded_instr.rs1_used
                           || decoded_instr.rs2 == de_ex_instr.rd && decoded_instr.rs2_used)
                          && decoded_instr.instr_part == 0;

        // ignore waitrequest unless we are actually reading/writing memory,
        // because the bus is allowed to hold waitrequest high while idle.
        stall_for_memory_wait = (instr_wait && instr_read_enable)
                                || (main_wait && (main_read_enable || main_write_enable));
                                
        stall_for_memory_pending = main_read_pending && !main_read_data_buffer_valid && !main_read_data_valid;

        stall_for_decode = !stage_invalid && instr_part != 1;
    end

    always_ff @(posedge clock) begin
        if (!stall_stage) begin
            instr_part <= !stage_invalid ? instr_part + 1 : 0;
        end
    end

    // === Forwarding ==========================================================

    logic could_forward_from_ex, could_forward_from_ma, could_forward_from_wb;
    value_source_t rs1_source, rs2_source;

    always_comb begin
        // check if stages are eligible to have their values forwarded
        // forward from EX result: instruction must not be a load since result won't be ready until end of MA stage
        could_forward_from_ex = !ex_invalid && de_ex_instr.enable_wb && !de_ex_instr.memory_read;
        could_forward_from_ma = !ma_invalid && ex_ma_instr.enable_wb;
        could_forward_from_wb = !wb_invalid && ma_wb_instr.enable_wb;

        // now we also check whether source and destination registers match up
        // prioritise forwarding from earlier stages (more recent instructions),
        // since these may overwrite values written by later stages (less recent instructions).
        // Also check current part of the instruction in decode stage
        // corellates to the part we are forwarding from.
        rs1_source = get_value_source(decoded_instr.rs1, decoded_instr.instr_part);
        rs2_source = get_value_source(decoded_instr.rs2, decoded_instr.instr_part);

        unique case (rs1_source)
            REGISTER_FILE:  rs1_forward = rs1_fetched;
            WRITE_BACK:     rs1_forward = wb_forward_value; 
            MEMORY_ACCESS:  rs1_forward = ma_forward_value;
            EXECUTE:        rs1_forward = ex_forward_value;
        endcase

        unique case (rs2_source)
            REGISTER_FILE:  rs2_forward = rs2_fetched;
            WRITE_BACK:     rs2_forward = wb_forward_value; 
            MEMORY_ACCESS:  rs2_forward = ma_forward_value;
            EXECUTE:        rs2_forward = ex_forward_value;
        endcase
    end

    function automatic value_source_t get_value_source(register_t reg_src, logic instr_part);
        if      (could_forward_from_ex && de_ex_instr.rd == reg_src && de_ex_instr.instr_part == instr_part) return EXECUTE;
        else if (could_forward_from_ma && ex_ma_instr.rd == reg_src && ex_ma_instr.instr_part == instr_part) return MEMORY_ACCESS;
        else if (could_forward_from_wb && ma_wb_instr.rd == reg_src && ma_wb_instr.instr_part == instr_part) return WRITE_BACK;
        else                                                              return REGISTER_FILE;
    endfunction
    
    // === Decode functions ====================================================

    function automatic instr_t decode_instr(logic [31:0] instr, logic [63:0] pc, logic instr_part);
        // registers, funct7 and funct3 are in the same place in every instruction type
        decode_instr.rd  = register_t'(instr`rd);
        decode_instr.rs1 = register_t'(instr`rs1);
        decode_instr.rs2 = register_t'(instr`rs2);
        decode_instr.funct12 = funct12_t'(instr`funct12);

        decode_instr.op = decode_opcode(instr);
        decode_instr.is32_bit_op = instr`opcode == OPC_OP_32 
                                || instr`opcode == OPC_OP_IMM_32;

        // we check whether a register is used for forwarding purposes -- no need to forward the zero register
        decode_instr.rs1_used = decode_instr.rs1 != zero
                             && instr`opcode != OPC_LUI
                             && instr`opcode != OPC_AUIPC
                             && instr`opcode != OPC_JAL
                             && instr`opcode != OPC_MISC_MEM;

        decode_instr.rs2_used = decode_instr.rs2 != zero
                             && (instr`opcode == OPC_BRANCH
                              || instr`opcode == OPC_STORE
                              || instr`opcode == OPC_OP
                              || instr`opcode == OPC_OP_32);

        //Following instructions require going down the pipeline in reverse
        //order
        decode_instr.instr_part = (decode_instr.op == SRL && !decode_instr.is32_bit_op
                                || decode_instr.op == SRA && !decode_instr.is32_bit_op
                                || decode_instr.op == SLT
                                || decode_instr.op == SLTU) ? ~instr_part
                                                            :  instr_part;

        {decode_instr.immediate_used, decode_instr.immediate} = decode_immediate(instr, decode_instr.instr_part);

        decode_instr.memory_write = instr`opcode == OPC_STORE;
        decode_instr.memory_read  = instr`opcode == OPC_LOAD;
        decode_instr.memory_read_unsigned = instr[14];  // if memory_read is true, this indicates an unsigned read.
        decode_instr.memory_width = mem_width_t'(instr[13:12]);

        // write back for all except s-type instructions and not to register 0
        decode_instr.enable_wb = decode_instr.rd != '0
                              && instr`opcode != OPC_BRANCH
                              && instr`opcode != OPC_STORE;

        decode_instr.pc = pc;
    endfunction


    function automatic operation_t decode_opcode(logic [31:0] instr);
        logic [11:0] funct12 = instr`funct12;
        logic [2:0]  funct3  = instr`funct3;
        logic [4:0]  rs1 = instr`rs1;
        logic legal_csr_op = validate_csr_op(rs1 != zero, csr_t'(funct12));

        // ensure the two LSBs are 1
        if (instr[1:0] != 2'b11)
            return INVALID;

        unique case (instr`opcode)
            OPC_LUI:   return LUI;
            OPC_AUIPC: return AUIPC;
            OPC_JAL:   return JAL;
            OPC_JALR:  return JALR;
            OPC_BRANCH:
                unique case (funct3)
                    F3_BEQ:  return BEQ;
                    F3_BNE:  return BNE;
                    F3_BLT:  return BLT;
                    F3_BLTU: return BLTU;
                    F3_BGE:  return BGE;
                    F3_BGEU: return BGEU;
                endcase
            OPC_LOAD:  return LOAD;
            OPC_STORE: return STORE;
            OPC_OP_32, OPC_OP_IMM_32:
                unique case (funct3)
                    // there is no SUBI instruction so also check opcode
                    F3_ADDSUB: return instr[5] && funct12[10] ? SUB : ADD;
                    F3_SLL:  return funct12[5] ? INVALID : SL;
                    F3_SR:   return funct12[5] ? INVALID : (funct12[10] ? SRA : SRL);
                    default: return INVALID;
                endcase
            OPC_OP, OPC_OP_IMM:
                unique case (funct3)
                    // there is no SUBI instruction so also check opcode
                    F3_ADDSUB: return instr[5] && funct12[10] ? SUB : ADD;
                    F3_SLT:  return SLT;
                    F3_SLTU: return SLTU;
                    F3_XOR:  return XOR;
                    F3_OR:   return OR;
                    F3_AND:  return AND;
                    F3_SLL:  return SL;
                    F3_SR:   return funct12[10] ? SRA : SRL;
                    default: return INVALID;
                endcase
            OPC_MISC_MEM: return funct3[0] ? FENCE_I : FENCE;
            OPC_SYSTEM:
                unique case (funct3[1:0])
                    // when rs1 is zero we are not writing to the CSR. This is used when checking for
                    // an illegal write to a read-only CSR.
                    F2_CSRRW: return legal_csr_op ? CSRRW : INVALID;
                    F2_CSRRS: return legal_csr_op ? CSRRS : INVALID;
                    F2_CSRRC: return legal_csr_op ? CSRRC : INVALID;
                    F2_PRIV:
                        unique case (funct12)
                            F12_ECALL:  return ECALL;
                            F12_EBREAK: return EBREAK;
`ifdef MACHINE_MODE
                            F12_MRET:   return MRET;
                            F12_WFI:    return WFI;
`endif
                            default:    return INVALID;
                        endcase
                endcase
            default: return INVALID;
        endcase
    endfunction

    function automatic logic [32:0] decode_immediate(logic [31:0] instr, logic instr_part);
        // returns an extra top bit to indicate whether the immediate is used
        // all except u-type instructions have sign-extended immediates.
        logic [19:0] sign_ext_20 = {20{instr[31]}};
        logic [11:0] sign_ext_12 = {12{instr[31]}};
        logic [31:0] sign_ext_32 = {32{instr[31]}};
        logic upper = instr_part == 1;
        unique case (instr`opcode)
            OPC_JALR, OPC_LOAD:
                return {1'b1, upper ? sign_ext_32 : {sign_ext_20, instr[31:20]}};
            OPC_OP_IMM, OPC_OP_IMM_32: // i-type
                unique case (instr`funct3)
                    F3_SLL,F3_SR:
                        return {1'b1,{sign_ext_20, instr[31:20]}};
                    default:
                        return {1'b1, upper ? sign_ext_32 : {sign_ext_20, instr[31:20]}};
                endcase
            OPC_STORE: // s-type
                return {1'b1, upper ? sign_ext_32 : {sign_ext_20, instr[31:25], instr[11:7]}};
            OPC_BRANCH: // sb-type
                return {1'b1, upper ? sign_ext_32 : {sign_ext_20, instr[7], instr[30:25], instr[11:8], 1'b0}};
            OPC_JAL: // uj-type
                return {1'b1, upper ? sign_ext_32 : {sign_ext_12, instr[19:12], instr[20], instr[30:21], 1'b0}};
            OPC_LUI, OPC_AUIPC: // u-type
                return {1'b1, upper ? sign_ext_32 : {instr[31:12], 12'b0}};
            OPC_SYSTEM: // no ordinary immediate but possibly a csr zimm (5-bit immediate)
                return {instr[14], 32'bx};
            default: // no immediate
                return {1'b0, 32'bx};
        endcase

    endfunction

    function automatic logic validate_csr_op(logic write, csr_t csr);
        // first check we aren't writing to a read-only CSR
        if (write && csr[11:10] == 2'b11)
            return '0;
        unique case (csr)
`ifdef MACHINE_MODE
            // all the CSRs we support in machine mode...
            MVENDORID, MARCHID, MIMPID, MHARTID, MEDELEG, MIDELEG,
            MISA, MTVEC, MSTATUS, MIP, MIE, MSCRATCH, MEPC, MCAUSE, MBADADDR, DSCRATCH,
            MCYCLE, MTIME, MINSTRET, MCYCLEH, MTIMEH, MINSTRETH, MTIMECMP, MTIMECMPH,
            DOUTHEX,DOUTCHAR,DOUTINT,
`endif
            // in user-mode only timer CSRs can be read
            CYCLE, TIME, CYCLEH, TIMEH:
                     return '1;
            default: return '0;
        endcase

    endfunction


endmodule




