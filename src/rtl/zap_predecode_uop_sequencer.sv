//
// (C) 2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//
// This module sequences LDM/STM CISC instructions into simpler RISC
// instructions. Basically LDM -> LDRs and STM -> STRs. Supports a base
// restored abort model. Start instruction carries interrupt information
// so this cannot  block interrupts if there is a sequence of these.
//
// Also handles SWAP instruction but without atomicity preserving.
// The SWAP implementation is meant for SW compatibility and not for MP
//
// SWAP steps:
// - Read data from [Rn] into DUMMY. - LDR DUMMY0, [Rn]
// - Write data in Rm to [Rn]        - STR Rm, [Rn]
// - Copy data from DUMMY to Rd.     - MOV Rd, DUMMY0
//

module zap_predecode_uop_sequencer
(
        // Clock and reset.
        input logic              i_clk,                  // ZAP clock.
        input logic              i_reset,                // ZAP reset.

        // Instruction information from the fetch.
        input logic  [34:0]      i_instruction,
        input logic              i_instruction_valid,

        // Interrupt information from the fetch.
        input logic              i_irq,
        input logic              i_fiq,

        // CPSR
        input logic              i_cpsr_t,

        // L4 behavior.
        input   logic            i_l4_enable,

        // Pipeline control signals.
        input logic              i_clear_from_writeback,
        input logic              i_data_stall,
        input logic              i_clear_from_alu,
        input logic              i_stall_from_shifter,
        input logic              i_issue_stall,
        input logic              i_clear_from_decode,

        // Instruction output.
        output logic [39:0]       o_instruction,
        output logic              o_instruction_valid,
        output logic              o_align,
        output logic              o_switch,

        // We generate a stall.
        output logic              o_stall_from_decode,

        // Possibly masked interrupts.
        output logic              o_irq,
        output logic              o_fiq,

        // UOP last.
        output logic              o_uop_last
);

///////////////////////////////////////////////////////////////////////////////

`include "zap_defines.svh"
`include "zap_localparams.svh"

///////////////////////////////////////////////////////////////////////////////

// Instruction breakup
logic [3:0]  cc                  ;
logic [2:0]  id                  ;
logic        pre_index           ;
logic        up                  ;
logic        s_bit               ;
logic        writeback           ;
logic        load                ;
logic [3:0]  base                ;
logic [15:0] reglist             ;
logic        store               ;

logic          unused;
logic  [11:0]  oc_offset;                  // Ones counter offset.
logic  [15:0]  reglist_ff, reglist_nxt;    // Register list.
logic  [31:0]  const_ff, const_nxt;        // For BLX - const reg.

////////////////////////////////////////////////////////////////////////////////

assign {cc, id, pre_index, up, s_bit, writeback, load, base, reglist} = i_instruction[31:0];
assign store = ~load;
assign unused = |{pre_index};

///////////////////////////////////////////////////////////////////////////////

enum logic [20:0] {
        IDLE            = 1 << 0 ,
        MEMOP           = 1 << 1 ,
        WRITE_PC        = 1 << 2 ,
        SWAP1           = 1 << 3 ,
        SWAP2           = 1 << 4 ,
        LMULT_BUSY      = 1 << 5 ,
        BL_S1           = 1 << 6 ,
        BLX1_STATE_S0   = 1 << 7 ,
        BLX1_STATE_S1   = 1 << 8 ,
        BLX1_STATE_S2   = 1 << 9 ,
        BLX1_STATE_S3   = 1 << 10 ,
        BLX1_STATE_S4   = 1 << 11 ,
        BLX1_STATE_S5   = 1 << 12 ,
        BLX2_STATE_S0   = 1 << 13 ,
        LDRD_STRD_S0    = 1 << 14 ,
        LDRD_STRD_S1    = 1 << 15 ,
        LDR_TO_PC_S0    = 1 << 16 ,
        DEP_WAIT        = 1 << 17 ,
        DEP_WAIT_1      = 1 << 18 ,
        DEP_WAIT_2      = 1 << 19 ,
        DEP_WAIT_3      = 1 << 20 ,
        `ZAP_DEFAULT_XX
} state_ff, state_nxt;

///////////////////////////////////////////////////////////////////////////////

// Next state and output logic.
always_comb
begin:next_state_logic_and_output_logic

        // ========================================
        // Default Value Section
        // (Done to avoid combo loops/incomplete assignments)
        // ========================================

        const_nxt = const_ff;

        // Block interrupts by default.
        o_irq = 0;
        o_fiq = 0;

        // Align zero.
        o_align = 0;

        state_nxt               = state_ff;
        o_instruction           = {5'd0, i_instruction};
        o_instruction_valid     = i_instruction_valid;
        reglist_nxt             = reglist_ff;
        o_stall_from_decode     = 1'd0;
        o_switch                = 0;

        // =========================================
        // Code Section
        // =========================================

        case ( state_ff )
                LDR_TO_PC_S0:
                begin
                        o_stall_from_decode = 1'd0;
                        o_instruction_valid = 1'd1;

                        // MOV PC, ARCH_DUMMY_REG0
                        o_instruction[31:0] = { cc, 2'b00, 1'd0, MOV, 1'd0, 4'd0, ARCH_PC, 12'd0 };
                        {o_instruction[ZAP_DP_RB_EXTEND], o_instruction[`ZAP_DP_RB]}
                                      = ARCH_DUMMY_REG0;

                        o_irq = 1'd0;
                        o_fiq = 1'd0;

                        state_nxt = IDLE;
                end

                BLX1_STATE_S0: // SCONST = ($signed(constant) << 2) + ( H(i.e., [24]) << 1 ))
                begin
                        o_stall_from_decode = 1'd1;

                        const_nxt = ( { {8{i_instruction[23]}} , i_instruction[23:0] } << 2 ) +
                                    ( {31'd0, i_instruction[24]} << 1 );

                        // MOV DUMMY0, SCONST[7:0] ror 0
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, MOV, 1'd0, 4'd0, 4'd0, 4'd0, const_nxt[7:0]};
                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]} = ARCH_DUMMY_REG0;

                        state_nxt = BLX1_STATE_S1;
                end

                // The 3 states here try to build up a constant in the internal register using immediate+rotates.
                // ROR x, y = x >> y | x << (32 - y)

                BLX1_STATE_S1:
                begin
                        o_stall_from_decode = 1'd1;

                        // ORR DUMMY0, DUMMY0, SCONST[15:8]  ror 12*2
                        o_instruction[31:0] = {AL, 2'b00, 1'b1, ORR, 1'd0, 4'd0, 4'd0, 4'd12, const_nxt[15:8]};
                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]} = ARCH_DUMMY_REG0;
                        {o_instruction[ZAP_DP_RA_EXTEND], o_instruction[`ZAP_DP_RA]} = ARCH_DUMMY_REG0;

                        state_nxt = BLX1_STATE_S2;
                end

                BLX1_STATE_S2:
                begin
                        o_stall_from_decode = 1'd1;

                        // ORR DUMMY0, DUMMY0, SCONST[23:16] ror 8*2
                         o_instruction[31:0] = {AL, 2'b00, 1'b1, ORR, 1'd0, 4'd0, 4'd0, 4'd8, const_nxt[23:16]};
                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]} = ARCH_DUMMY_REG0;
                        {o_instruction[ZAP_DP_RA_EXTEND], o_instruction[`ZAP_DP_RA]} = ARCH_DUMMY_REG0;

                        state_nxt = BLX1_STATE_S3;
                end

                BLX1_STATE_S3:
                begin
                        o_stall_from_decode = 1'd1;

                        // ORR DUMMY0, DUMMY0, SCONST[31:24] ror 4*2
                         o_instruction[31:0] = {AL, 2'b00, 1'b1, ORR, 1'd0, 4'd0, 4'd0, 4'd4, const_nxt[31:24]};
                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]} = ARCH_DUMMY_REG0;
                        {o_instruction[ZAP_DP_RA_EXTEND], o_instruction[`ZAP_DP_RA]} = ARCH_DUMMY_REG0;

                        state_nxt = BLX1_STATE_S4;
                end

                BLX1_STATE_S4:
                begin
                        o_stall_from_decode = 1'd1;

                        // ORR DUMMY0, DUMMY0, 1 - Needed to indicate a switch
                        // to mode16 if needed.
                         o_instruction[31:0] = {AL, 2'b00, 1'b1, ORR, 1'd0, 4'd0, 4'd0, 4'd0, !i_cpsr_t ? 8'd1 : 8'd0};
                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]} = ARCH_DUMMY_REG0;
                        {o_instruction[ZAP_DP_RA_EXTEND], o_instruction[`ZAP_DP_RA]} = ARCH_DUMMY_REG0;

                        state_nxt = BLX1_STATE_S5;
                end

                BLX1_STATE_S5:
                begin
                        // Remove stall.
                        o_stall_from_decode = 1'd0;

                        // BX DUMMY0
                        o_instruction = {8'd0, 32'hE12FFF10};
                        {o_instruction[ZAP_DP_RB_EXTEND], o_instruction[`ZAP_DP_RB]} = ARCH_DUMMY_REG0;

                        state_nxt = IDLE;
                end

                BLX2_STATE_S0:
                begin
                        // Remove stall.
                        o_stall_from_decode     = 1'd0;

                        // BX Rm. Just remove the L bit. Conditional is passed
                        // on.
                        o_instruction           = {5'd0, i_instruction};
                        o_instruction[5]        = 1'd0;

                        state_nxt               = IDLE;
                end

                LDRD_STRD_S0:
                begin
                        o_stall_from_decode = 1'd0;

                        o_instruction[31:28] = i_instruction[31:28];
                        o_instruction[27:26] = 2'b01;
                        o_instruction[15:12] = i_instruction[15:12] + 1;
                        o_instruction[24:23] = i_instruction[24:23];
                        o_instruction[19:16] = i_instruction[19:16];
                        o_instruction[22]    = 1'd0;

                        // If writeback was specified, generate LDR Rdata, [Raddress, #4] for the next load.
                        // Make it pre-indexing without writeback in this case.
                        if ( i_instruction[21] )
                        begin
                                o_instruction[11:0] = 12'd4;
                                o_instruction[25]   = 1'd1;
                                o_instruction[21]   = 1'd0;
                        end
                        else // No writeback.
                        begin
                                if ( i_instruction[22] )
                                begin
                                        // If no writeback was specified, issue +4 to immediate (for I mode) for the next
                                        // address.
                                        o_instruction[11:0]  = o_instruction[11:0] + 12'd4;
                                        o_instruction[25]    = 1'd1;
                                        state_nxt            = IDLE;
                                end
                                else
                                begin

                                        // If no writeback was specified and in register mode, issue + 4 to the register.
                                        // This requires the register to be temporarily added by 4.
                                        // 1.
                                        // Generate ADDAL ARCH_DUMMY_REG0, Register, #4

                                        o_instruction[31:0] =
                                        {AL, 2'b00, 1'b1, ADD, 1'd0, 4'd0, i_instruction[19:16], 12'd4};

                                        {o_instruction[ZAP_DP_RD_EXTEND], o_instruction[`ZAP_DP_RD]}= ARCH_DUMMY_REG0;

                                        state_nxt = LDRD_STRD_S1;

                                        o_stall_from_decode = 1'd1;

                                end
                        end

                        if ( i_instruction[6:5] == 2'b11 )
                        begin
                                o_instruction[20] = 1'd0;       // Store
                        end
                        else
                        begin
                                o_instruction[20] = 1'd1;       // Load
                        end
                end

                LDRD_STRD_S1:
                begin
                        o_stall_from_decode  = 1'd0;
                        o_instruction[31:28] = i_instruction[31:28];

                        // Use arch dummy reg0 as the base address since it was incremented by 4.
                        o_instruction[15:12] = i_instruction[15:12] + 1;
                        o_instruction[27:26] = 2'b01;
                        o_instruction[25]    = 1'd0;
                        o_instruction[11:0]  = i_instruction[11:0];
                        o_instruction[24:23] = i_instruction[24:23];
                        o_instruction[22]    = 1'd0;
                        o_instruction[21]    = i_instruction[21];
                        o_instruction[15:12] = i_instruction[15:12];
                        {o_instruction[ZAP_DP_RA_EXTEND], o_instruction[`ZAP_DP_RA]} = ARCH_DUMMY_REG0;

                        if ( i_instruction[6:5] == 2'b11 )
                        begin
                                o_instruction[20] = 1'd0;       // Store
                        end
                        else
                        begin
                                o_instruction[20] = 1'd1;       // Load
                        end

                        state_nxt = IDLE;
                end

                // Issue ANDEQ R0, R0, R0 - block interrupts.
                DEP_WAIT, DEP_WAIT_1, DEP_WAIT_2:
                begin
                        o_stall_from_decode = 1'd1;
                        o_instruction       = '0;
                        state_nxt           =
                                state_ff == DEP_WAIT   ? DEP_WAIT_1 :
                                state_ff == DEP_WAIT_1 ? DEP_WAIT_2 :
                                state_ff == DEP_WAIT_2 ? DEP_WAIT_3 :
                                state_ff;

                end

                // Issue ANDEQ R0, R0, R0 - block interrupts.
                DEP_WAIT_3:
                begin
                        o_stall_from_decode = 1'd0;
                        o_instruction       = '0;
                        state_nxt           = IDLE;
                end

                IDLE:
                begin
                        // CLZ and saturating instruction - gap the issue.
                        if (
                               (i_instruction[31:0] ==? CLZ_INSTRUCTION ||
                                i_instruction[31:0] ==? QADD            ||
                                i_instruction[31:0] ==? QSUB            ||
                                i_instruction[31:0] ==? QDADD           ||
                                i_instruction[31:0] ==? QDSUB)          &&
                                i_instruction_valid
                        )
                        begin
                                state_nxt           = DEP_WAIT;
                                o_stall_from_decode = 1'd1;
                                o_instruction       = {5'd0, i_instruction};
                                o_irq               = i_irq;
                                o_fiq               = i_fiq;
                        end
                        // Instruction in coprocessor space.
                        else if (
                             (i_instruction[31:0] ==? MRC   ||
                              i_instruction[31:0] ==? MCR   ||
                              i_instruction[31:0] ==? LDC   ||
                              i_instruction[31:0] ==? STC   ||
                              i_instruction[31:0] ==? CDP   ||
                              i_instruction[31:0] ==? MCR2  ||
                              i_instruction[31:0] ==? LDC2  ||
                              i_instruction[31:0] ==? STC2) &&
                              i_instruction_valid
                        )
                        begin
                                o_instruction_valid = 1'd0;
                        end
                        // LDRD and STRD. First reg should be EVEN.
                        else if
                            ( i_instruction[27:25] == 3'b000                                &&
                             i_instruction[20]    == 1'd0                                   &&
                             ( i_instruction[6:5] == 2'b10 || i_instruction[6:5] == 2'b11 ) &&
                             i_instruction[12]    == 1'd0                                   &&
                             i_instruction[7]     == 1'd1                                   &&
                             i_instruction[4]     == 1'd1                                   &&
                             i_instruction_valid )
                        begin
                                // If writeback is specified, the address of the second load is the writeback value
                                // with 4 added to it. The written back value holds the result of executing the
                                // first load.
                                //
                                // If writeback is not specified, the address of the second load is 4 more than the
                                // address of the first load.

                                o_stall_from_decode = 1'd1;

                                o_instruction[27:26] = 2'b01;  // Make it an classic load-store.

                                // Specify addressing mode.
                                if ( i_instruction[22] ) // Immediate.
                                begin
                                        o_instruction[25]    = 1'd1;
                                        o_instruction[11:0]  = $signed({i_instruction[11],
                                                                        i_instruction[11],
                                                                        i_instruction[11],
                                                                        i_instruction[11],
                                                                        i_instruction[11:8],
                                                                        i_instruction[3:0]});
                                end
                                else
                                begin
                                        o_instruction[25]    = 1'd0;
                                        o_instruction[11:0]  = i_instruction[11:0];
                                end

                                o_instruction[24:23] = i_instruction[24:23];
                                o_instruction[22]    = 1'd0;
                                o_instruction[21]    = i_instruction[21];

                                // Load or Store.
                                if ( i_instruction[6:5] == 2'b11 )
                                begin
                                        o_instruction[20] = 1'd0;       // Store
                                end
                                else
                                begin
                                        o_instruction[20] = 1'd1;       // Load
                                end

                                o_instruction[19:12] = i_instruction[19:12];

                                state_nxt            = LDRD_STRD_S0;

                                // Fine to give IRQs.
                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                        // BLX1 detected. Unconditional!!!
                        // Immediate Offset.
                        else if ( i_instruction[31:25] == BLX1[31:25] && i_instruction_valid )
                        begin
                                // We must generate a SUBAL LR,PC,4 ROR 0
                                // This makes LR have the value
                                // PC+8-4=PC+4 which is the address of
                                // the next instruction. This is in 32bit mode.
                                o_instruction[31:0]           = {AL, 2'b00, 1'b1, SUB, 1'd0, 4'd15, 4'd14, 12'd4};

                                // In mode16 mode, we must generate PC+4-2. Modify it.
                                if ( i_cpsr_t )
                                begin
                                        o_instruction[11:0] = 12'd2; // Modify the instruction.
                                end

                                o_stall_from_decode     = 1'd1; // Stall the core.
                                state_nxt               = BLX1_STATE_S0;

                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                        // BLX2 detected. Register offset. CONDITIONAL.
                        else if ( i_instruction[27:4] == BLX2[27:4] && i_instruction_valid )
                        begin
                                // Write address of next instruction to LR. Now this
                                // depends on the mode we're in. Mode in the sense
                                // 16/32bit. We need to look at i_cpsr_t.

                                // We need to generate a SUBcc LR,PC,4 ROR 0
                                // to store the next instruction address in
                                // LR. This is in 32bit mode.
                                o_instruction[31:0]     =
                                {i_instruction[31:28], 2'b00, 1'b1, SUB, 1'd0, 4'd15, 4'd14, 12'd4};

                                // In mode16 mode, we need to remove 2 from PC
                                // instead of 4. Modify it.
                                if ( i_cpsr_t )
                                begin
                                        o_instruction[11:0] = 12'd2; // modify instr.
                                end

                                o_stall_from_decode     = 1'd1; // Stall the core.
                                state_nxt               = BLX2_STATE_S0;

                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                        // LDM/STM detected...
                        else if ( id == 3'b100 && i_instruction_valid )
                        begin
                                // Backup base register.
                                // MOV DUMMY0, Base
                                if ( up )
                                begin
                                        o_instruction[31:0] = {cc, 2'b00, 1'b0, MOV,
                                                 1'b0, 4'd0, 4'd0, 8'd0, base};

                                        {o_instruction[ZAP_DP_RD_EXTEND],
                                         o_instruction[`ZAP_DP_RD]}
                                                = ARCH_DUMMY_REG0;
                                end
                                else
                                begin
                                        // SUB DUMMY0, BASE, OFFSET
                                        o_instruction[31:0] = {cc, 2'b00, 1'b1, SUB,
                                                  1'd0, base, 4'd0, oc_offset};

                                        {o_instruction[ZAP_DP_RD_EXTEND],
                                         o_instruction[`ZAP_DP_RD]} =
                                                ARCH_DUMMY_REG0;
                                end

                                o_instruction_valid = 1'd1;
                                reglist_nxt         = reglist;

                                state_nxt = MEMOP;
                                o_stall_from_decode = 1'd1;

                                // Take interrupt on this.
                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                        else if ( i_instruction[31:0] ==? SWAP && i_instruction_valid ) // SWAP
                        begin
                                o_irq = i_irq;
                                o_fiq = i_fiq;

                                // dummy = *(rn) - LDR ARCH_DUMMY_REG0, [rn, #0]
                                state_nxt = SWAP1;

                                o_instruction[31:0]  = {cc, 3'b010, 1'd1, 1'd0,
                                i_instruction[22], 1'd0, 1'd1,
                                i_instruction[19:16], 4'b0000, 12'd0};
                                // The 0000 is replaced with dummy0 below.

                                {o_instruction[ZAP_SRCDEST_EXTEND],
                                 o_instruction[`ZAP_SRCDEST]} = ARCH_DUMMY_REG0;

                                o_instruction_valid = 1'd1;
                                o_stall_from_decode = 1'd1;
                        end
                        else if ( i_instruction[27:23] == 5'd1    &&
                                  i_instruction[7:4]   == 4'b1001 &&
                                  i_instruction_valid )
                        begin
                                 // LMULT
                                 state_nxt           = LMULT_BUSY;
                                 o_stall_from_decode = 1'd1;
                                 o_irq               = i_irq;
                                 o_fiq               = i_fiq;
                                 o_instruction       = {5'd0, i_instruction};
                                 o_instruction_valid = i_instruction_valid;
                        end
                        else if (  i_instruction[27:23] == 5'b00010 &&
                                   i_instruction[22:21] == 2'b10    &&
                                  !i_instruction[20]                &&
                                   i_instruction[7] && i_instruction[4] )
                        begin
                                // LMULT
                                state_nxt = LMULT_BUSY;
                                o_stall_from_decode = 1'd1;
                                o_irq = i_irq;
                                o_fiq = i_fiq;
                                o_instruction = {5'd0, i_instruction};
                                o_instruction_valid = i_instruction_valid;
                        end
                        else if ( i_instruction[27:25] == 3'b101 &&
                                  i_instruction[24] && i_instruction_valid ) // BL.
                        begin
                                // Move to new state. In that state, we will
                                // generate a plain branch.
                                state_nxt = BL_S1;

                                // PC will stall preventing the fetch from
                                // presenting new data.
                                o_stall_from_decode = 1'd1;

                                if ( i_cpsr_t == 1'd0 ) // 32bit mode
                                begin
                                        // PC is 8 bytes ahead.
                                        // Craft a SUB LR, PC, 4.
                                        o_instruction[31:0] = {i_instruction[31:28],
                                                         28'h24FE004};
                                end
                                else
                                begin
                                        // PC is 4 bytes ahead...
                                        // Craft a SUB LR, PC, 1 so that return
                                        // goes to the next 16bit instruction
                                        // and making LSB of LR = 1.
                                         o_instruction[31:0] = {i_instruction[31:28],
                                                                28'h24FE001};
                                end

                                // Sell it as a valid instruction
                                o_instruction_valid = 1;

                                // Allow interrupts to pass
                                o_irq = i_irq;
                                o_fiq = i_fiq;
                        end
                        else if ( (i_instruction[31:0] ==? LS_INSTRUCTION_SPECIFIED_SHIFT ||
                                   i_instruction[31:0] ==? LS_IMMEDIATE)                  &&
                                   i_instruction[15:12] == ARCH_PC                        &&
                                   i_instruction[20] )
                        // Load to PC. First load to local, then to PC.
                        begin
                                o_irq = i_irq;
                                o_fiq = i_fiq;

                                o_stall_from_decode = 1'd1;
                                o_instruction_valid = 1'd1;
                                {o_instruction[ZAP_SRCDEST_EXTEND], o_instruction[`ZAP_SRCDEST]}
                                 = ARCH_DUMMY_REG0;

                                state_nxt = LDR_TO_PC_S0;
                        end
                        else
                        begin
                                // Be transparent.
                                state_nxt               = state_ff;
                                o_stall_from_decode     = 1'd0;
                                o_instruction           = {5'd0, i_instruction};
                                o_instruction_valid     = i_instruction_valid;
                                reglist_nxt             = 16'd0;

                                // Allow interrupts to pass.
                                o_irq                   = i_irq;
                                o_fiq                   = i_fiq;
                        end
                end

                BL_S1:
                begin
                        // Launch out the original instruction clearing the
                        // link bit. This is like MOV PC, <Whatever>
                        o_instruction       = {5'd0, i_instruction} & ~(1 << 24);
                        o_instruction_valid = i_instruction_valid;

                        // Move to IDLE state.
                        state_nxt       =       IDLE;

                        // Free the fetch from your clutches.
                        o_stall_from_decode = 1'd0;

                        // Continue to silence interrupts.
                        o_irq           = 0;
                        o_fiq           = 0;
                end

                LMULT_BUSY:
                begin
                        o_irq                   = 0;
                        o_fiq                   = 0;
                        o_instruction           = {5'd1, i_instruction};  // Select upper.
                        o_instruction_valid     = i_instruction_valid;
                        o_stall_from_decode     = 1'd0;
                        state_nxt               = IDLE;
                end

                SWAP1:
                begin
                        // STR Rm, [Rn, #0]
                        o_irq = 0;
                        o_fiq = 0;

                        o_stall_from_decode = 1'd1;
                        o_instruction_valid = 1;
                        o_instruction[31:0] = {cc, 3'b010, 1'd1, 1'd0,
                                        i_instruction[22], 1'd0, 1'd0,
                                        i_instruction[19:16],
                                        i_instruction[3:0], 12'd0}; // BUG FIX

                        state_nxt = SWAP2;
                end

                SWAP2:
                begin:SWP2BLK
                        // MOV Rd, DUMMY0
                        o_stall_from_decode = 1'd0;
                        o_instruction_valid = 1'd1;

                        o_irq = 0;
                        o_fiq = 0;

                        o_instruction[31:0] = {cc, 2'b00, 1'd0, MOV, 1'd0, 4'b0000,
                                         i_instruction[15:12], 12'd0}; // ALU src doesn't matter.

                        {o_instruction[ZAP_DP_RB_EXTEND], o_instruction[`ZAP_DP_RB]}
                                        = ARCH_DUMMY_REG0;

                        state_nxt = IDLE;
                end

                MEMOP:
                begin

                        // Memory operations happen here.

                        reglist_nxt = reglist_ff & ~(16'd1 << pri_enc(reglist_ff));

                        o_irq = 0;
                        o_fiq = 0;

                        // The map function generates a base restore
                        // instruction if reglist = 0.
                        o_instruction[33:0] = map ( i_instruction[31:0], pri_enc(reglist_ff), reglist_ff );
                        o_instruction_valid = 1'd1;

                        if ( o_instruction[27:26] == 2'b01 )
                        begin
                                o_align = 1;
                        end

                        if ( reglist_ff == 0 )
                        begin
                                if ( i_instruction[{2'd0, ARCH_PC}] && load )
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

                // If needed, we finally write to the program counter as
                // either a MOV PC, LR or MOVS PC, LR.
                WRITE_PC:
                begin
                        // MOV(S) PC, ARCH_DUMMY_REG1
                        state_nxt = IDLE;
                        o_stall_from_decode = 1'd0;

                        if ( i_l4_enable == 1'd0 )
                        begin
                                o_switch = 1;
                        end

                        o_instruction[31:0] =
                        { cc, 2'b00, 1'd0, MOV, s_bit, 4'd0, ARCH_PC,
                                                                8'd0, 4'd0 };

                        {o_instruction[ZAP_DP_RB_EXTEND], o_instruction[`ZAP_DP_RB]}
                                        = ARCH_DUMMY_REG1;

                        o_instruction_valid = 1'd1;
                        o_irq = 0;
                        o_fiq = 0;
                end

                // ========================================
                // Default Section (To Simplify Synthesis)
                // ========================================

                default:
                begin
                        state_nxt = XX;

                        {const_nxt
                        ,o_stall_from_decode
                        ,o_irq
                        ,o_fiq
                        ,o_instruction
                        ,o_instruction_valid
                        ,reglist_nxt
                        ,o_switch
                        ,o_align
                        } = 'x;
                end
        endcase
end

// Debug only.
assign o_uop_last = (((state_ff == IDLE) && (state_nxt == IDLE)) ||
                     ((state_ff != IDLE) && (state_nxt == IDLE))) &&
                     o_instruction_valid;

///////////////////////////////////////////////////////////////////////////////

// map[24] == 0 : post index.
function automatic [33:0] map ( input [31:0] instr, input [3:0] enc, input [15:0] list );
begin
        // Default.
        map     = {2'd0, instr};    // map = instr.

        // Override various fields.
        map[22]           =  1'd0;
        map[25]           =  1'd0;
        map[23]           =  1'd1;             // Hardcoded to increment.
        map[11:0]         =  12'd4;            // Offset
        map[27:26]        =  2'b01;            // Memory instruction.
        map[`ZAP_SRCDEST] =  enc;

       {map[ZAP_BASE_EXTEND],
        map[`ZAP_BASE]}   = ARCH_DUMMY_REG0;  // Use as base register.

        map[24] ^= !up;     // If not up, then DA -> IB and DB -> IA.
        map[21]  = map[24]; // If post index, writeback is implicit (map[21]=0).

        if ( list == 0 ) // Catch 0 list here itself...
        begin
                // Restore base. MOV Rbase, DUMMY0
                if ( writeback )
                begin
                        if ( up ) // Original instruction asked increment.
                        begin
                                map =
                                { 2'd0, cc, 2'b0, 1'b0, MOV, 1'b0, 4'd0,
                                                       base, 8'd0, 4'd0 };

                                {map[ZAP_DP_RB_EXTEND],map[`ZAP_DP_RB]} =
                                 ARCH_DUMMY_REG0;
                        end
                        else
                        begin   // Restore.
                                // SUB BASE, BASE, #OFFSET
                                map = { 2'd0, cc, 2'b00, 1'b1, SUB,
                                        1'd0, base, base, oc_offset};
                        end
                end
                else
                begin
                        map = 34'd0; // Wasted cycle.
                end
        end
        else if ( (store && s_bit) || (load && s_bit && !list[15]) )
        // STR with S bit or LDR with S bit and no PC - force user bank access.
        begin
                        case ( map[`ZAP_SRCDEST] ) // Force user bank.
                        8: {map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R8;
                        9: {map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R9;
                        10:{map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R10;
                        11:{map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R11;
                        12:{map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R12;
                        13:{map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R13;
                        14:{map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_USR2_R14;
                        default:; // Propagate map as usual.
                        endcase
        end
        else if ( load && enc == 4'd15  )
        //
        // Load with PC in register list. Load to dummy register.
        // Will never use user bank.
        //
        begin
                        //
                        // If S = 1, perform an atomic return.
                        // If S = 0, just write to PC i.e., a jump.
                        //
                        // For now, load to ARCH_DUMMY_REG1.
                        //
                        {map[ZAP_SRCDEST_EXTEND],map[`ZAP_SRCDEST]} = ARCH_DUMMY_REG1;
        end
end
endfunction : map

///////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge i_clk)
begin
        if      ( i_reset )
        begin
                state_ff                <= IDLE;
                reglist_ff              <= {16{1'dx}};
                const_ff                <= {32{1'dx}};
        end
        else if
        (
                  i_clear_from_writeback                 ||
                ( i_clear_from_alu    && !i_data_stall ) ||
                ( i_clear_from_decode && !i_stall_from_shifter && !i_issue_stall && !i_data_stall )
        )
        begin
                state_ff                <= IDLE;
                reglist_ff              <= {16{1'dx}};
                const_ff                <= {32{1'dx}};
        end
        else if ( !i_stall_from_shifter && !i_issue_stall && !i_data_stall )
        begin
                state_ff   <= state_nxt;
                reglist_ff <= reglist_nxt;
                const_ff   <= const_nxt;
        end
end

////////////////////
// Ones Counter
////////////////////

zap_ones_counter u_zap_ones_counter (
    .o_ones_counter(oc_offset),
    .i_word(i_instruction[15:0])
);

////////////////////
// Functions
////////////////////

// Priority encoder. Bit 0 is prioritized.
function automatic  [3:0] pri_enc ( input [15:0] in );
                casez ( in )
                16'b????_????_????_???1: pri_enc = 4'd0;
                16'b????_????_????_??10: pri_enc = 4'd1;
                16'b????_????_????_?100: pri_enc = 4'd2;
                16'b????_????_????_1000: pri_enc = 4'd3;
                16'b????_????_???1_0000: pri_enc = 4'd4;
                16'b????_????_??10_0000: pri_enc = 4'd5;
                16'b????_????_?100_0000: pri_enc = 4'd6;
                16'b????_????_1000_0000: pri_enc = 4'd7;
                16'b????_???1_0000_0000: pri_enc = 4'd8;
                16'b????_??10_0000_0000: pri_enc = 4'd9;
                16'b????_?100_0000_0000: pri_enc = 4'hA;
                16'b????_1000_0000_0000: pri_enc = 4'hB;
                16'b???1_0000_0000_0000: pri_enc = 4'hC;
                16'b??10_0000_0000_0000: pri_enc = 4'hD;
                16'b?100_0000_0000_0000: pri_enc = 4'hE;
                16'b1000_0000_0000_0000: pri_enc = 4'hF;
                default:                 pri_enc = 4'h0;
                endcase
endfunction : pri_enc

///////////////////////
// Assertions
///////////////////////

always @ ( posedge i_clk ) // Assertion.
begin
        if ( state_ff == IDLE && state_nxt == MEMOP && !i_reset )
        begin
                assert ( reglist_nxt != 'd0 ) else
                $info("Warning: Empty reglist leads to UNPREDICTABLE behavior.");

                assert ( base != 'd15 ) else
                $info("Warning: Using R15 as a base in LDM/STM leads to UNPREDICTABLE behavior.");

                assert ( ~(!i_instruction[20] && reglist_nxt[15] ) ) else
                $info("Warning: Using R15 in the reglist of STM leads to IMPLEMENTATION DEFINED (PC + 8) value stored.");

                for(int i=0;i<16;i++)
                begin
                        // Get first register accessed.
                        if( reglist_nxt[i] )
                        begin
                                // Never: HAVE BASE AS REGLIST && BASE NOT AS FIRST REGISTER.
                                assert ( ~(reglist_nxt[base] && base != i[3:0]) ) else
                                $info("Warning: Specifying base in non-trailing bit is UNPREDICTABLE.");

                                break;
                        end
                end
        end
end

endmodule : zap_predecode_uop_sequencer

// ----------------------------------------------------------------------------
// END OF FILE
// ----------------------------------------------------------------------------
