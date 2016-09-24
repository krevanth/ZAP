.global _Reset

// Set up an interrupt vector table.
_Reset   : b there
_Undef   : b asm_undef
_Swi     : b swi
_Pabt    : b pabt
_Dabt    : b dabt
reserved : b _Reset
irq      : b irq
fiq      : b fiq

asm_undef:
mov r13, #2000
stmfd r13!, {r0-r12, lr}
mov r0, #2
mov r1, #1
mov r2, #2
mov r3, #2
mov r4, #1
mov r5, #12
mov r6, #12
mov r7, #22
mov r8, #43
mov r9, #43
mov r10, #121
mov r11, #122
mov r12, #123
bl undef
ldmfd r13!, {r0-r12, pc}

there:
mov sp, #1000
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
mov r10, #11
mov r11, #12
mov r12, #13

// Make R10 and R11 = 13.
str r12, [sp]
ldr r11, [sp]
str r11, [sp]
ldr r10, [sp]

mcr p15, 0, r0, c7, c7, 0
b prog

here: b here

