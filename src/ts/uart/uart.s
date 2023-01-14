// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2022 Revanth Kamaraj (krevanth)              --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 3          --
// -- of the License, or (at your option) any later version.                  --
// --                                                                         --
// -- This program is distributed in the hope that it will be useful,         --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
// -- GNU General Public License for more details.                            --
// --                                                                         --
// -- You should have received a copy of the GNU General Public License       --
// -- along with this program; if not, write to the Free Software             --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
// -- 02110-1301, USA.                                                        --
// --                                                                         --
// -----------------------------------------------------------------------------

.set USER_STACK_POINTER, 0x00002000
.set IRQ_STACK_POINTER,  0x00003000
.set FIQ_STACK_POINTER,  0x00004000
.set VIC_BASE_ADDRESS,   0xFFFFFFA0

.text
.global _Reset
_Reset:

_Reset   : b there
_Undef   : b _Undef
_Swi     : b _Swi
_Pabt    : b _Pabt
_Dabt    : b _Dabt
reserved : b reserved
irq      : b sc_call
fiq      : b sc_call

/*
 * This handler simply revectors IRQs to
 * a dedicated irq_handler function. This
 * is a common routine for IRQ and FIQ.
 */
sc_call:
sub r14, r14, #4
stmfd sp!, {r0-r12, r14}
bl irq_handler
ldmfd sp!, {r0-r12, pc}^

there:
/* 
 * Switch to IRQ mode.
 * Set up stack pointer.
 */
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #18
msr cpsr_c, r2
ldr sp, =IRQ_STACK_POINTER

/* 
 * Switch to FIQ mode.
 * Setup up stack pointer.
 */
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #17
msr cpsr_c, r2
ldr sp, =FIQ_STACK_POINTER

/*
 * Switch to user mode with interrupts enabled.
 * Set up stack pointer.
 */
mrs r2, cpsr
bic r1, r1, #31
orr r1, r1, #16
bic r1, r1, #0xC0
msr cpsr_c, r1

/*
 * Unmask all interrupts in the VIC.
 */
ldr r0, =VIC_BASE_ADDRESS // VIC base address.
add r0, r0, #4            // Move to INT_MASK
mov r1, #0                // Prepare mask value
str r1, [r0]              // Unmask all interrupt sources.

/*
 * Then call the main function. The main function
 * will initiallize UART0 in TX and RX.
 */
ldr sp, =USER_STACK_POINTER
bl main
here: b here

