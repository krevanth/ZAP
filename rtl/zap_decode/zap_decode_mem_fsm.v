`default_nettype none
/*
 Filename --
 zap_decode_mem_fsm.v

 HDL --
 Verilog-2005

 Description --
 This module sequences ARM LDM/STM CISC instructions into simpler RISC
 instructions. Basically LDM -> LDRs and STM -> STRs. Supports a base restored
 abort model.

 Dependencies --
 None

 Author --
 Revanth Kamaraj 
*/

module zap_decode_mem_fsm
(
        // Clock and reset.
        input wire              i_clk,                  // ZAP clock.
        input wire              i_reset,                // ZAP reset.

        // Instruction information from the fetch.
        input wire  [31:0]      i_instruction,
        input wire              i_instruction_valid,

        // Interrupt information from the fetch.
        input wire              i_irq,
        input wire              i_fiq,

        // Pipeline control signals.
        input wire              i_clear_from_writeback,
        input wire              i_data_stall,
        input wire              i_clear_from_alu,
        input wire              i_issue_stall,

        output reg [34:0]       o_instruction,
        output reg              o_instruction_valid,
        output reg              o_stall_from_decode,// Inputs to this module must not  change
                                                    // if this is seen as 1. The interrupt 
                                                    // sequencer may choose not to override this
                                                    // since it too monitors the input instruction.
                                                    // LDMs and STMs may be interrupted. Others
                                                    // cannot.

        // Possibly masked interrupts.
        output reg              o_irq,
        output reg              o_fiq
);

`include "fields.vh"
`include "opcodes.vh"
`include "regs.vh"

// Instruction breakup
// These assignments are repeated in the function.
wire [3:0] base    = i_instruction[`BASE];
wire [3:0] srcdest = i_instruction[`SRCDEST];
wire [3:0] cc      = i_instruction[31:28];
wire [2:0] id      = i_instruction[27:25];
wire pre_index     = i_instruction[24];
wire up            = i_instruction[23];
wire s_bit         = i_instruction[22];
wire writeback     = i_instruction[21];
wire load          = i_instruction[20];
wire store         = !load;
wire [15:0] reglist= i_instruction[15:0];
wire link          = i_instruction[24];
wire [11:0] branch_offset = i_instruction[11:0];

// States.
localparam IDLE         = 0;
localparam MEMOP        = 1;
localparam WRITE_PC     = 2;

// Registers.
reg     [2:0]   state_ff, state_nxt;
reg     [15:0]  reglist_ff, reglist_nxt;

// Next state and output logic.
always @*
begin
        case ( state_ff )
                IDLE:
                begin
                        if ( id == 3'b100 && i_instruction_valid )
                        begin
                                // Backup base register.
                                // MOV DUMMY0, Base

                                o_instruction = {cc, 2'b00, 1'b0, MOV, 1'b0, 4'd0, 4'd0, 8'd0, base};
                                {o_instruction[`DP_RD_EXTEND], o_instruction[`DP_RD]} = ARCH_DUMMY_REG0;

                                o_instruction_valid = 1'd1;
                                reglist_nxt = reglist;
                              
                                state_nxt = MEMOP;  
                                o_stall_from_decode = 1'd1; 

                                o_irq = 0;
                                o_fiq = 0;
                        end
                        else
                        begin
                                // Be transparent.
                                state_nxt = state_ff;
                                o_stall_from_decode = 1'd0;
                                o_instruction = i_instruction;
                                o_instruction_valid = i_instruction_valid;
                                reglist_nxt = 16'd0;

                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                end

                MEMOP:
                begin: mem_op_blk_1

                        // Memory operations happen here.

                        reg [3:0] pri_enc_out;


                        pri_enc_out = pri_enc(reglist_ff);
                        reglist_nxt = reglist_ff & ~(1 << pri_enc_out); 

                        // The map function generates a base restore instruction if reglist = 0.
                        o_instruction = map ( i_instruction, pri_enc_out, reglist_ff );
                        o_instruction_valid = 1'd1;

                        if ( reglist_ff == 0 )
                        begin
                                if ( i_instruction[ARCH_PC] && load )
                                begin
                                        o_stall_from_decode     = 1'd1;
                                        state_nxt               = WRITE_PC;
                                end
                                else
                                begin   
                                        o_stall_from_decode     = 1'd0;       
                                        state_nxt               = IDLE;
                                end 
                        end
                        else
                        begin
                                state_nxt = MEMOP;
                                o_stall_from_decode = 1'd1;
                        end
                end

                // If needed, we finally write to the program counter.
                WRITE_PC:
                begin
                        state_nxt = IDLE;
                        o_stall_from_decode = 1'd0;      
                        o_instruction = { cc, 2'b00, 1'd0, MOV, s_bit, 4'd0, ARCH_PC, 8'd0, 4'd0 };
                        {o_instruction[`DP_RS_EXTEND], o_instruction[`DP_RS]} = ARCH_DUMMY_REG1; 
                        o_instruction_valid = 1'd1;                 
                end
        endcase
end

function [33:0] map ( input [31:0] instr, input [3:0] enc, input [15:0] list );
// These override the globals within the function scope.
reg [3:0] base;    
reg [3:0] srcdest; 
reg [3:0] cc;      
reg [2:0] id;      
reg pre_index;     
reg up;            
reg s_bit;         
reg writeback;     
reg load;          
reg store;         
reg [15:0] reglist;
begin
        // All variables used inside the function depend solely on the input args.
                
        base            = instr[`BASE];
        srcdest         = instr[`SRCDEST];
        cc              = instr[31:28];
        id              = instr[27:25];
        pre_index       = instr[24];
        up              = instr[23];
        s_bit           = instr[22];
        writeback       = instr[21];
        load            = instr[20];
        store           = !load;
        reglist         = instr[15:0];

        map = instr;
        map = map & ~(1<<22); // No byte access.
        map = map & ~(1<<25); // Constant Offset (of 4).
        map[11:0] = 12'd4;
        map[`SRCDEST] = enc;         
        {map[`BASE_EXTEND],map[`BASE]} = ARCH_DUMMY_REG0; // Use this as the base register.
        
        if ( list == 0 ) // Catch 0 list here itself...
        begin
                // Restore base. MOV Rbase, DUMMY0
                if ( writeback )
                begin
                        map = { cc, 2'b0, 1'b0, MOV, 1'b0, 4'd0, base, 8'd0, 4'd0 };
                        {map[`DP_RS_EXTEND],map[`DP_RS]} = ARCH_DUMMY_REG0;  
                end
                else
                begin
                        map = 32'd0; // Wasted cycle.
                end
        end
        else if ( (store && s_bit) || (load && s_bit && !list[15]) ) // STR with S bit or LDR with S bit and no PC - force user bank access.
        begin
                        case ( map[`SRCDEST] ) // Force user bank.
                        8:      {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R8;
                        9:      {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R9;
                        10:     {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R10;
                        11:     {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R11;
                        12:     {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R12;
                        13:     {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R13;
                        14:     {map[`SRCDEST_EXTEND],map[`SRCDEST]}  = ARCH_USR2_R14;
                        endcase
        end
        else if ( load && enc == 15  ) // Load with PC in register list. Load to dummy register. S bit does not matter here. Will never use user bank.
        begin
                        // Load to ARCH_DUMMY_REG1.
                        {map[`SRCDEST_EXTEND],map[`SRCDEST]} = ARCH_DUMMY_REG1;
        end
end
endfunction

// Priority encoder.
function [3:0] pri_enc ( input [15:0] in );
begin: priEncFn
        integer i;
        pri_enc = 4'd0;
        for(i=16;i>=0;i=i-1)
                if ( in[i] == 1'd1 )
                        pri_enc = i;
end
endfunction

always @ (posedge i_clk)
begin
        if      ( i_reset )                             clear;
        else if ( i_clear_from_writeback)               clear;
        else if ( i_data_stall )                        begin end       // Stall the CPU.
        else if ( i_clear_from_alu )                    clear;
        else if ( i_issue_stall )                       begin end
        else
        begin
                state_ff   <= state_nxt;
                reglist_ff <= reglist_nxt; 
        end
end

// Unit is reset.
task clear;
begin
        state_ff                <= IDLE;
        reglist_ff              <= 16'd0;
end
endtask

endmodule
