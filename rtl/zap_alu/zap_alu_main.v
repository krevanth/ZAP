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

        // From CPSR. ( I, F, T, Mode ) - From WB.
        input wire  [31:0]                 i_cpsr_ff,
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
`include "cpsr.vh"
`include "modes.vh"

// These override global N,Z,C,V definitions which are on CPSR.
localparam _N = 3;
localparam _Z = 2;
localparam _C = 1;
localparam _V = 0;

reg sleep_ff, sleep_nxt;
reg [31:0] flags_ff, flags_nxt;
reg [31:0] rm, rn;
reg [31:0] mem_address_nxt;
reg [$clog2(PHY_REGS)-1:0] o_destination_index_nxt;

always @*
begin
        rm         = i_shifted_source_value_ff;
        rn         = i_alu_source_value_ff;
        o_flags_ff = flags_ff;
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
                flags_ff                         <= SVC;
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
                o_und_ff                         <= 0;
        end
        else if ( i_clear_from_writeback ) 
        begin
                o_alu_result_ff                  <= 0; 
                o_dav_ff                         <= 0;    
                o_pc_plus_8_ff                   <= 0; 
                o_mem_address_ff                 <= 0; 
                o_destination_index_ff           <= 0; 
                flags_ff                         <= i_cpsr_nxt; 
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
                o_und_ff                         <= 0;
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
                        o_und_ff                         <= i_und_ff;
                end
        end
end

always @*
begin
        // Memory address output based on pre or post index.
        if ( i_mem_pre_index_ff == 0 ) // Post-index. Update is done after memory access.
                mem_address_nxt = rn;   
        else                           // Pre-index. Update is done before memory access.
                mem_address_nxt = o_alu_result_nxt;

        if ( i_force32align_ff )
                mem_address_nxt[1:0] = 2'b00;
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

       o_dav_nxt = is_cc_satisfied ( i_condition_code_ff, flags_ff[31:28] );

        if (            opcode == AND || 
                        opcode == EOR || 
                        opcode == MOV || 
                        opcode == MVN || 
                        opcode == BIC || 
                        opcode == ORR 
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
                {flags_nxt[31:28], rd} = process_arithmetic_instructions ( rn, rm, flags_ff[31:28], opcode, i_rrx_ff, i_flag_update_ff );
        end

        if ( i_irq_ff || i_fiq_ff || i_abt_ff || i_swi_ff || i_und_ff ) // Any sign of an interrupt is present.
        begin
                `ifdef SIM
                        $display($time, "ALU :: Interrupt detected! ALU put to sleep...");
                `endif

                o_dav_nxt = 1'd0;
                sleep_nxt = 1'd1;
        end
        else if ( (flags_nxt[7:0] != flags_ff[7:0]) && o_dav_nxt ) // Critical change. Can occur only on FMOV.
        begin
                `ifdef SIM
                        $display($time, "ALU :: Major change to CPSR! Restarting from the next instruction...");
                `endif
                o_clear_from_alu = 1'd1;
                o_pc_from_alu    = i_pc_plus_8_ff - 32'd4;
                flags_nxt[`CPSR_MODE] = (flags_nxt[`CPSR_MODE] == USR) ? USR : flags_nxt[`CPSR_MODE]; // Security.
        end
        else if ( i_destination_index_ff == ARCH_PC && o_dav_nxt)
        begin
                if ( i_flag_update_ff ) // Unit sleeps since this is handled in WB.
                begin
                        `ifdef SIM
                                $display($time, "ALU :: PC write with flag update! Unit put to sleep...");
                        `endif
                        sleep_nxt = 1'd1;
                end
                else // Without flag updates!
                begin
                        `ifdef SIM
                                $display($time, "ALU :: A quick branch! Possibly a BX i_switch_ff = %d...", i_switch_ff);
                        `endif
                        // Quick branches!
                        o_destination_index_nxt = PHY_RAZ_REGISTER;                     // Dumping ground since PC change is done.
                        o_clear_from_alu        = 1'd1;
                        o_pc_from_alu           = rd;
                        flags_nxt[T]            = i_switch_ff ? rd[0] : flags_ff[T];   // Thumb/ARM state if i_switch_ff = 1.
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
        CLZ: rd = count_leading_zeros(rm);
        default:
        begin
                `ifdef SIM
                        $display("This should never happen, check the RTL!");
                        $stop;
                `endif
        end
        endcase           

        flags_out = flags;

        if ( i_flag_upd )
                flags_out[_C] = tmp_carry;

        if ( rd == 0 && i_flag_upd )
                flags_out[_Z] = 1'd1;

        if ( rd[31] && i_flag_upd )
                flags_out[_N] = 1'd1;

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

        // Avoid accidental latch inference.
        rd        = 0;
        n         = 0;
        z         = 0;
        c         = 0;
        v         = 0;
        flags_out = 0;

        if ( rrx )
        begin
                rm = {flags[_C], rm[31:1]}; // The flag from the shifter is not used anyway.
        end

        case ( op )
        ADD: {c,rd} = rn +  rm + 32'd0;
        ADC: {c,rd} = rn +  rm + flags[_C];
        SUB: {c,rd} = rn + ~rm + 32'd1;
        RSB: {c,rd} = rn + ~rm + 32'd1;
        SBC: {c,rd} = rn + ~rm + !flags[_C];
        RSC: {c,rd} = rm + ~rn + !flags[_C];
        CMP: {c,rd} = rm + ~rn + 32'd0; // Target is not written.
        CMN: {c,rd} = rm + ~rn + 32'd1; // Target is not written.
        default:
        begin
                `ifdef SIM
                        $display("ALU__arith__:This should never happen op = %d, check the RTL!", op);
                        $stop;
                `endif
        end
        endcase

        flags_out = flags;

        if ( i_flag_upd )
        begin
                if ( rd == 0 )                  flags_out[_Z] = 1;
                if ( rd[31] )                   flags_out[_N] = 1;
                if ( c )                        flags_out[_C] = 1;

                // Overflow.
                if ( rn[31] == rm[31] && (rd[31] != rn[31]) )
                begin
                        flags_out[_V] = 1;
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
        AL:     ok = 1'd1;
        NV:     ok = 1'd0;                    
        endcase   

        is_cc_satisfied = ok;
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

endmodule
