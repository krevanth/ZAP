.global _Reset

// Set up an interrupt vector table.
_Reset   : b there
_Undef   : b __undef
_Swi     : b __swi
_Pabt    : b __pabt
_Dabt    : b __dabt
reserved : b _Reset
irq      : b IRQ
fiq      : b __fiq

IRQ:
add sp, sp, #1
subs pc, lr, #4

there:
// Enable interrupts.
mrs r1, cpsr
bic r1, r1, #0x80
msr cpsr_c, r1

// Disable interrupts
mrs r1, cpsr
orr r1, r1, #0x80
msr cpsr_c, r1

// Switch mode.
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #16
msr cpsr_c, r2

mov sp, #8000

// Enable interrupts.
mrs r1, cpsr
bic r1, r1, #0x80
msr cpsr_c, r1

// Run main loop.
bl factorial
here: b here

