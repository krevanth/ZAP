module zap_coproc_decode
(
        input wire              i_clk,
        input wire              i_reset,

        // Stall signals
        

        input wire [31:0]       i_instruction,
        input wire              i_valid,

        input wire              i_irq,
        input wire              i_fiq,

         // Clear and stall signals.
        input wire              i_clear_from_writeback, // | High Priority
        input wire              i_data_stall,           // |
        input wire              i_clear_from_alu,       // |
        input wire              i_stall_from_shifter,   // |
        input wire              i_stall_from_issue,     // V Low Priority

        input wire              i_decode_dav_ff,
        input wire              i_issue_dav_ff,
        input wire              i_shift_dav_ff,
        input wire              i_alu_dav_ff,
        input wire              i_mem_dav_ff,

        input wire              i_copro_done,           // Coprocessor done.

        output reg              o_irq,
        output reg              o_fiq,

        output reg [31:0]       o_instruction,
        output reg              o_valid,

        output reg              o_stall_from_decode,

        output reg              o_copro_word_dav,
        output reg  [31:0]      o_copro_word            // The entire instruction is passed to the coprocessor.
);

localparam IDLE = 0;
localparam BUSY = 1;

reg state_ff, state_nxt;
reg cp_dav_nxt;
reg [31:0] cp_word_nxt;

always @*
begin
        cp_dav_nxt              = 1'd0;
        cp_word_nxt             = 32'd0;
        o_stall_from_decode     = 1'd0;
        o_instruction           = 32'd0;
        o_valid                 = 1'd0;
        state_nxt               = state_ff;
        o_irq                   = 1'd0;
        o_fiq                   = 1'd0;

        case ( state_ff )
        IDLE:
                casez (i_instruction)
                MRC, MCR:
                begin
                        // As long as there is an instruction to process
                        if ( i_decode_dav_ff || i_issue_dav_ff || 
                        i_shift_dav_ff || i_alu_dav_ff || i_mem_dav_ff )
                        begin
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd1;
                        end
                        else
                        begin
                                o_valid                 = 1'd0;
                                o_stall_from_decode     = 1'd0;
                                cp_word_nxt             = i_instruction,
                                cp_dav_nxt              = 1'd1;
                                state_nxt               = BUSY;
                        end
                end
                default:
                begin
                        // Remain transparent.
                        o_valid         = i_valid;
                        o_instruction   = i_instruction;
                        o_irq           = i_irq;
                        o_fiq           = i_fiq;
                end
                endcase

        BUSY:
        begin
                cp_word_nxt             = o_copro_word_ff;
                cp_dav_nxt              = o_copro_word_dav_ff;
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

        end
        else if ( i_stall_from_issue )
        begin

        end
        else
        begin
                state_ff     <= state_nxt;
                o_copro_word <= cp_word_nxt;
                o_copro_dav  <= cp_dav_nxt;
        end
end

task clear;
begin
                state_ff         <= IDLE;
                o_copro_word     <= 32'd0;
                o_copro_word_dav <= 1'd0; 
end
endtask

endmodule
