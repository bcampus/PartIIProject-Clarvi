`include "riscv.svh"

module clarvi_ALU (
    input logic clock,
    input logic reset,
    input logic stall,
    input instr_t instr,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    output logic [31:0] result );

    logic [31:0] ex_state, ex_next_state;
    always_comb begin
        {ex_next_state, result} = execute(instr, rs1_value, rs2_value, ex_state);
    end

    always_ff @(posedge clock)
        if (!reset && !stall) begin
            ex_state            <= ex_next_state;
        end

    function automatic logic [63:0] execute(instr_t instr, logic [31:0] rs1_value, logic [31:0] rs2_value, logic [31:0] state);

        logic [31:0] rs2_value_or_imm = instr.immediate_used ? instr.immediate : rs2_value;

        // implement both logical and arithmetic as an arithmetic right shift, with a 33rd bit set to 0 or 1 as required.
        // logic signed [32:0] rshift_operand = {(instr.funct7_bit & rs1_value[31]), rs1_value};

        // shifts use the lower 5 bits of the intermediate or rs2 value
        logic [5:0] shift_amount = rs2_value_or_imm[5:0];
        logic [63:0] working_result; //to allow us to rearrange bits of result

        if (instr.instr_part == 1 && instr.is32_bit_op) return {32{state[0]}};
        else begin
            unique case (instr.op)
                ADD: if (instr.is32_bit_op) begin //Use bit 32 to propagate sign ext.
                        working_result = {32'b0, rs1_value} + {32'b0, rs2_value_or_imm};
                        return { 31'b0, working_result[31], working_result[31:0] }; //sets sign ext. bit
                    end
                    else return {32'b0, rs1_value} + {32'b0, rs2_value_or_imm} + (instr.instr_part != 0 && state[0]);
                SUB: if (instr.is32_bit_op) begin //Use bit 32 to propagate sign ext.
                        working_result = {32'b0, rs1_value} + {32'b0, ~rs2_value_or_imm} + 1;
                        return { 31'b0, working_result[31], working_result[31:0] }; //sets sign ext. bit
                    end
                    else return {32'b0, rs1_value} + {32'b0, ~rs2_value_or_imm} + (instr.instr_part == 0 || state[0]);
                // SLT is a reverse instruction, result of comparison on the lower
                // bits is dependant on the result of a comparison on the upper bits
                SLT:   case (instr.instr_part)
                        1'b0: return state[0] || (state[1] && ($signed(rs1_value) < $signed(rs2_value_or_imm))); 
                        1'b1: return {rs1_value == rs2_value, $signed(rs1_value) < $signed(rs2_value_or_imm), 32'b0};
                    endcase
                SLTU:  case (instr.instr_part)
                        1'b0: return state[0] || (state[1] && (rs1_value < rs2_value_or_imm));
                        1'b1: return {rs1_value == rs2_value, rs1_value < rs2_value_or_imm, 32'b0};
                    endcase
                XOR:   return rs1_value ^ rs2_value_or_imm;
                OR:    return rs1_value | rs2_value_or_imm;
                AND:   return rs1_value & rs2_value_or_imm;
                SL:    return ({32'b0, rs1_value} << shift_amount) | {32'b0, (instr.instr_part != 0 ? state : 32'b0)};
                SRL:   case (instr.instr_part)
                        1'b1: begin
                            working_result = { rs1_value, 32'b0 } >> shift_amount;
                            return { working_result[31:0], working_result[63:32] };
                        end
                        1'b0: begin
                            if (instr.is32_bit_op) begin
                                working_result = { 32'b0, rs1_value >> shift_amount };
                                return { 31'b0, working_result[31], working_result[31:0] }; //sets sign ext. bit
                            end
                            else return {32'b0, state | (rs1_value >> shift_amount) }; //combine with underflow from upper bits
                        end
                    endcase
                SRA:   case (instr.instr_part)
                        1'b1: begin
                            working_result = $signed({ rs1_value, 32'b0 }) >>> shift_amount ;
                            return { working_result[31:0], working_result[63:32] };
                        end
                        1'b0: begin
                            if (instr.is32_bit_op) begin
                                working_result = { 32'b0, $signed(rs1_value) >>> shift_amount };
                                return { 31'b0, working_result[31], working_result[31:0] }; //sets sign ext. bit
                            end
                            else return {32'b0, state | (rs1_value >> shift_amount) }; //combine with underflow from upper bits
                        end
                    endcase
                LUI:   return instr.immediate;
                AUIPC: case (instr.instr_part)
                        1'b0 : return instr.immediate + instr.pc[31:0];
                        1'b1 : return instr.immediate + instr.pc[63:32] + state[0];
                    endcase
                // JAL(R) stores the address of the instruction that followed the jump
                JAL, JALR: 
                    begin
                        working_result = instr.pc + 4 ; 
                        case (instr.instr_part)
                            1'b0 : return working_result[31:0];
                            1'b1 : return working_result[63:32]; 
                        endcase
                    end
                default: return 'x;
            endcase
        end
    endfunction

endmodule
