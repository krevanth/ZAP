`default_nettype none

/*
Filename --
zap_decode_thumb.v

HDL --
Verilog-2005

Description --
Performs Thumb to ARM conversion. Placed in series with ARM decode
since ARM decode is relatively simple.

Author --
Revanth Kamaraj.

License --
Released under the MIT License.
*/

module zap_decode_thumb
(
        // Clock and reset.
        input wire              i_clk,
        input wire              i_reset,

        // Input from I-cache.
        input wire [31:0]       i_instruction,
        input wire              i_instruction_valid,

        // Interrupts.
        input wire              i_irq,
        input wire              i_fiq,

        // Ensure Thumb mode is active.
        input wire [31:0]       i_cpsr_ff, // To ensure Thumb mode is active.

        // Output to the ARM decoder.
        output reg [34:0]       o_instruction,
        output reg              o_instruction_valid,
        output reg              o_und,

        // Interrupt outputs.
        output reg              o_irq,
        output reg              o_fiq
);

reg [11:0] offset_ff, offset_nxt;       // Remember offset.

`include "cc.vh"
`include "cpsr.vh"
`include "instruction_patterns.vh"

always @*
begin
        // If you are not in Thumb mode, just pass stuff on.
        o_instruction_valid     = i_instruction_valid;
        o_und                   = 0;
        o_instruction           = i_instruction;
        state_nxt               = state_ff;
        offset_nxt              = i_instruction[11:0];
        o_irq                   = i_irq;
        o_fiq                   = i_fiq;

        if ( i_cpsr_ff[T] && i_instruction_valid ) // Thumb mode.
        begin
                casez ( i_instruction[15:0] )
                        T_BRANCH_COND   : decode_conditional_branch; 
                        T_BRANCH_NOCOND : decode_unconditional_branch;
                        T_BL            : decode_bl;
                        T_BX            : decode_bx;
                        T_SWI           : decode_swi;
                        T_SHIFT         : decode_shift;
                        T_ADD_SUB_LO    : decode_add_sub_lo; 
                        T_MCAS_IMM      : decode_mcas_imm;    // MOV,CMP,ADD,SUB IMM.
                        T_ALU_LO        : decode_alu_lo;
                        default:
                        begin
                                $display($time, "%m: Not implemented!");
                                o_und = 1;
                        end
                endcase 
        end
end

task decode_alu_lo;
begin: tskDecAluLo
        reg [3:0] op;
        reg [3:0] rs, rd;
        reg [3:0] rn;

        op = i_instruction[9:6];
        rs = i_instruction[5:3];
        rd = i_instruction[2:0];

        o_instruction = 0;

        case(op)
                0:      o_instruction[31:0] = {AL, 2'b00, 1'b0, AND, 1'd1, rd, rd, 8'd0, rs};                   // ANDS Rd, Rd, Rs
                1:      o_instruction[31:0] = {AL, 2'b00, 1'b0, EOR, 1'd1, rd, rd, 8'd0, rs};                   // EORS Rd, Rd, Rs
                2:      o_instruction[31:0] = {AL, 2'b00, 1'b0, MOV, 1'd1, rd, rd, rs, 1'd0, LSL, 1'd1, rd};    // MOVS Rd, Rd, LSL Rs
                3:      o_instruction[31:0] = {AL, 2'b00, 1'b0, MOV, 1'd1, rd, rd, rs, 1'd0, LSR, 1'd1, rd};    // MOVS Rd, Rd, LSR Rs
                4:      o_instruction[31:0] = {AL, 2'b00, 1'b0, MOV, 1'd1, rd, rd, rs, 1'd0, ASR, 1'd1, rd};    // MOVS Rd, Rd, ASR Rs
                5:      o_instruction[31:0] = {AL, 2'b00, 1'b0, ADC, 1'd1, rd, rd, 8'd0, rs};                   // ADCS Rd, Rd, Rs
                6:      o_instruction[31:0] = {AL, 2'b00, 1'b0, SBC, 1'd1, rd, rd, 8'd0, rs};                   // SBCS Rd, Rs, Rs        
                7:      o_instruction[31:0] = {AL, 2'b00, 1'b0, MOV, 1'd1, rd, rd, rs, 1'd0, ROR, 1'd1, rd};    // MOVS Rd, Rd, ROR Rs.
                8:      o_instruction[31:0] = {AL, 2'b00, 1'b0, TST, 1'd1, rd, rd, 8'd0, rs};                   // TST Rd, Rs
                9:      o_instruction[31:0] = {AL, 2'b00, 1'b1, RSB, 1'd1, rs, rd, 12'd0};                      // Rd = 0 - Rs
                10:     o_instruction[31:0] = {AL, 2'b00, 1'b1, CMP, 1'd1, rd, rd, 8'd0, rs};                   // CMP Rd, Rs
                11:     o_instruction[31:0] = {AL, 2'b00, 1'b1, CMN, 1'd1, rd, rd, 8'd0, rs};                   // CMN Rd, Rs
                12:     o_instruction[31:0] = {AL, 2'b00, 1'b1, ORR,  
                13:
                14:
                15:
        endcase
end
endtask

task decode_mcas_imm;
begin: tskDecodeMcasImm
        reg [1:0]  op;
        reg [3:0]  rd;
        reg [11:0] imm;

        o_instruction = 0;

        op = i_instruction[12:11];
        rd = i_instruction[10:8];
        imm =i_instruction[7:0];

        case (op)
                0:
                begin
                        // MOV Rd, Offset8
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, MOV, 1'd1, rn, rd, imm};  
                end
                1:
                begin
                        // CMP Rd, Offset8
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, CMP, 1'd1, rn, rd, imm};  
                end
                2:
                begin
                        // ADDS Rd, Rd, Offset8
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, ADD, 1'd1, rn, rd, imm};  
                end
                3:
                begin
                        // SUBS Rd, Rd, Offset8
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, SUB, 1'd1, rn, rd, imm};  
                end
        endcase
end
endtask

task decode_add_sub_lo;
begin: tskDecodeAddSubLo
        o_instruction = 0;

        reg [3:0] rn, rd, rs;
        reg [11:0] imm;

        rn = i_instruction[8:6];
        rd = i_instruction[2:0];
        rs = i_instruction[5:3];
        imm = rn;

        case({i_instruction[9], i_instruction[10]})
        0:
        begin
                // Add Rd, Rs, Rn - Instr spec shift.
                o_instruction[31:0] = {AL, 2'b00, 1'b0, ADD, 1'd1, rs, rd, 8'd0, rn};  
        end
        1:
        begin
                // Adds Rd, Rs, #Offset3 - Immediate.
                o_instruction[31:0] = {AL, 2'b00, 1'b1, ADD, 1'd1, rn, rd, imm};  
        end
        2:
        begin
                // SUBS Rd, Rs, Rn - Instr spec shift.
                o_instruction[31:0] = {AL, 2'b00, 1'b0, SUB, 1'd1, rs, rd, 8'd0, rn}; 
        end
        3:
        begin
                // SUBS Rd, Rs, #Offset3 - Immediate.
                o_instruction[31:0] = {AL, 2'b00, 1'b1, SUB, 1'd1, rn, rd, imm}; 
        end
        endcase
end
endtask

task decode_conditional_branch;
begin
        // An MSB of 1 indicates a left shift of 1.
        o_instruction           = {1'd1, 2'b0, AL, 3'b101, 1'b0, 24'd0}; 
        o_instruction[23:0]     = $signed(i_instruction[7:0]); 
end        
endtask

task decode_unconditional_branch;
begin
        // An MSB of 1 indicates a left shift of 1.
        o_instruction           = {1'd1, 2'b0, AL, 3'b101, 1'b0, 24'd0}; 
        o_instruction[23:0]     = $signed(i_instruction[10:0]);        
end
endtask

task decode_bl;
begin
        case ( i_instruction[11] )
                1'd0:
                begin
                        // Store the offset and send out a dummy instruction.
                        offset_nxt      = i_instruction[11:0];
                        o_instruction   = 32'd0;
                        o_irq           = 1'd0;
                        o_fiq           = 1'd0;
                end
                1'd1:
                begin
                        // Generate a full jump.
                        o_instruction = {1'd1, 2'b0, AL, 3'b101, 1'b1, 24'd0};
                        o_instruction[23:0] = ($signed(offset_nxt) << 12) | (offset_ff); 
                        o_irq           = 1'd0;
                        o_fiq           = 1'd0;
                end
        endcase
end
endtask

task decode_bx;
begin
        // Generate a BX Rm.
        o_instruction = 32'b0000_0001_0010_1111_1111_1111_0001_0000;
        o_instruction[31:28] = AL;
        o_instruction[3:0]   = i_instruction[6:3];
end
endtask

task decode_swi;
begin
        // Generate a SWI.
        o_instruction = 32'b0000_1111_0000_0000_0000_0000_0000_0000;
        o_instruction[31:28] = AL;
        o_instruction[7:0]   = i_instruction[7:0]; 
end
endtask

task decode_shift;
begin
        // Thumb shift instructions. Decompress to ARM with instruction specified shift.
        o_instruction           = 32'd0;                // Extension -> 0.
        o_instruction[31:28]    = AL;                   // Always execute.
        o_instruction[27:26]    = 2'b00;                // Data processing.
        o_instruction[25]       = 1'd0;                 // Immediate is ZERO.
        o_instruction[24:21]    = MOV;                  // Operation is MOV.
        o_instruction[20]       = 1'd1;                 // Do update flags.
        o_instruction[19:16]    = 4'd0;                 // ALU source. Doesn't matter.
        o_instruction[15:12]    = i_instruction[2:0] ;  // Destination. 
        o_instruction[11:7]     = i_instruction[10:6];  // Shamt.
        o_instruction[6:5]      = i_instruction[12:11]; // Shtype.
        o_instruction[3:0]      = i_instruction[5:3];   // Shifter source.
end
endtask

endmodule
