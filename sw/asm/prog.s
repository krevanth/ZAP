.global _Reset

// Set up an interrupt vector table.
_Reset   : b there
_Undef   : b __undef
_Swi     : b SWI
_Pabt    : b __pabt
_Dabt    : b __dabt
reserved : b _Reset
irq      : b IRQ
fiq      : b __fiq

IRQ:
sub r14, r14, #4
stmfd sp!, {r0-r12, r14}
mov r0, #1
mov r1, #2
mov r2, #3
mov r3, #4
mov r4, #5
mov r5, #6
mov r6, #7
mov r7, #8
mov r8, #9
mov r9, #10
mov r10, #12
mov r11, #13
mov r12, #14
mov r14, #15
ldmfd sp!, {r0-r12, pc}^

SWI:
ldr sp,=#700
stmfd sp!, {r0-r12, r14}
mrs r1, spsr
orr r1, r1, #0x80
msr spsr_c, r1
ldmfd sp!, {r0-r12, pc}^

there:
// Switch to IRQ mode.
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #18 
msr cpsr_c, r2
ldr sp, =#800

// Enable interrupts.
mrs r1, cpsr
bic r1, r1, #0x80
msr cpsr_c, r1

// Switch mode.
mrs r2, cpsr
bic r2, r2, #31
orr r2, r2, #16
msr cpsr_c, r2
mov sp, #1000

// Run main loop.
bl factorial
swi #0x00
here: b here

