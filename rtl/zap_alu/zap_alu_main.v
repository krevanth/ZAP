`default_nettype none

/*
Filename --
zap_alu_main.v

HDL --
Verilog-2005

Dependencies --
None

Description --
This unit performs arithmetic operations. It also generates memory signals at the end of
the clock cycle. RRX is performed here since the operation is trivial.

Author --
Revanth Kamaraj

License --
Released under the MIT license.
*/

module zap_alu_main #(
        parameter PHY_REGS = 46,
        parameter SHIFT_OPS = 5,
        parameter ALU_OPS = 32
)
(
        // Clock and reset.
        input wire                         i_clk,                  // ZAP clock.
        input wire                         i_reset,                // ZAP synchronous active high reset.

        // From CPSR. ( I, F, T, Mode )
        input wire  [31:0]                 i_cpsr_ff,

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
        output reg              [3:0]       o_flags_ff,                 // Output flags.
        output reg                          o_flag_update_ff,

        output reg  [$clog2(PHY_REGS)-1:0]  o_mem_srcdest_index_ff,     
        output reg                          o_mem_load_ff,                     
        output reg                          o_mem_store_ff,                         
        output reg                          o_mem_unsigned_byte_enable_ff,     
        output reg                          o_mem_signed_byte_enable_ff,       
        output reg                          o_mem_signed_halfword_enable_ff,        
        output reg                          o_mem_unsigned_halfword_enable_ff,      
        output reg [31:0]                   o_mem_srcdest_value_ff,
        output reg                          o_mem_translate_ff 
);

`include "cc.vh"
`include "regs.vh"
`include "opcodes.vh"

localparam N = 3;
localparam Z = 2;
localparam C = 1;
localparam V = 0;

reg sleep_ff, sleep_nxt;
reg [3:0] flags_ff, flags_nxt;
reg [31:0] rm, rn;
reg [31:0] mem_address_nxt;

always @*
begin
        rm         = i_shifted_source_value_ff;
        rn         = i_alu_source_value_ff;
        o_flags_ff = flags_ff;
end

// Provides branch instructions. This will change
// the direction PC takes.
always @*
begin
        if ( i_destination_index_ff == PHY_PC )
        begin
                o_clear_from_alu = 1'd1;
                o_pc_from_alu    = o_alu_result_nxt;
        end
        else
        begin
                o_clear_from_alu = 1'd0;
                o_pc_from_alu = 32'd0;
        end
end

// This check can be done independently of
// others. This ensures that the instructions can be
// executed.
always @*
        o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff );

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                o_alu_result_ff                  <= 0;
                o_dav_ff                         <= 0;
                o_pc_plus_8_ff                   <= 0;
                o_mem_address_ff                 <= 0;
                o_destination_index_ff           <= 0;
                flags_ff                         <= 0;
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
                o_flag_update_ff                 <= 0;
        end
        else if ( i_clear_from_writeback ) // Make flags_ff same as i_cpsr_nxt
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
                sleep_ff                         <= 0;
                o_flag_update_ff                 <= 0; 

        end
        else if ( i_data_stall )
        begin
                // Preserve values.
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
                        o_flag_update_ff                 <= 0;
                        sleep_ff                         <= 1'd1; // Keep sleeping.
                end
                else
                begin
                        o_alu_result_ff                  <= o_alu_result_nxt;
                        o_dav_ff                         <= o_dav_nxt;                
                        o_pc_plus_8_ff                   <= i_pc_plus_8_ff;
                        o_mem_address_ff                 <= mem_address_nxt;
                        o_destination_index_ff           <= i_destination_index_ff;
                        flags_ff                         <= o_dav_nxt ? flags_nxt : flags_ff;
                        o_abt_ff                         <= i_abt_ff;
                        o_irq_ff                         <= i_irq_ff;
                        o_fiq_ff                         <= i_fiq_ff;
                        o_swi_ff                         <= i_swi_ff;
                        o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;
                        o_mem_srcdest_index_ff           <= i_mem_srcdest_index_ff;           
                        o_mem_load_ff                    <= i_mem_load_ff;                    
                        o_mem_store_ff                   <= i_mem_store_ff;                   
                        o_mem_unsigned_byte_enable_ff    <= i_mem_unsigned_byte_enable_ff;    
                        o_mem_signed_byte_enable_ff      <= i_mem_signed_byte_enable_ff;      
                        o_mem_signed_halfword_enable_ff  <= i_mem_signed_halfword_enable_ff;  
                        o_mem_unsigned_halfword_enable_ff<= i_mem_unsigned_halfword_enable_ff;
                        o_mem_translate_ff               <= i_mem_translate_ff;  
                        o_mem_srcdest_value_ff           <= i_mem_srcdest_value_ff;
                        sleep_ff                         <= sleep_nxt;
                        o_flag_update_ff                 <= i_flag_update_ff;
                end
        end
end

always @*
begin: blk1
       reg [31:0] rd;
       reg [$clog2(ALU_OPS)-1:0]  opcode;

       opcode = i_alu_operation_ff;
       sleep_nxt = sleep_ff;

       o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff );

        if ( i_irq_ff || i_fiq_ff || i_abt_ff || i_swi_ff ) // Any sign of an interrupt is present.
        begin
                // Send out invalid instruction. Interrupt will trigger despite the instruction
                // being invalid. Flags won't be updated because of this.
                o_dav_nxt = 1'd0;

                // Put the unit to sleep.
                sleep_nxt = 1'd1;
        end
        else if (       opcode == AND || 
                        opcode == EOR || 
                        opcode == MOV || 
                        opcode == MVN || 
                        opcode == BIC || 
                        opcode == ORR 
                )
        begin
                {flags_nxt, rd} = process_logical_instructions ( rn, rm, flags_ff, opcode, i_rrx_ff, i_flag_update_ff  );

                // If the target is PC and instruction is valid, put unit to sleep.
                if ( o_dav_nxt && i_destination_index_ff == PHY_PC )
                begin
                        sleep_nxt = 1'd1;
                end
        end
        else if ( opcode == FMOV || opcode == MMOV )
        begin: blk2
                // Update ALU flags if needed. Also a fancy MOV instruction.
                // This is a special kind of MOV instruction that has mask bits
                // in ALU source.

                integer i;
                reg [31:0] exp_mask;

                flags_nxt = flags_ff;

                rd = {flags_ff, 4'd0, 8'd0, 8'd0, i_cpsr_ff[7:0]}; 
                exp_mask = {{8{rn[3]}},{8{rn[2]}},{8{rn[1]}},{8{rn[0]}}};

                for ( i=0;i<32;i=i+1 )
                begin
                        if ( exp_mask[i] )
                                rd[i] = rm[i];
                end                

                // We must put the unit to sleep if rd[7:0] is different from i_cpsr_ff[7:0]. If only flags
                // are changing, we can update flags_nxt.

                if ( opcode == FMOV && o_dav_nxt )
                begin
                        if ( rd[7:0] != i_cpsr_ff[7:0] ) // Critical change.
                        begin
                                sleep_nxt = 1;          // Set to sleep.
                                flags_nxt = rd[31:28];  // Update flags too.
                        end
                        else
                        begin
                                flags_nxt = rd[31:28]; // Just update flags. Don't sleep.
                        end
                end
        end
        else
        begin: blk3
                // Process arithmetic instructions.
                {flags_nxt, rd} = process_arithmetic_instructions ( rn, rm, flags_ff, opcode, i_rrx_ff, i_flag_update_ff );

                // If the target is PC and instruction is valid, put unit to sleep.
                if ( o_dav_nxt && i_destination_index_ff == PHY_PC )
                begin
                        sleep_nxt = 1'd1;
                end
        end

        // Memory address output based on pre or post index.
        if ( i_mem_pre_index_ff == 1 )
                mem_address_nxt = rn;  
        else
                mem_address_nxt = rd;

        o_alu_result_nxt = rd;
end

// Process logical instructions.
function [35:0] process_logical_instructions 
( input [31:0] rn, rm, input [3:0] flags, input [$clog2(ALU_OPS)-1:0] op, input rrx, input i_flag_upd );
begin: blk2
        reg [31:0] rd;
        reg [3:0] flags_out;
        reg       tmp_carry;

        if ( rrx )
        begin
                rm = {flags[C], rm[31:1]};
                tmp_carry = rm[0];
        end

        case(op)
        AND: rd = rn & rm;
        EOR: rd = rn ^ rm;
        BIC: rd = rn & ~(rm);
        MOV: rd = rm;
        MVN: rd = ~rm;
        ORR: rd = rn | rm;
        TST: rd = rn & rm;
        TEQ: rd = rn ^ rn;
        endcase           

        flags_out = flags;

        if ( rrx && i_flag_upd )
        begin
                flags_out[C] = tmp_carry;
        end

        if ( rd == 0 && i_flag_upd )
                flags_out[Z] = 1'd1;

        if ( rd[31] && i_flag_upd )
                flags_out[N] = 1'd1;

        process_logical_instructions = {flags_out, rd};     
end
endfunction

// Process arithmetic instructions.
function [35:0] process_arithmetic_instructions 
( input [31:0] rn, rm, input [3:0] flags, input [$clog2(ALU_OPS)-1:0] op, input rrx, input i_flag_upd );
begin: blk3
        reg [31:0] rd;
        reg n,z,c,v;
        reg [3:0] flags_out;

        if ( rrx )
        begin
                rm = {flags[C], rm[31:1]}; // The flag is not used anyway.
        end

        case ( op )
        ADD: {c,rd} = rn +  rm + 32'd0;
        ADC: {c,rd} = rn +  rm + flags[C];
        SUB: {c,rd} = rn + ~rm + 32'd1;
        RSB: {c,rd} = rn + ~rm + 32'd1;
        SBC: {c,rd} = rn + ~rm + !flags[C];
        RSC: {c,rd} = rm + ~rn + !flags[C];
        CMP: {c,rd} = rm + ~rn + 32'd0;
        CMN: {c,rd} = rm + ~rn + 32'd1;
        endcase

        flags_out = flags;

        if ( i_flag_upd )
        begin
                if ( rd == 0 )                  flags_out[Z] = 1;
                if ( rd[31] )                   flags_out[N] = 1;
                if ( c )                        flags_out[C] = 1;

                // Overflow.
                if ( rn[31] == rm[31] && (rd[31] != rn[31]) )
                begin
                        flags_out[V] = 1;
                end 
        end

        process_arithmetic_instructions = {flags_out, rd};

end
endfunction

// Determines if the current instruction is worthy of execution.
function is_cc_satisfied 
( 
        input [3:0] cc,         // 31:28 of the instruction. 
        input [3:0] fl          // CPSR flags.
);
reg ok,n,z,c,v;
begin
        {n,z,c,v} = fl;

        case(cc)
        EQ:     ok =  z;
        NE:     ok = !z;
        CS:     ok = c;
        CC:     ok = !c;
        MI:     ok = n;
        PL:     ok = !n;
        VS:     ok = v;
        VC:     ok = !v;
        HI:     ok = c && !z;
        LS:     ok = !c || z;
        GE:     ok = n^v;
        LT:     ok = !(n^v);
        GT:     ok = (n^v) && !z;
        LE:     ok = (!(n^v)) || z;
        AL:     ok = 1;
        NV:     ok = 0;                    
        endcase   

        is_cc_satisfied = ok;
end
endfunction

endmodule
