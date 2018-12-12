.text
.global _Reset
.set SP_INIT, 4000
.set R0_FINAL_VALUE, 0xFFFFFFFF

_Reset:
ldr sp, =SP_INIT
ldr r0, =myThumbFunction+1
mov lr, pc
bx r0 // Jump to Thumb code
ldr r0, =R0_FINAL_VALUE
here: b here

.thumb_func
myThumbFunction:

mov r0, #10
mov r1, #10
mov r2, #10
mov r3, #10
mov r4, #10
mov r5, #10
mov r6, #10
mov r7, #10

bx lr

