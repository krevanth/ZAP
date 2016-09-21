`default_nettype none

module zap_decode_coproc #(
        parameter PHY_REGS = 46
)
(
        input wire              i_clk,
        input wire              i_reset,

        // Stall signals
        

        input wire [31:0]       i_instruction,
        input wire              i_valid,

        input wire [31:0]       i_cpsr_ff,

        input wire              i_irq,
        input wire              i_fiq,

         // Clear and stall signals.
        input wire              i_clear_from_writeback, // | High Priority
        input wire              i_data_stall,           // |
        input wire              i_clear_from_alu,       // |
        input wire              i_stall_from_shifter,   // |
        input wire              i_stall_from_issue,     // V Low Priority

        input wire              i_pipeline_dav,

        input wire              i_copro_done,           // Coprocessor done indicator.

        output reg              o_irq,
        output reg              o_fiq,

        output reg [31:0]       o_instruction,
        output reg              o_valid,

        output reg              o_stall_from_decode,      // Stall from decode.

        output reg  [31:0]                o_copro_mode_ff,          // Processor mode sent to coprocessor.
        output reg                        o_copro_dav_ff,           // Are we really asking for the coprocessor.
        output reg  [31:0]                o_copro_word_ff,          // The entire instruction is passed to the coprocessor.
        output reg [$clog2(PHY_REGS)-1:0] o_copro_reg_ff            // Register the coprocessor must deal with. 
);

`include "cpsr.vh"
`include "regs.vh"
`include "modes.vh"
`include "instruction_patterns.vh"

localparam IDLE = 0;
localparam BUSY = 1;

reg state_ff, state_nxt;
reg cp_dav_nxt;
reg [31:0] cp_word_nxt;
reg cp_reg_nxt;

always @*
begin
        cp_dav_nxt              = o_copro_dav_ff;
        cp_word_nxt             = o_copro_word_ff;
        o_stall_from_decode     = 1'd0;
        o_instruction           = 32'd0;
        o_valid                 = 1'd0;
        state_nxt               = state_ff;
        o_irq                   = 1'd0;
        o_fiq                   = 1'd0;

        cp_reg_nxt              = o_copro_reg_ff;

        case ( state_ff )
        IDLE:
                // Activate only if no thumb.
                casez ( (!i_cpsr_ff[T]) ? i_instruction : 32'd0 )
                MRC, MCR, LDC, STC, CDP:
                begin
                        // As long as there is an instruction to process
                        if ( i_pipeline_dav )
                        begin
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd1;
                                cp_dav_nxt              = 1'd0;
                                cp_word_nxt             = 32'd0;
                                cp_reg_nxt              = 1'd0;
                        end
                        else
                        begin
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd1;
                                cp_word_nxt             = i_instruction;
                                cp_dav_nxt              = 1'd1;
                                state_nxt               = BUSY;

                                if ( i_instruction[27:25] != 3'b110 ) // MCR, MRC.
                                        cp_reg_nxt              = translate ( i_instruction[15:12], i_cpsr_ff[`CPSR_MODE] );
                                else                                  // LDC, STC, CDP(Useless)  
                                        cp_reg_nxt              = translate ( i_instruction[19:16], i_cpsr_ff[`CPSR_MODE] );
                        end
                end
                default:
                begin
                        // Remain transparent.
                        o_valid         = i_valid;
                        o_instruction   = i_instruction;
                        o_irq           = i_irq;
                        o_fiq           = i_fiq;
                        cp_dav_nxt      = 0;
                        cp_word_nxt     = 0;
                        cp_reg_nxt      = 0;
                        o_stall_from_decode = 1'd0;
                end
                endcase

        BUSY:
        begin
                cp_word_nxt             = o_copro_word_ff;
                cp_dav_nxt              = o_copro_dav_ff;
                cp_reg_nxt              = o_copro_reg_ff;
                o_stall_from_decode     = 1'd1;

                if ( i_copro_done )
                begin
                        cp_dav_nxt              = 1'd0;
                        cp_word_nxt             = 32'd0;
                        state_nxt               = IDLE;
                        o_stall_from_decode     = 1'd0;
                end
        end
        endcase
end

always @ (posedge i_clk)
begin
        if ( i_reset )
        begin
                clear;
        end
        else if ( i_clear_from_writeback )
        begin
                clear;
        end
        else if ( i_clear_from_alu )
        begin
                clear;
        end
        else if ( i_stall_from_shifter )
        begin
                // Preserve values.
        end
        else if ( i_stall_from_issue )
        begin
                // Preserve values.
        end
        else
        begin
                state_ff        <= state_nxt;
                o_copro_word_ff <= cp_word_nxt;
                o_copro_dav_ff  <= cp_dav_nxt;
                o_copro_reg_ff  <= cp_reg_nxt;
                o_copro_mode_ff <= i_cpsr_ff;
        end
end

task clear;
begin
                state_ff            <= IDLE;
                o_copro_word_ff     <= 32'd0;
                o_copro_dav_ff      <= 1'd0; 
                o_copro_reg_ff      <= 0;
                o_copro_mode_ff     <= 0;
end
endtask

// ===========================
// Translate FUNCTION.
// ===========================
function [$clog2(PHY_REGS)-1:0] translate ( input [$clog2(PHY_REGS)-1:0] index, input [4:0] cpu_mode );
begin
        translate = index; // Avoid latch inference.

        case ( index )
                      0:      translate = PHY_USR_R0; 
                      1:      translate = PHY_USR_R1;                            
                      2:      translate = PHY_USR_R2; 
                      3:      translate = PHY_USR_R3;
                      4:      translate = PHY_USR_R4;
                      5:      translate = PHY_USR_R5;
                      6:      translate = PHY_USR_R6;
                      7:      translate = PHY_USR_R7;
                      8:      translate = PHY_USR_R8;
                      9:      translate = PHY_USR_R9;
                      10:     translate = PHY_USR_R10;
                      11:     translate = PHY_USR_R11;
                      12:     translate = PHY_USR_R12;
                      13:     translate = PHY_USR_R13;
                      14:     translate = PHY_USR_R14;
                      15:     translate = PHY_PC;
            RAZ_REGISTER:     translate = PHY_RAZ_REGISTER;
               ARCH_CPSR:     translate = PHY_CPSR;
          ARCH_CURR_SPSR:     translate = PHY_CPSR;
              ARCH_USR2_R8:   translate = PHY_USR_R8;
              ARCH_USR2_R9:   translate = PHY_USR_R9;
              ARCH_USR2_R10:  translate = PHY_USR_R10;
              ARCH_USR2_R11:  translate = PHY_USR_R11;
              ARCH_USR2_R12:  translate = PHY_USR_R12;
              ARCH_USR2_R13:  translate = PHY_USR_R13;
              ARCH_USR2_R14:  translate = PHY_USR_R14;
              ARCH_DUMMY_REG0:translate = PHY_DUMMY_REG0;
              ARCH_DUMMY_REG1:translate = PHY_DUMMY_REG1;
        endcase

        case ( cpu_mode )
                FIQ:
                begin
                        case ( index )
                                8:      translate = PHY_FIQ_R8;
                                9:      translate = PHY_FIQ_R9;
                                10:     translate = PHY_FIQ_R10;
                                11:     translate = PHY_FIQ_R11;
                                12:     translate = PHY_FIQ_R12;
                                13:     translate = PHY_FIQ_R13;
                                14:     translate = PHY_FIQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_FIQ_SPSR;
                        endcase
                end

                IRQ:
                begin
                        case ( index )
                                13:     translate = PHY_IRQ_R13;
                                14:     translate = PHY_IRQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_IRQ_SPSR;
                        endcase
                end

                ABT:
                begin
                        case ( index )
                                13:     translate = PHY_ABT_R13;
                                14:     translate = PHY_ABT_R14;
                    ARCH_CURR_SPSR:     translate = PHY_ABT_SPSR;
                        endcase
                end

                UND:
                begin
                        case ( index )
                                13:     translate = PHY_UND_R13;
                                14:     translate = PHY_UND_R14;
                    ARCH_CURR_SPSR:     translate = PHY_UND_SPSR;
                        endcase
                end

                SVC:
                begin
                        case ( index )
                                13:     translate = PHY_SVC_R13;
                                14:     translate = PHY_SVC_R14;
                    ARCH_CURR_SPSR:     translate = PHY_SVC_SPSR;
                        endcase
                end
        endcase
end
endfunction

endmodule
