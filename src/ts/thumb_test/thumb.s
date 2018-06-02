.text
.global _Reset

_Reset:
ldr sp, =#4000 
ldr r0, =myThumbFunction+1
mov lr, pc
bx r0
ldr r0, =#0xFFFFFFFF
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

