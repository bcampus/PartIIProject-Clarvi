`ifndef RISCV_SVH
`include "riscv.svh"
`endif

module clarvi_ALU (
    input logic clock,
    input logic reset,
    input logic stall,
    input instr_t instr,
    input logic [ 7:0] rs1_value,
    input logic [ 7:0] rs2_value,
    output logic [ 7:0] result );

    logic [55:0] ex_state, ex_next_state;
    always_comb begin
        {ex_next_state, result} = execute(instr, rs1_value, rs2_value, ex_state);
    end

    always_ff @(posedge clock)
        if (!reset && !stall) begin
            ex_state            <= ex_next_state;
        end

    function automatic logic [63:0] execute(instr_t instr, logic [7:0] rs1_value, logic [7:0] rs2_value, logic [55:0] state);

        logic [7:0] rs2_value_or_imm = instr.immediate_used ? instr.immediate : rs2_value;

        // implement both logical and arithmetic as an arithmetic right shift, with a 33rd bit set to 0 or 1 as required.
        // logic signed [32:0] rshift_operand = {(instr.funct7_bit & rs1_value[31]), rs1_value};

        // shifts use the lower 5 bits of the intermediate or rs2 value
        logic [5:0] shift_amount = rs2_value_or_imm[5:0];
        logic [63:0] working_result; //to allow us to rearrange bits of result

        if (instr.is32_bit_op && instr.instr_part > 3 ) return {9{state[0]}}; //Sign-ext 32-bit ops
        else begin
            unique case (instr.op)
                ADD,SUB: begin
                        working_result = {56'b0, rs1_value} 
                            + {56'b0, instr.op == SUB ? ~rs2_value_or_imm : rs2_value_or_imm} 
                            + (instr.instr_part == 0 ? instr.op == SUB : state[0]); 

                        return { 55'b0, 
                            (instr.is32_bit_op && instr.instr_part == 3) ? working_result[7] : working_result[8],
                            working_result[7:0] }; 
                    end
                // SLT is a reverse instruction, result of comparison on the lower
                // bits is dependant on the result of a comparison on the upper bits
                SLT: case (instr.instr_part)
                        3'b000: return state[0] || (state[1] && (rs1_value < rs2_value_or_imm)); 
                        3'b111: return {rs1_value == rs2_value, $signed(rs1_value) < $signed(rs2_value_or_imm), 8'b0};
                        //Propagates previous result if == (state[1]) not set, else recalculates == and <
                        default: return {state[1] && rs1_value == rs2_value, 
                            (!state[1] && state[0]) || (state[1] && (rs1_value < rs2_value)), 
                            8'b0};
                    endcase
                SLTU: case (instr.instr_part)
                        3'b000: return state[0] || (state[1] && (rs1_value < rs2_value_or_imm));
                        3'b111: return {rs1_value == rs2_value, rs1_value < rs2_value_or_imm, 8'b0};
                        //Propagates previous result if == (state[1]) not set, else recalculates == and <
                        default: return {state[1] && rs1_value == rs2_value, 
                            (!state[1] && state[0]) || (state[1] && rs1_value < rs2_value), 
                            8'b0};
                    endcase
                XOR:   return rs1_value ^ rs2_value_or_imm;
                OR:    return rs1_value | rs2_value_or_imm;
                AND:   return rs1_value & rs2_value_or_imm;
                SL:    if (instr.is32_bit_op) begin
                        case (instr.instr_part)
                            3'b011: begin
                                working_result = ({ 56'b0, rs1_value } << shift_amount) | {8'b0, state};
                                return {55'b0, working_result[7], working_result[7:0]};
                            end
                            default : return ({56'b0, rs1_value} << shift_amount) | {8'b0, (instr.instr_part != 0 ? state : 56'b0)};
                        endcase
                    end else
                        return ({56'b0, rs1_value} << shift_amount) | {8'b0, (instr.instr_part != 0 ? state : 56'b0)};
                SRL:   if (instr.is32_bit_op) begin //32-bit right shift is ordered with parts 3, 2, 1, 0, 7, 6, 5, 4
                    //since 32 bit does not need lower bits of state, use this
                    //to store sign ext.
                        case (instr.instr_part)
                            3'b011: begin
                                working_result = { rs1_value, 56'b0 } >> shift_amount;
                                //places sign ext. in bit 0 of state
                                return {working_result[55:1], working_result[63], working_result[63:56]};
                            end
                            default: begin
                                working_result = ({ rs1_value, 56'b0 } >> shift_amount) | {state, 8'b0};
                                //places sign ext. back in bit 0 of state
                                return {working_result[55:1], working_result[8], working_result[63:56]};
                            end
                        endcase
                        
                    end else begin
                        working_result = ({ rs1_value, 56'b0 } >> shift_amount) | {(instr.instr_part != 7 ? state : 56'b0), 8'b0};
                        return { working_result[55:0], working_result[63:56] };
                    end
                SRA:   if (instr.is32_bit_op) begin //32-bit right shift is ordered with parts 3, 2, 1, 0, 7, 6, 5, 4
                    //since 32 bit does not need lower bits of state, use this
                    //to store sign ext.
                        case (instr.instr_part)
                            3'b011: begin
                                working_result = $signed({ rs1_value, 56'b0 }) >>> shift_amount;
                                //places sign ext. in bit 0 of state
                                return {working_result[55:1], working_result[63], working_result[63:56]};
                            end
                            default: begin
                                working_result = ({ rs1_value, 56'b0 } >> shift_amount) | {state, 8'b0};
                                //places sign ext. back in bit 0 of state
                                return {working_result[55:1], working_result[8], working_result[63:56]};
                            end
                        endcase
                    end else begin
                        if (instr.instr_part == 3'b111) begin
                            working_result = $signed({ rs1_value, 56'b0 }) >>> shift_amount;
                            return { working_result[55:0], working_result[63:56] };
                        end else begin
                            working_result = ({ rs1_value, 56'b0 } >> shift_amount) |  { state, 8'b0 };
                            return { working_result[55:0], working_result[63:56] };
                        end
                    end
                LUI:   return instr.immediate;
                AUIPC: case (instr.instr_part)
                        3'b000 : return instr.immediate + instr.pc[7:0];
                        3'b001 : return instr.immediate + instr.pc[15:8] + state[0];
                        3'b010 : return instr.immediate + instr.pc[23:16] + state[0];
                        3'b011 : return instr.immediate + instr.pc[31:24] + state[0];
                        3'b100 : return instr.immediate + instr.pc[39:32] + state[0];
                        3'b101 : return instr.immediate + instr.pc[47:40] + state[0];
                        3'b110 : return instr.immediate + instr.pc[55:48] + state[0];
                        3'b111 : return instr.immediate + instr.pc[63:56] + state[0];
                    endcase
                // JAL(R) stores the address of the instruction that followed the jump
                JAL, JALR: 
                    begin
                        working_result = instr.pc + 4 ; 
                        case (instr.instr_part)
                            3'b000 : return working_result[7:0];
                            3'b001 : return working_result[15:8]; 
                            3'b010 : return working_result[23:16]; 
                            3'b011 : return working_result[31:24]; 
                            3'b100 : return working_result[39:32];
                            3'b101 : return working_result[47:40]; 
                            3'b110 : return working_result[55:48]; 
                            3'b111 : return working_result[63:56]; 
                        endcase
                    end
                default: return 'x;
            endcase
        end
    endfunction

endmodule
