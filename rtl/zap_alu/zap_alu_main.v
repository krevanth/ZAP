`default_nettype none
`include "config.vh"

/*
Filename --
zap_alu_main.v

HDL --
Verilog-2005

Dependencies --
None

Description --
This unit performs arithmetic operations. It also generates memory signals at the end of
the clock cycle. RRX is performed here since the operation is trivial. The point is to 
not carry CARRY over to another stage.

Author --
Revanth Kamaraj

License --
Released under the MIT license.
*/

module zap_alu_main #(
        parameter PHY_REGS = 46,
        parameter SHIFT_OPS = 5,
        parameter ALU_OPS = 32,
        parameter FLAG_WDT = 32
)
(
        // Clock and reset.
        input wire                         i_clk,                  // ZAP clock.
        input wire                         i_reset,                // ZAP synchronous active high reset.

        // Taken.
        input wire   [1:0]                 i_taken_ff,

        // PC
        input wire   [31:0]                i_pc_ff,

        // From CPSR. ( I, F, T, Mode ) - From WB.
//        input wire  [31:0]                 i_cpsr_ff,
        input wire  [31:0]                 i_cpsr_nxt,

        // State switch ( ARM <-> Thumb possible ).
        input wire                         i_switch_ff,

        // Clear and Stall signals.
        input wire                         i_clear_from_writeback, // | High Priority
        input wire                         i_data_stall,           // V Low Priority

        // Inputs from shift stage.
        input wire  [31:0]                 i_mem_srcdest_value_ff,      // Value to store.
        input wire  [31:0]                 i_alu_source_value_ff,       // ALU source operand.
        input wire  [31:0]                 i_shifted_source_value_ff,   // Shifter source operand. 
        input wire                         i_shift_carry_ff,            // Carry out from shifer.
        input wire                         i_rrx_ff,                    // RRX indicator to be done in this stage.
        input wire  [31:0]                 i_pc_plus_8_ff,
        input wire                         i_abt_ff, 
                                           i_irq_ff, 
                                           i_fiq_ff, 
                                           i_swi_ff,
        input wire  [$clog2(PHY_REGS)-1:0] i_mem_srcdest_index_ff,     
        input wire                         i_mem_load_ff,                     
        input wire                         i_mem_store_ff,                         
        input wire                         i_mem_pre_index_ff,                
        input wire                         i_mem_unsigned_byte_enable_ff,     
        input wire                         i_mem_signed_byte_enable_ff,       
        input wire                         i_mem_signed_halfword_enable_ff,        
        input wire                         i_mem_unsigned_halfword_enable_ff,      
        input wire                         i_mem_translate_ff,  
        input wire  [3:0]                  i_condition_code_ff,
        input wire  [$clog2(PHY_REGS)-1:0] i_destination_index_ff,
        input wire  [$clog2(ALU_OPS)-1:0]  i_alu_operation_ff,      
        input wire                         i_flag_update_ff,

        // Force 32.
        input wire                         i_force32align_ff,

        // Use old carry.
        input wire                         i_use_old_carry_ff,

        // undefined instr.
        input wire                         i_und_ff,
        output reg                         o_und_ff,

        // data abort.
        input wire                         i_data_mem_fault,

        // Outputs
        output reg [31:0]                   o_alu_result_nxt,

        output reg [31:0]                   o_alu_result_ff,

        // Interrupt outputs.
        output reg                          o_abt_ff, 
        output reg                          o_irq_ff, 
        output reg                          o_fiq_ff, 
        output reg                          o_swi_ff,

        // Memory stuff.
        output reg                          o_dav_ff,
        output reg                          o_dav_nxt,
        output reg [31:0]                   o_pc_plus_8_ff,
        output reg [31:0]                   o_mem_address_ff,           // Memory addresss sent. 
        output reg                          o_clear_from_alu,
        output reg [31:0]                   o_pc_from_alu,
        output reg [$clog2(PHY_REGS)-1:0]   o_destination_index_ff,

        output reg [FLAG_WDT-1:0]           o_flags_ff,                 // Output flags (CPSR).
        output reg [FLAG_WDT-1:0]           o_flags_nxt,                // Next output flags (CPSR) - For multiply.

        output reg                          o_confirm_from_alu,

        output reg  [$clog2(PHY_REGS)-1:0]  o_mem_srcdest_index_ff,     
        output reg                          o_mem_load_ff,                     
        output reg                          o_mem_store_ff,                         
        output reg                          o_mem_unsigned_byte_enable_ff,     
        output reg                          o_mem_signed_byte_enable_ff,       
        output reg                          o_mem_signed_halfword_enable_ff,        
        output reg                          o_mem_unsigned_halfword_enable_ff,      
        output reg [31:0]                   o_mem_srcdest_value_ff,
        output reg                          o_mem_translate_ff,

        /* Byte enables useful for writes. */
        output reg [3:0]                    o_ben_ff 
);

`include "cc.vh"
`include "regs.vh"
`include "opcodes.vh"
`include "cpsr.vh"
`include "modes.vh"
`include "global_functions.vh"

// These override global N,Z,C,V definitions which are on CPSR.
localparam _N = 3;
localparam _Z = 2;
localparam _C = 1;
localparam _V = 0;

// Branch status.
localparam SNT = 2'd0;
localparam WNT = 2'd1;
localparam WT  = 2'd2;
localparam ST  = 2'd3;

reg                             sleep_ff, sleep_nxt;
reg [31:0]                      flags_ff, flags_nxt;
reg [31:0]                      rm, rn;
reg [31:0]                      mem_address_nxt;
reg [$clog2(PHY_REGS)-1:0]      o_destination_index_nxt;
wire [31:0]                     not_rm, not_rn;

assign not_rm = ~rm;
assign not_rn = ~rn;

// Wires to connect to the adder.
reg [31:0]      op1, op2;
reg             cin;

always @*
begin
        rm         = i_shifted_source_value_ff;
        rn         = i_alu_source_value_ff;
        o_flags_ff = flags_ff;
        o_flags_nxt = flags_nxt;
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                o_alu_result_ff                  <= 0;
                o_dav_ff                         <= 0;
                o_pc_plus_8_ff                   <= 0;
                o_mem_address_ff                 <= 0;
                o_destination_index_ff           <= 0;
                flags_ff                         <= {1'd1,1'd1,1'd0,SVC};
                o_abt_ff                         <= 0;
                o_irq_ff                         <= 0;
                o_fiq_ff                         <= 0;
                o_swi_ff                         <= 0;
                o_mem_srcdest_index_ff           <= 0;
                o_mem_srcdest_index_ff           <= 0;
                o_mem_load_ff                    <= 0;
                o_mem_store_ff                   <= 0;
                o_mem_unsigned_byte_enable_ff    <= 0;
                o_mem_signed_byte_enable_ff      <= 0;
                o_mem_signed_halfword_enable_ff  <= 0;
                o_mem_unsigned_halfword_enable_ff<= 0;
                o_mem_translate_ff               <= 0;
                o_mem_srcdest_value_ff           <= 0;
                sleep_ff                         <= 0;
                o_und_ff                         <= 0;
                o_ben_ff                         <= 0;
        end
        else if ( i_clear_from_writeback ) 
        begin
                o_alu_result_ff                  <= 0; 
                o_dav_ff                         <= 0;    
                o_pc_plus_8_ff                   <= 0; 
                o_mem_address_ff                 <= 0; 
                o_destination_index_ff           <= 0; 
                flags_ff                         <= i_cpsr_nxt; // If the instruction that caused clear has flags, then copy that over.
                o_abt_ff                         <= 0; 
                o_irq_ff                         <= 0; 
                o_fiq_ff                         <= 0; 
                o_swi_ff                         <= 0; 
                o_mem_srcdest_index_ff           <= 0; 
                o_mem_srcdest_index_ff           <= 0; 
                o_mem_load_ff                    <= 0; 
                o_mem_store_ff                   <= 0; 
                o_mem_unsigned_byte_enable_ff    <= 0; 
                o_mem_signed_byte_enable_ff      <= 0; 
                o_mem_signed_halfword_enable_ff  <= 0; 
                o_mem_unsigned_halfword_enable_ff<= 0; 
                o_mem_translate_ff               <= 0; 
                o_mem_srcdest_value_ff           <= 0;
                sleep_ff                         <= 0;
                o_und_ff                         <= 0;
                o_ben_ff                         <= 0;
        end
        else if ( i_data_stall )
        begin
                // Preserve values.
        end
        else if ( i_data_mem_fault )
        begin
                        o_alu_result_ff                  <= 0; 
                        o_dav_ff                         <= 0;    
                        o_pc_plus_8_ff                   <= 0; 
                        o_mem_address_ff                 <= 0; 
                        o_destination_index_ff           <= 0; 
                        flags_ff                         <= flags_ff; // Preserve flags.
                        o_abt_ff                         <= 0; 
                        o_irq_ff                         <= 0; 
                        o_fiq_ff                         <= 0; 
                        o_swi_ff                         <= 0; 
                        o_mem_srcdest_index_ff           <= 0; 
                        o_mem_srcdest_index_ff           <= 0; 
                        o_mem_load_ff                    <= 0; 
                        o_mem_store_ff                   <= 0; 
                        o_mem_unsigned_byte_enable_ff    <= 0; 
                        o_mem_signed_byte_enable_ff      <= 0; 
                        o_mem_signed_halfword_enable_ff  <= 0; 
                        o_mem_unsigned_halfword_enable_ff<= 0; 
                        o_mem_translate_ff               <= 0; 
                        o_mem_srcdest_value_ff           <= 0;
                        sleep_ff                         <= 1'd1; // Initiate a sleep.
                        o_und_ff                         <= 0;
                        o_ben_ff                         <= 0;
               
        end
        else
        begin
                if ( sleep_ff )
                begin
                        o_alu_result_ff                  <= 0; 
                        o_dav_ff                         <= 0;    
                        o_pc_plus_8_ff                   <= 0; 
                        o_mem_address_ff                 <= 0; 
                        o_destination_index_ff           <= 0; 
                        flags_ff                         <= flags_ff; // Preserve flags.
                        o_abt_ff                         <= 0; 
                        o_irq_ff                         <= 0; 
                        o_fiq_ff                         <= 0; 
                        o_swi_ff                         <= 0; 
                        o_mem_srcdest_index_ff           <= 0; 
                        o_mem_srcdest_index_ff           <= 0; 
                        o_mem_load_ff                    <= 0; 
                        o_mem_store_ff                   <= 0; 
                        o_mem_unsigned_byte_enable_ff    <= 0; 
                        o_mem_signed_byte_enable_ff      <= 0; 
                        o_mem_signed_halfword_enable_ff  <= 0; 
                        o_mem_unsigned_halfword_enable_ff<= 0; 
                        o_mem_translate_ff               <= 0; 
                        o_mem_srcdest_value_ff           <= 0;
                        sleep_ff                         <= 1'd1; // Keep sleeping.
                        o_und_ff                         <= 0;
                end
                else
                begin
                        o_alu_result_ff                  <= o_alu_result_nxt;
                        o_dav_ff                         <= o_dav_nxt;                
                        o_pc_plus_8_ff                   <= i_pc_plus_8_ff;
                        o_mem_address_ff                 <= mem_address_nxt;
                        o_destination_index_ff           <= o_destination_index_nxt;
                        flags_ff                         <= flags_nxt;
                        o_abt_ff                         <= i_abt_ff;
                        o_irq_ff                         <= i_irq_ff;
                        o_fiq_ff                         <= i_fiq_ff;
                        o_swi_ff                         <= i_swi_ff;
                        o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;
                        o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;           
                        o_mem_load_ff                    <= o_dav_nxt ? i_mem_load_ff : 1'd0;                    
                        o_mem_store_ff                   <= o_dav_nxt ? i_mem_store_ff: 1'd0;                   
                        o_mem_unsigned_byte_enable_ff    <= i_mem_unsigned_byte_enable_ff;    
                        o_mem_signed_byte_enable_ff      <= i_mem_signed_byte_enable_ff;      
                        o_mem_signed_halfword_enable_ff  <= i_mem_signed_halfword_enable_ff;  
                        o_mem_unsigned_halfword_enable_ff<= i_mem_unsigned_halfword_enable_ff;
                        o_mem_translate_ff               <= i_mem_translate_ff;  
                        o_mem_srcdest_value_ff           <= duplicate   (i_mem_unsigned_byte_enable_ff, i_mem_signed_byte_enable_ff, i_mem_unsigned_halfword_enable_ff, i_mem_unsigned_halfword_enable_ff, i_mem_srcdest_value_ff); 
                        sleep_ff                         <= sleep_nxt;
                        o_und_ff                         <= i_und_ff;
                        o_ben_ff                         <= generate_ben(i_mem_unsigned_byte_enable_ff, i_mem_signed_byte_enable_ff, i_mem_unsigned_halfword_enable_ff, i_mem_unsigned_halfword_enable_ff, mem_address_nxt);
                end
        end
end

function [31:0] duplicate (input ub, input sb, input uh, input sh, input [31:0] val);
reg [31:0] x;
begin
        if ( ub || sb)
        begin
                // Byte.
                x = {val[7:0], val[7:0], val[7:0], val[7:0]};    
        end
        else if (uh || sh)
        begin
                // Halfword.
                x = {val[15:0], val[15:0]};
        end
        else
        begin
                x = val;
        end

        duplicate = x;
end
endfunction

function [3:0] generate_ben (input ub, input sb, input uh, input sh, input [31:0] addr);
reg [3:0] x;
begin
        if ( ub || sb )
        begin
                case ( addr[1:0] )
                0: x = 1;
                1: x = 1 << 1;
                2: x = 1 << 2;
                3: x = 1 << 3;
                endcase
        end 
        else if ( uh || sh )
        begin
                case ( addr[1] )
                0: x = 4'b0011;
                1: x = 4'b1100;
                endcase
        end
        else
        begin
                x = 4'b1111;
        end

        generate_ben = x;
end
endfunction

always @*
begin
        // Memory address output based on pre or post index.
        if ( i_mem_pre_index_ff == 0 ) // Post-index. Update is done after memory access.
                mem_address_nxt = rn;   
        else                           // Pre-index. Update is done before memory access.
                mem_address_nxt = o_alu_result_nxt;

        // If a force 32 align is set, make the lower 2 bits as zero.
        // Valid for Thumb.
        if ( i_force32align_ff )
                mem_address_nxt[1:0] = 2'b00;

        // Do not change address simply.
        if (!( (i_mem_load_ff || i_mem_store_ff) && o_dav_nxt )) // If NOT a load OR a store.
                mem_address_nxt = o_mem_address_ff;
end

always @*
begin: blk1
       reg [31:0] rd;
       reg [$clog2(ALU_OPS)-1:0]  opcode;

       o_clear_from_alu         = 1'd0;
       o_pc_from_alu            = 32'd0;
       opcode                   = i_alu_operation_ff;
       sleep_nxt                = sleep_ff;
       flags_nxt                = flags_ff;
       o_destination_index_nxt  = i_destination_index_ff;
       o_confirm_from_alu      = 1'd0;
       op1 = 0;
       op2 = 0;
       cin = 0;

       o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff[31:28] );

        if (            opcode == AND || 
                        opcode == EOR || 
                        opcode == MOV || 
                        opcode == MVN || 
                        opcode == BIC || 
                        opcode == ORR ||
                        opcode == TST ||
                        opcode == TEQ ||
                        opcode == CLZ 
                )
        begin
                {flags_nxt[31:28], rd} = process_logical_instructions ( rn, rm, flags_ff[31:28], opcode, i_rrx_ff, i_flag_update_ff  );
        end
        else if ( opcode == FMOV || opcode == MMOV )
        begin: blk2
                integer i;
                reg [31:0] exp_mask;

                rd = flags_ff;
                exp_mask = {{8{rn[3]}},{8{rn[2]}},{8{rn[1]}},{8{rn[0]}}};

                for ( i=0;i<32;i=i+1 )
                begin
                        if ( exp_mask[i] )
                                rd[i] = rm[i];
                end

                if ( opcode == FMOV )
                begin
                        flags_nxt = rd;
                end                
        end
        else
        begin: blk3
                {flags_nxt[31:28], rd} = process_arithmetic_instructions ( rn, rm, not_rn, not_rm, flags_ff[31:28], opcode, i_rrx_ff, i_flag_update_ff );
        end

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        if ( i_irq_ff || i_fiq_ff || i_abt_ff || i_swi_ff || i_und_ff ) // Any sign of an interrupt is present.
        begin
                `ifdef SIM
                        $display($time, "ALU :: Interrupt detected! ALU put to sleep...");
                `endif

                o_dav_nxt = 1'd0;
                sleep_nxt = 1'd1;
        end
        else if ( (opcode == FMOV) && o_dav_nxt ) // Writes to CPSR.
        begin
                `ifdef SIM
                        $display($time, "ALU :: Major change to CPSR! Restarting from the next instruction...");
                `endif
                o_clear_from_alu        = 1'd1;
                o_pc_from_alu           = i_pc_plus_8_ff - 32'd4;
                flags_nxt[`CPSR_MODE]   = (flags_nxt[`CPSR_MODE] == USR) ? USR : flags_nxt[`CPSR_MODE]; // Security.
        end
        else if ( i_destination_index_ff == ARCH_PC )
        begin
                if ( i_flag_update_ff && o_dav_nxt ) // Unit sleeps since this is handled in WB. Taken :: flag_update
                begin
                        `ifdef SIM
                                $display($time, "ALU :: PC write with flag update! Unit put to sleep...");
                        `endif
                        sleep_nxt = 1'd1;

                        // No need to tell the predictor anything.
                end
                else if ( o_dav_nxt ) // Taken :: Without flag updates!
                begin
                        `ifdef SIM
                                $display($time, "ALU :: A quick branch! Possibly a BX i_switch_ff = %d...", i_switch_ff);
                        `endif

                        if ( i_taken_ff == SNT || i_taken_ff == WNT ) // Incorrectly predicted.
                        begin
                                // Quick branches - Flush everything before.
                                o_destination_index_nxt = PHY_RAZ_REGISTER;                     // Dumping ground since PC change is done.
                                o_clear_from_alu        = 1'd1;
                                o_pc_from_alu           = rd;
                                flags_nxt[T]            = i_switch_ff ? rd[0] : flags_ff[T];   // Thumb/ARM state if i_switch_ff = 1.
                        end
                        else    // Correctly predicted.
                        begin
                                // If thumb bit changes, flush everything before
                                if ( i_switch_ff )
                                begin
                                        // Quick branches!
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;                     // Dumping ground since PC change is done.
                                        o_clear_from_alu        = 1'd1;
                                        o_pc_from_alu           = rd;
                                        flags_nxt[T]            = i_switch_ff ? rd[0] : flags_ff[T];   // Thumb/ARM state if i_switch_ff = 1.
                                end
                                else
                                begin
                                        // No mode change, do not change anything.
                                        o_destination_index_nxt = PHY_RAZ_REGISTER;
                                        o_clear_from_alu = 1'd0;
                                        flags_nxt[T]     = i_switch_ff ? rd[0] : flags_ff[T];

                                        // Send confirmation message to branch predictor.
                                        o_pc_from_alu      = 32'd0;
                                        o_confirm_from_alu = 1'd1; 
                                end
                        end
                end
                else    // Branch not taken
                begin
                        if ( i_taken_ff == WT || i_taken_ff == ST ) // Wrong prediction.
                        begin
                                o_clear_from_alu = 1'd1;
                                o_pc_from_alu    = i_pc_ff; // Go to the same branch.
                        end
                        else
                        begin
                                // Correct prediction.
                                o_clear_from_alu = 1'd0;
                                o_pc_from_alu    = 32'd0;
                        end
                end
        end
        else if ( i_mem_srcdest_index_ff == ARCH_PC && o_dav_nxt && i_mem_load_ff)
        begin
                // Loads to PC also puts the unit to sleep.
                sleep_nxt = 1'd1;
        end

        // Drive nxt.
        o_alu_result_nxt = rd;

        if ( o_dav_nxt == 1'd0 ) // If the current instruction is invalid, do not update flags.
                flags_nxt = flags_ff;
end

// Process logical instructions.
function [35:0] process_logical_instructions 
( input [31:0] rn, rm, input [3:0] flags, input [$clog2(ALU_OPS)-1:0] op, input rrx, input i_flag_upd );
begin: blk2
        reg [31:0] rd;
        reg [3:0] flags_out;
        reg       tmp_carry;

        // Avoid accidental latch inference.
        rd = 0;
        flags_out = 0;
        tmp_carry = 0;

        if ( rrx )
        begin
                rm = {flags[_C], rm[31:1]};
                tmp_carry = rm[0];
        end
        else
        begin
                if ( i_use_old_carry_ff )
                begin
                        tmp_carry = flags[_C];
                end
                else
                begin
                        tmp_carry = i_shift_carry_ff;
                end
        end

        case(op)
        AND: rd = rn & rm;
        EOR: rd = rn ^ rm;
        BIC: rd = rn & ~(rm);
        MOV: rd = rm;
        MVN: rd = ~rm;
        ORR: rd = rn | rm;
        TST: rd = rn & rm; // Target is not written.
        TEQ: rd = rn ^ rn; // Target is not written.
//        CLZ: rd = count_leading_zeros(rm); /* v4T does not need CLZ support. Leaving the function here anyway. */
        default:
        begin
                `ifdef SIM
                        //#40;
                        $display("This should never happen, check the RTL!");
                        //$stop;
                `endif
        end
        endcase           

        // Suppose flags are not going to change at ALL.
        flags_out = flags;

        // Assign values to the flags only if an update is requested. Note that V
        // is not touched even if change is requested.
        if ( i_flag_upd )
        begin
                // V is preserved since flags_out = flags assignment.
                flags_out[_C] = tmp_carry;
                flags_out[_Z] = (rd == 0);
                flags_out[_N] = rd[31];
        end

        process_logical_instructions = {flags_out, rd};     
end
endfunction

// Process arithmetic instructions.
function [35:0] process_arithmetic_instructions 
( input [31:0] rn, rm, not_rn, not_rm, input [3:0] flags, input [$clog2(ALU_OPS)-1:0] op, input rrx, input i_flag_upd );
begin: blk3

        reg [31:0]      r_d;
        reg             n,z,c,v;

        // Avoid accidental latch inference.
        r_d       = 0;
        n         = 0;
        z         = 0;
        c         = 0;
        v         = 0;
        op1       = 0;
        op2       = 0;
        cin       = 0;

        if ( rrx )
        begin
                rm = {flags[_C], rm[31:1]}; // The flag from the shifter is not used anyway.
        end

        case ( op )
        ADD: begin op1 = rn ; op2 = rm     ; cin =   32'd0;     end
        ADC: begin op1 = rn ; op2 = rm     ; cin =   flags[_C]; end
        SUB: begin op1 = rn ; op2 = not_rm ; cin =   32'd1;     end
        RSB: begin op1 = rm ; op2 = not_rn ; cin =   32'd1;     end
        SBC: begin op1 = rn ; op2 = not_rm ; cin =   !flags[_C];end
        RSC: begin op1 = rm ; op2 = not_rn ; cin =   !flags[_C];end
        CMP: begin op1 = rn ; op2 = not_rm ; cin =   32'd1;     end // Target is not written.
        CMN: begin op1 = rn ; op2 = rm     ; cin =   32'd0;     end // Target is not written.
        default:
        begin
                `ifdef SIM
                        //#40;
                        $display("ALU__arith__:This should never happen op = %d, check the RTL!", op);
                        //$stop;
                `endif
        end
        endcase

        // Assign output of adder to variables
        {c,r_d} = sum(op1,op2,cin);

        // Compute Z and N (C computed before).
        z = (r_d == 0);
        n = r_d[31];

        // Overflow.
        if ( ( op == ADD || op == ADC || op == CMN ) && (rn[31] == rm[31]) && (r_d[31] != rn[31]) )
        begin
                v = 1;
        end 
        else if ( (op == RSB || op == RSC) && (rm[31] == !rn[31]) && (r_d[31] != rm[31] ) )
        begin
                v = 1;
        end
        else if ( (op == SUB || op == SBC || op == CMP) && (rn[31] == !rm[31]) && (r_d[31] != rn[31]) )
        begin
                v = 1;
        end
        else
        begin
                v = 0;
        end
       
        // If you choose not to update flags, force n,z,c,v to previous values. 
        // Otherwise, they will contain their newly computed values.
        if ( !i_flag_upd )
                {n,z,c,v} = flags;

        // Write out the result.
        process_arithmetic_instructions = {n, z, c, v, r_d};

end
endfunction

// Count leading zeros.
function [5:0] count_leading_zeros ( input [31:0] in );
begin: clzBlk
        integer i;
        reg done;
        reg [5:0] cnt;

        // Avoid latch inference.
        done = 0;
        cnt  = 32; // If in = 0, out = 32

        // Ripple carry method.
        for(i=31;i>=0;i=i-1)
        begin
                if ( done == 0 ) /* no sleep */
                begin
                        // Keep counting till you see a '1'.
                        if ( in[i] == 1'd1 )
                        begin
                                // Put loop to sleep.
                                done = 1;
                        end
                        else
                        begin
                                cnt = cnt - 6'd1;        
                        end
                end
        end

        count_leading_zeros = cnt;        
        
end
endfunction

function [32:0] sum ( input [31:0] op1, input [31:0] op2, input cin );
        sum = op1 + op2 + cin;
endfunction

endmodule
