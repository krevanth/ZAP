// 
//  This is a creation of the Laboratory of Processor Architecture
//  of Ecole Polytechnique Fédérale de Lausanne ( http://lap.epfl.ch )
// 
//  Test program which uses all the instruction set to be assembled with GCC assembler
// 
//  Written By -  Jonathan Masur and Xavier Jimenez (2013)
//                Revanth Kamaraj                   (2016-2022)
// 
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; either version 2, or (at your option) any
//  later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  In other words, you are welcome to use, share and improve this program.
//  You are forbidden to forbid anyone else to use, share and improve
//  what you give them.   Help stamp out software-hoarding!
// 

.text
.global test_cond, test_fwd, test_bshift, test_logic, test_adder, test_bshift_reg, test_load
.global test_store, test_byte, test_cpsr, test_mul, test_ldmstm, test_r15jumps, test_rti
.global test_clz, test_sat

_Reset:
       b enable_cache

// ------------------------------
// CONSTANT POOL
// ------------------------------

.word 4100
.word 16380
.word 0xFFF00002
.word 4101 
.word 0x7fffffff
.word 0xffffffff

enable_cache:
   // Enable cache (Uses a single bit to enable both caches).
   .set ENABLE_CP_WORD, 4100
   mov r0, #4
   ldr r1, [r0]
   mcr p15, 0, r1, c1, c1, 0
   
   // Write out identitiy section mapping. Write 16KB to register 2.
   mov r1, #1
   mov r1, r1, lsl #14
   mcr p15, 0, r1, c2, c0, 1
   
   // Set domain access control to all 1s.
   mvn r1, #0
   mcr p15, 0, r1, c3, c0, 0
   
   // Set up a section desctiptor for identity mapping that is Cachaeable.
   mov r1, #1
   mov r1, r1, lsl #14     // 16KB
   mov r2, #14             // Cacheable identity descriptor.
   str r2, [r1]            // Write identity section desctiptor to 16KB location.
   ldr r6, [r1]            // R6 holds the descriptor.
   mov r7, r1              // R7 holds the address.
   
   // Set up a section descriptor for upper 1MB of virtual address space.
   // This is identity mapping. Uncacheable.
   mov r1, #1
   mov r1, r1, lsl #14     // 16KB. This is descriptor 0.
   
   // Go to descriptor 4095. This is the address BASE + (#DESC * 4).
   .set DESCRIPTOR_IO_SECTION_OFFSET, 16380 // 4095 x 4
   mov r0, #8
   ldr r2,[r0]
   add r1, r1, r2
   
   // Prepare a descriptor. Descriptor = 0xFFF00002 (Uncacheable section descriptor).
   .set DESCRIPTOR_IO_SECTION, 0xFFF00002
   mov r0, #0xC
   ldr r2 ,[r0]
   str r2, [r1]
   ldr r6, [r1]
   mov r7, r1
   
   // ENABLE MMU
   .set ENABLE_MMU_CP_WORD, 4101
   mov r0, #0x10
   ldr r1, [r0]
   mcr p15, 0, r1, c1, c1, 0

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

disable_cache:

        msr cpsr, #0x1f         @ Enter SYS mode.

        // Check if unaligned loads work.
       mov r0, #4
       ldr r1, [r0, #2]
       ldr r2, [r0]
       mov r2, r2, ror #16
       cmp r1, r2
       bne _Reset

// Must check TEQ first.
fail_teq:
        mov r0, #1
        teq r0, #0
        swieq #0xFF
        beq fail_teq
        teq r0, #1
        bne fail_teq
        
        bl test_sat

fail_sat:
        teq r0, #0
        mov r1, #0
        bne fail_sat

        bl test_clz
fail0:
        teq r0, #0
        mov r1, #0
        bne fail0

        bl test_cond
fail1:
        teq r0, #0
        mov r1, #1
        bne fail1

        bl test_fwd
fail2:
        teq r0, #0
        mov r1, #2
        bne fail2

        bl test_bshift
fail3:
        teq r0, #0
        mov r1, #3
        bne fail3

        bl test_logic
fail4:
        teq r0, #0
        mov r1, #4
        bne fail4

        bl test_adder
fail5:
        teq r0, #0
        mov r1, #5
        bne fail5

        bl test_bshift_reg
fail6:
        teq r0, #0
        mov r1, #6
        bne fail6

        bl test_load
fail7:
        teq r0, #0
        mov r1, #7
        bne fail7

        bl test_store
fail8:
        teq r0, #0
        mov r1, #8
        bne fail8

        bl test_byte
fail9:
        teq r0, #0
        mov r1, #9
        bne fail9

        bl test_cpsr
fail10:
        teq r0, #0
        mov r1, #10
        bne fail10

        bl test_mul
fail11:
        teq r0, #0
        mov r1, #11
        bne fail11

        bl test_ldmstm
fail12:
        teq r0, #0
        mov r1, #12
        bne fail12

        bl test_r15jumps
fail13:
        teq r0, #0
        mov r12, #13
        bne fail13

        bl test_rti

passed:
        // Both these should not change mode or T state.
        msr cpsr, #0x0
        msr cpsr, #0x20
        msr cpsr, #0x30

        // Check if we're still in user mode.
        mrs r0, cpsr
        and r0, r0, #0x1F
        cmp r0, #0x10
        bne passed

        mvn  r0, #0
        mov  r1, r0
        mov  r2, r0
        mov  r3, r0
        mov  r4, r0
        mov  r5, r0
        mov  r6, r0
        mov  r7, r0

        mov  r0, #0x18
        ldr  r8, [r0]
        mov  r9, r8
        mov r10, r8
        mov r11, r8
        mov r12, r8
        mov r13, r8
        mov r14, r8
        mvn  r0, #0

passed_here:
        b passed_here

        @ test sat
test_sat:
        mov r0, #0x1
        mov r6, #0x14
        ldr r6, [r6]

        @ Test 1 - test bit 27 of CPSR is set after QADD.

        mov r1, #0xffffffff
        mov r5, #0x80000000

        qadd r2, r1, r5
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        @ Test 2 - test result of saturating add to be smallest negative number.

        qadd r2, r5, r1
        teq r2, #0x80000000
        bne fail

        add r0, r0, #1

        @ Test 3 - Ensure bit 27 of CPSR remains set after non saturating ADD.

        adds r2, r5, r1
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        //////////////////////////////////////////////////////////////////////////

        mov r7, #0
        msr cpsr_flg, r7

        @ Test 4 - test bit 27 of CPSR is set after QADD

        mov r1, #0x40000000
        mov r5, #0x40000000

        qadd r2, r1, r5
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        @ Test 5 - test result of saturating add to be the largest positive number.

        qadd r2, r5, r1
        teq r2, r6
        bne fail

        add r0, r0, #1

        @ Test 6 - Ensure bit 27 of CPSR remains set after non saturating ADD.

        adds r3, r5, r1
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        ////////////////////////////////////////////////////////////////////////////

        msr cpsr_flg, r7

        @ Test 7 - test bit 27 of CPSR is set after QSUB

        mov r1, #0x80000000
        mov r5, #0x1

        qsub r2, r1, r5
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        @ Test 8 - test result of saturating subtract to be the largest positive number.

        qsub r2, r5, r1
        teq r2, r6
        bne fail

        add r0, r0, #1

        @ Test 9 - test result of saturating subtract to be the smallest negative number.

        qsub r2, r1, r5
        teq r2, #0x80000000
        bne fail

        add r0, r0, #1

        @ Test 10 - Ensure bit 27 of CPSR remains set after non saturating SUB.

        subs r2, r5, r1
        mrs r2, cpsr
        and r2, r2, #0x08000000
        teq r2, #0x08000000
        bne fail

        add r0, r0, #1

        ///////////////////////////////////////////////////////////////////////////////

        msr cpsr_flg, r7

        @ Test 11 - test bit 27 of CPSR is set after QSUB

        mov r1, #0x7ffffffe  // MAX - 1
        mov r5, #0xfffffffe  // -2
        // Result =  MAX - 1 + 2 = MAX + 1 = Saturate to MAX.

        qsub r2, r1, r5
        mrs r3, cpsr
        and r3, r3, #0x08000000
        teq r3, #0x08000000
        bne fail

        add r0, r0, #1

        @ Test 12 - test result of saturating subtract to be the smallest -ve number.

        // - 2 - MAX + 1 = - MAX - 1 
        qsub r2, r5, r1
        teq r2, #0x80000000
        bne fail

        add r0, r0, #1

        @ Test 13 - test result of saturating subtract to be the largest +ve number.

        qsub r2, r1, r5
        teq r2, r6
        bne fail

        add r0, r0, #1

        @ Test 14 - Ensure bit 27 of CPSR remains set after non saturating SUB.

        subs r2, r5, r1
        mrs r4, cpsr
        and r4, r4, #0x08000000
        teq r4, #0x08000000
        bne fail

        add r0, r0, #1

        ///////////////////////////////////////////////////////////////////////////////

        mov r0, #0
        msr cpsr_flg, r0        // Clear out flags to keep in sync with the rest of the test program.

        bx lr

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        @ test CLZ
test_clz:
        mov r0, #1
        clz r1, r0
        teq r1, #31
        bne fail
        mov r0, #0
        bx lr

        @test N and Z flags conditional execution
test_cond:
        mov r0, #1

        @ test 1 - test that the Z flag is set properly, and N flag clear properly
        movs r5, #0
        bne fail
        bmi fail
        add r0, #1

        @test 2 - test that an instruction without 'S' does not affect the flags
        movs r5, #1
        mov r5, #0
        beq fail
        bmi fail
        add r0, #1

        @test 3 - test that the N flag is set properly
        movs r5, #-2
        mov r5, #0
        beq fail
        bpl fail
        add r0, #1

        @test4 - make sure conditional MOV are skipped, and that flags are not updated on a skipped instruction
        movs r5, #1
        movpls r5, #0   @valid
        movnes r5, #1   @invalid
        movmis r5, #2   @invalid
        bne fail
        cmp r5, #0
        bne fail
        add r0, #1

        @ test 5 - make sure instructions after a branch are skipped completely
        b .dummy
        movs r5, #-1
        movs r5, #-2
        movs r5, #-3
.dummy:
        bne fail
        bmi fail

        @condition test passed
        mov r0, #0
fail:
        bx lr

test_fwd:
        mov r0, #1

        @test forwarding and register file for OPA
        mov r1, #1
        add r1, r1, #1
        add r1, r1, #1
        add r1, r1, #1
        add r1, r1, #1
        add r1, r1, #1
        cmp r1, #6
        bne fail
        add r0, #1

        @test forwarding priority for opb
        mov r1, #1
        mov r1, #2
        mov r1, #3
        mov r1, #4
        mov r1, #5
        cmp r1, #5
        bne fail
        add r0, #1

        @forwarding test passed
        mov r0, #0
        bx lr

test_bshift:
        @test barrel shifter all modes (shift by literal const. only for now)
        mov r0, #1

        @test 1 - test LSL output
        movs r5, #0xf0000000
        mov r1, #0x0f
        mov r2, r1, lsl #28
        cmp r5, r2
        bne fail
        add r0, #1

        @test 2 - test ROR output
        mov r3, r1, ror #4
        cmp r5, r3
        bne fail
        add r0, #1

        @test 3 - test LSR output
        mov r4, r5, lsr #28
        cmp r4, r1
        bne fail
        add r0, #1

        @test 4 - test ASR output
        mov r1, #0x80000000
        mov r2, r1, asr #3
        cmp r5 ,r2
        bne fail
        add r0, #1

        @test 5 - test RRX output and carry
        mov r1, #1
        movs r1, r1, rrx
        bcc fail
        movs r1, r1, rrx
        beq fail
        bcs fail
        add r0, #1

        @test 6 - test carry output from rotated constant
        movs r5, #0xf0000000
        bcc fail
        movs r5, #0xf
        bcc fail
        movs r5, #0x100
        bcs fail
        add r0, #1

        @test 7 - test carry output from LSL
        mov r5, #0x1
        movs r5, r5, lsl #1
        bcs fail
        mov r5, #0x80000000
        movs r5, r5, lsl #1
        bcc fail
        add r0, #1

        @test 8 - test carry output from LSR
        mov r5, #2
        movs r5, r5, lsr #1
        bcs fail
        movs r5, r5, lsr #1
        bcc fail
        bne fail
        add r0, #1

        @test 9 - test carry output from ASR
        mvn r5, #0x01
        movs r5, r5, asr #1
        bcs fail
        movs r5, r5, asr #1
        bcc fail
        add r0, #1

        @test 10 - check for LSR #32 to behave correctly
        mov r1, #0xa5000000
        mvn r2, r1
        lsrs r3, r1, #32
        bcc fail
        lsrs r3, r2, #32
        bcs fail
        add r0, #1

        @test 11 - check for ASR #32 to behave correctly
        asrs r3, r1, #32
        bcc fail
        cmp r3, #-1
        bne fail
        asrs r3, r2, #32
        bcs fail
        bne fail

        @barrelshift test passed
        mov r0, #0
        bx lr

        @test logical operations
test_logic:
        mov r0, #1

        @test 1 - NOT operation
        mov r5, #-1
        mvns r5, r5
        bne fail
        add r0, #1

        @test 2 - AND operation
        mov r5, #0xa0
        mov r1, #0x0b
        mov r2, #0xab
        mov r3, #0xba

        ands r4, r5, r1
        bne fail
        ands r4, r5, r2
        cmp r4, r5
        bne fail
        add r0, #1

        @test 3 - ORR and EOR operations
        orr r4, r5, r1
        eors r4, r2, r4
        bne fail
        orr r4, r1, r5
        teq     r4, r2
        bne fail
        add r0, #1

        @test 4 - TST opcode
        tst r1, r5
        bne fail
        tst r4, r2
        beq fail
        add r0, #1

        @test 5 - BIC opcode
        bics r4, r2, r3
        cmp r4, #1
        bne fail

        @logical test passed
        mov r0, #0
        bx lr

        @test adder, substracter, C and V flags
test_adder:
        mov r0, #1

        @test 1 - check for carry when adding
        mov r5, #0xf0000000
        mvn r1, r5                      @0x0fffffff
        adds r2, r1, r5
        bcs fail
        bvs fail

        adds r2, #1
        bcc fail
        bvs fail

        adc r2, #120
        cmp r2, #121
        bne fail
        bvs fail
        add r0, #1

        @test 2 - check for overflow when adding
        mov r3, #0x8fffffff             @two large negative numbers become positive
        adds r3, r5
        bvc fail
        bcc fail
        bmi fail

        mov r3, #0x10000000
        adds r3, r1                             @r3 = 0x1fffffff
        bvs fail
        bcs fail

        adds r3, #0x60000001    @two large positive numbers become negative
        bvc fail
        bpl fail

        add r0, #1

        @test 3 - check for carry when substracting
        mov r5, #0x10000000
        subs r2, r5, r1
        bcc fail
        bvs fail

        subs r2, #1
        bcc fail
        bvs fail

        subs r2, #1
        bcs fail
        bvs fail

        add r0, #1

        @test 4 - check for overflow when substracting
        mov r3, #0x90000000
        subs r3, r5
        bvs fail
        bcc fail

        subs r3, #1             @substract a positive num from a large negative make the result positive
        bvc fail
        bcc fail

        @test 5 - check for carry when reverse substracting
        mov r3, #1
        rsbs r2, r1, r5
        bcc fail
        bvs fail
        rsbs r2, r3, r2
        bcc fail
        bvs fail
        rscs r2, r3, r2
        bcs fail
        bvs fail

        add r0, #1

        @test 6 - check for overflow when reverse substracting
        mov r2, #0x80000000
        mov r1, #-1
        rsbs r2, r1
        bvs fail
        bmi fail
        bcc fail

        @test 7 - check SBC and RSC
        mov r2, #0x4
        mov r1, #0x5
        sbc r3, r2, r1
        adds r3, #1
        bne fail
        rsc r3, r1, r2
        adds r3, #1
        bne fail

        mov r0, #0
        bx lr

@test barrelshift with register controler rotates
test_bshift_reg:
        mov r0, #1

        mov r1, #0
        mov r2, #7
        mov r3, #32
        mov r4, #33
        mov r5, #127
        mov r6, #256
        add r7, r6, #7
        mov r8, #0xff000000

        @test 1 LSL mode with register shift
        movs r9, r8, lsl r2
        bpl fail
        bcc fail
        @make sure lsl #0 does not affect carry
        movs r9, r2, lsl r1
        bcc fail
        @test using the same register twice
        mov r9, r2, lsl r2
        cmp r9, #0x380
        bne fail

        add r0, #1

        @test 2 - LSL mode with barrelshift > 31
        movs r9, r2, lsl r3
        bcc fail
        bne fail
        movs r9, r2, lsl r4
        bcs fail
        bne fail
        add r0, #1

        @test 3 - LSL mode with barrelshift >= 256 (only 8 bits used)
        movs r9, r2, lsl r6
        bcs fail
        cmp r9, #7
        bne fail

        mov r9, r2, lsl r7
        cmp r9, #0x380
        bne fail

        movs r9, r8, lsl r7
        bpl fail
        bcc fail

        add r0, #1

        @test 4 - LSR mode with register shift
        mov r2, #4
        add r7, r6, #4

        movs r9, r8, lsr r2
        bmi fail
        bcs fail
        @make sure lsr #0 does not affect carry
        movs r9, r2, lsr r1
        bcs fail
        cmp r9, #4
        bne fail

        movs r9, r8, lsr r2
        bcs fail
        cmp r9, #0xff00000
        bne fail

        add r0, #1

        @test 5 - LSR mode with barrelshift > 31
        movs r9, r8, lsr r3
        bcc fail
        bne fail
        movs r9, r8, lsr r4
        bcs fail
        bne fail
        add r0, #1

        @test 6 - LSR mode with barrelshift >= 256 (only 8 bits used)
        movs r9, r8, lsr r6
        bcs fail
        cmp r9, #0xff000000
        bne fail

        movs r9, r8, lsr r7
        cmp r9, #0xff00000
        bne fail

        mov r0, #0
        bx lr

array:
        .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
array2:
        .word 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
        
test_load:
        mov r0, #1

        @ Test1 basic load operations
        ldr r1, .larray1
        ldr r2, .larray2

        ldr r3, [r1]
        teq r3, #0
        bne fail

        ldr r3, [r2]
        teq r3, #16
        bne fail
        add r0, #1

        @ Test 2 load operations with offsets
        ldr r3, [r2, #-60]
        teq r3, #1
        bne fail

        ldr r3, [r1, #20]
        teq r3, #5
        bne fail
        add r0, #1

        ldr r3, [r1, #20]
        mov r3, #0
        teq r3, #0
        bne fail
        add r0, #1

        @ Test 3 - test positive register offset addressing
        mov r3, #124
.lloop:
        ldr r4, [r1, r3]
        cmp r4, r3, lsr #2
        bne fail
        subs r3, #4
        bpl .lloop
        add r0, #1

        @ Test 4 - test negative register offset addressing
        mov r3, #64
.lloop2:
        ldr r4, [r2, -r3]
        rsb r4, #0x10
        cmp r4, r3, lsr #2
        bne fail
        subs r3, #4
        bne .lloop2
        add r0, #1

        @ Test 5 - test positive register offset addressing with shift
        mov r3, #0
.lloop3:
        ldr r4, [r1, r3, lsl #2]
        cmp r4, r3
        bne fail
        add r3, #1
        cmp r3, #32
        bne .lloop3
        add r0, #1

        @ Test 6 - test negative register offset addressing with shift
        mov r3, #0
.lloop4:
        ldr r4, [r2, -r3, lsl #2]
        rsb r4, #0x10
        cmp r4, r3
        bne fail
        add r3, #1
        cmp r3, #16
        bne .lloop4
        add r0, #1

        @ Test 7 - test offset with pre-increment
        mov r3, #31
        mov r5, r1
.lloop5:
        ldr r4, [r5, #4]!
        rsb r4, #32
        cmp r4, r3
        bne fail
        subs r3, #1
        bne .lloop5
        add r0, #1

        @ Test 8 - test offset with pre-degrement
        mov r3, #31
        add r5, r1, #128
.lloop6:
        ldr r4, [r5, #-4]!
        cmp r4, r3
        bne fail
        subs r3, #1
        bpl .lloop6
        add r0, #1

        @ Test 9 - test offset with post-increment
        mov r3, #32
        mov r5, r1
.lloop7:
        ldr r4, [r5], #4
        rsb r4, #32
        cmp r4, r3
        bne fail
        subs r3, #1
        bne .lloop7
        add r0, #1

        @ Test 10 - test offset with post-decrement
        mov r3, #31
        add r5, r1, #124
.lloop8:
        ldr r4, [r5], #-4
        cmp r3, r4
        bne fail
        subs r3, #1
        bpl .lloop8
        add r0, #1

        @ Test 11 - test register post-increment with a negative value
        mov r6, #0xfffffff0
        mov r5, r2
        mov r3, #16
.lloop9:
        ldr r4, [r5], r6, asr #2
        cmp r4, r3
        bne fail
        subs r3, #1
        bpl .lloop9

        mov r0, #0
        bx lr

.larray1:
        .word array
.larray2:
        .word array2

test_store:
        mov r0, #1

        @ Test 1 - test basic store opperation
        ldr r1, .larray1
        mov r2, #0x24
        str r2, [r1]
        ldr r2, [r1]
        cmp r2, #0x24
        bne fail
        add r0, #1

        @ Test 2 - check for post-increment and pre-decrement writes
        mov r2, #0xab
        mov r3, #0xbc
        str r2, [r1, #4]!               @ array[1] = 0xab
        str r3, [r1], #4                @ array[1] = 0xbc
        ldr r2, [r1, #-4]!              @ read 0xbc
        ldr r3, [r1, #-4]!              @ read 0x24
        cmp r3, #0x24
        bne fail
        cmp r2, #0xbc
        bne fail
        add r0, #1

        @ Test 3 - check for register post-increment addressing
        mov r2, #8
        mov r3, #20
        mov r4, r1
        str r2, [r4], r2
        str r3, [r4], r2
        sub r4, #16
        cmp r4, r1
        bne fail
        ldr r2, [r1]
        cmp r2, #8
        bne fail
        ldr r2, [r1, #8]
        cmp r2, #20
        bne fail

        mov r0, #0
        bx lr

        @ Tests byte loads and store
test_byte:
        mov r0, #1

        @ test 1 - test store bytes
        ldr r1, .larray1
        mov r2, #8
.bloop:
        strb r2, [r1], #1
        subs r2, #1
        bne .bloop

        ldr r2, .ref_words+4
        ldr r3, [r1, #-4]!
        cmp r2, r3
        bne fail

        ldr r2, .ref_words
        ldr r3, [r1, #-4]!
        cmp r2, r3
        bne fail
        add r0, #1

        @ test 2 - test load bytes
        mov r2, #8
.bloop2:
        ldrb r3, [r1], #1
        cmp r3, r2
        bne fail
        subs r2, #1
        bne .bloop2

        mov r0, #0
        bx lr

.ref_words:
        .word 0x05060708, 0x01020304

test_cpsr:
        mov r0, #1

        @ Test 1 - in depth test for the condition flags
        mrs r1, cpsr
        and r1, #0x000000ff
        msr cpsr_flg, r1
        @ NZCV = {0000}
        bvs fail
        bcs fail
        beq fail
        bmi fail
        bhi fail                @ bhi <-> bls
        blt fail                @ blt <-> bge
        ble fail                @ ble <-> bgt

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0001}
        bvc fail
        bhi fail
        bge fail
        bgt fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0010}
        bvs fail
        bcc fail
        bls fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0011}
        bls fail
        bge fail
        bgt fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0100}
        bne fail
        bhi fail
        bgt fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0101}
        bgt fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {0110}
        bhi fail

        add r1, #0x20000000
        msr cpsr, r1
        @ NZCV = {1000}
        bpl fail
        bge fail
        bgt fail

        add r1, #0x10000000
        msr cpsr, r1
        @ NZCV = {1001}
        blt fail

        add r1, #0x30000000
        msr cpsr, r1
        @ NZCV = {1100}
        bgt fail

        add r0, #1

        @ Test 2 - test for the FIQ processor mode
        mov r1, r14                     @ save our link register and stack pointer
        mov r2, r13
        mov r3, #30
        mov r4, #40
        mov r5, #50
        mov r6, #60
        mov r7, #70
        mov r8, #80
        mov r9, #90
        mov r10, #100
        mov r11, #110
        mov r12, #120
        mov r13, #130
        mov r14, #140

        msr cpsr, #0xd1         @ go into FIQ mode, disable all interrupts (F and I bits set)
        cmp r3, #30
        bne .fail
        mov r8, #8                      @ overwrite fiq regs...
        mov r9, #9
        mov r10, #10
        mov r11, #11
        mov r12, #12
        mov r13, #13
        mov r14, #14
        mov r3, #3                      @ also overwrite some user regs
        mov r4, #4
        mov r5, #5
        mov r6, #6
        mov r7, #7
        msr cpsr, #0x1f         @ back to SYS mode
        cmp r3, #3                      @ r3-7 should have been affected, but not r8-r14
        bne .fail
        cmp r4, #4
        bne .fail
        cmp r5, #5
        bne .fail
        cmp r6, #6
        bne .fail
        cmp r7, #7
        bne .fail
        cmp r8, #80
        bne .fail
        cmp r9, #90
        bne .fail
        cmp r10, #100
        bne .fail
        cmp r11, #110
        bne .fail
        cmp r12, #120
        bne .fail
        cmp r13, #130
        bne .fail
        cmp r14, #140
        bne .fail
        add r0, #1

        @ Test 3 - test for the SVC processor mode
        mov r12, #120
        mov r13, #130
        mov r14, #140
        msr cpsr, #0x13         @ enter SVC mode
        cmp r12, #120
        bne .fail
        mov r12, #12
        mov r13, #13
        mov r14, #14
        msr cpsr, #0x1f         @ back into SYS mode
        cmp r12, #12
        bne .fail
        cmp r13, #130
        bne .fail
        cmp r14, #140
        bne .fail
        add r0, #1

        @ Test 4 - test for the UND processor mode
        mov r12, #120
        mov r13, #130
        mov r14, #140
        msr cpsr, #0x1b         @ enter UND mode
        cmp r12, #120
        bne .fail
        mov r12, #12
        mov r13, #13
        mov r14, #14
        msr cpsr, #0x1f         @ back into SYS mode
        cmp r12, #12
        bne .fail
        cmp r13, #130
        bne .fail
        cmp r14, #140
        bne .fail
        add r0, #1

        @ Test 5 - test for the IRQ processor mode
        mov r12, #120
        mov r13, #130
        mov r14, #140
        msr cpsr, #0x92         @ enter IRQ mode, IRQ disabled
        cmp r12, #120
        bne .fail
        mov r12, #12
        mov r13, #13
        mov r14, #14
        msr cpsr, #0x1F         @ back into SYS mode
        cmp r12, #12
        bne .fail
        cmp r13, #130
        bne .fail
        cmp r14, #140
        bne .fail

        mov r0, #0
        mov r13, r2
        bx r1

.fail:
        msr cpsr, #0x1F         @ back into SYS mode
        b fail10

        @ Test multiplier and how it affects the flags
test_mul:
        mov r0, #1

        @ Test 1 - MUL instruction
        mov r1, #0
        mov r2, #2
        mov r3, #3
        mul r4, r2, r3
        cmp r4, #6
        bne fail
        bmi fail

        muls r5, r1, r2
        bne fail
        bmi fail

        muls r4, r2
        cmp r4, #12
        bne fail
        bmi fail

        mul r3, r3, r4        
        cmp r3, #36
        bne fail

        mov r3, #-3                     @ multiply positive * negative
        muls r5, r2, r3
        bpl fail        
        cmp r5, #-6
        bne fail

        mov r2, #-2                     @ multiply negative * negative
        muls r5, r2, r3
        bmi fail
        cmp r5, #6
        bne fail
        add r0, #1

        @ Test 2 - MLA instruction
        mov r1, #10
        mov r2, #2
        mov r3, #5
        mlas r4, r1, r2, r3             @ 2*10 + 5 = 25
        bmi fail
        bcc fail                        @ Carry should be unchanged.
        bvs fail
        cmp r4, #25
        bne fail

        mov r1, #-10
        mlas r4, r1, r2, r3             @ 2*-10 + 5 = -15
        bpl fail
        bvs fail
        cmp r4, #-15
        bne fail

        mov r3, #0x80000001             @ causes addition overflow
        mlas r4, r1, r2, r3
        bmi fail
        bvs fail                        @ Overflow should be unaffected.
        add r0, #1

        @ Test 3 - SMALTB test.
        mov r1, #0x20000001
        mov r2, r1
        mov r3, #0x4
        smlatb r4, r1, r2, r3
        mov r5, #0x2000
        add r5, #4
        cmp r4, r5
        bne fail

        mov r0, #0
        bx lr

        @ Test load multiple and store multiple instructions
test_ldmstm:
        mov r0, #1

        @ Test 1 - STMIA
        mov r1, #1
        mov r2, #2
        mov r3, #3
        mov r4, #4
        ldr r5, .larray1
        mov r6, r5

        stmia r6!, {r1-r4}
        sub r6, r5
        cmp r6, #16
        bne fail

        ldr r6, [r5]
        cmp r6, #1
        bne fail
        ldr r6, [r5, #4]
        cmp r6, #2
        bne fail
        ldr r6, [r5, #8]
        cmp r6, #3
        bne fail
        ldr r6, [r5, #12]
        cmp r6, #4
        bne fail
        add r0, #1

        @ Test 2 - STMIB
        mov r6, r5
        stmib r6!, {r1-r3}
        sub r6, r5
        cmp r6, #12
        bne fail

        ldr r6, [r5, #4]
        cmp r6, #1
        bne fail
        ldr r6, [r5, #8]
        cmp r6, #2
        bne fail
        ldr r6, [r5, #12]
        cmp r6, #3
        bne fail
        add r0, #1

        @ Test 3 - STMDB
        add r6, r5, #12
        stmdb r6!, {r1-r3}
        cmp r6, r5
        bne fail

        ldr r6, [r5]
        cmp r6, #1
        bne fail
        ldr r6, [r5, #8]
        cmp r6, #3
        bne fail
        add r0, #1

        @ Test 4 - STMDA
        add r6, r5, #12
        stmda r6!, {r1-r3}
        cmp r6, r5
        bne fail
        ldr r6, [r5, #4]
        cmp r6, #1
        bne fail
        ldr r6, [r5, #12]
        cmp r6, #3
        bne fail
        add r0, #1

        @ Test 5 - LDMIA
        ldr r5, .larray2
        ldmia r5, {r1-r4}
        cmp r1, #16
        bne fail
        cmp r2, #17
        bne fail
        cmp r3, #18
        bne fail
        cmp r4, #19
        bne fail
        add r0, #1

        @ Test 6 - LDMIB
        ldmib r5!, {r1-r4}
        cmp r1, #17
        bne fail
        cmp r2, #18
        bne fail
        cmp r3, #19
        bne fail
        cmp r4, #20
        bne fail
        add r0, #1

        @ Test 7 - LDMDB
        ldmdb r5!, {r1-r3}
        cmp r3, #19
        bne fail
        cmp r2, #18
        bne fail
        cmp r1, #17
        bne fail
        add r0, #1

        @ Test 8 - LDMDA
        ldmda r5, {r1-r2}
        cmp r1, #16
        bne fail
        cmp r2, #17
        bne fail

        mov r0, #0
        bx lr

        @ Test proper jumping on instructions that affect R15
test_r15jumps:
        mov r0, #1

        @ Test 1 - a standard, conditional jump instruction
        ldr r3, .llabels
        mov r1, #0
        movs r2, #0
        moveq r15, r3            @ jump to label 1
        movs r2, #12
        movs r1, #13            @ make sure fetched/decoded instructions do no execute
.label1:
        bne fail
        cmp r1, #0
        bne fail
        cmp r2, #0
        bne fail
        add r0, #1

        @ Test 2 - a jump instruction is not executed
        ldr r3, .llabels+4
        movs r2, #12
        moveq r15, r3
        movs r2, #0
.label2:
        cmp r2, #0
        bne fail
        add r0, #1

        @ Test 3 - add instruction to calculate new address
        ldr r3, .llabels+8
        movs r1, #0
        movs r2, #0
        add r15, r3, #8         @go 2 instructions after label 3
.label3:
        movs r1, #12
        movs r2, #13
        bne fail                @ program executions continues here
        bne fail
        add r0, #1

        @ Test 4 - use an addition directly from PC+8 (r15)
        movs r2, #0
        movs r1, #0
        add r15, r15, #4        @ Skip 2 instructions This could actually be used for a nice jump table if a register were used instead of #4
        movs r1, #1
        movs r2, #2
        bne fail
        bne fail
        add r0, #1

        @ Test 5 - load r15 directly from memory
        movs r1, #1
        movs r2, #2
        ldrne r15, .llabels+12          @ Makes sure code after a ldr r15 is not executed
        movs r1, #0
        movs r2, #0
.label4:
        beq fail
        beq fail

        ldreq r15, .llabels+16          @ Makes sure everything is right when a ldr r15 is not taken
        movs r2, #-2
.label5:
        bpl fail
        cmp r2, #-2
        bne fail
        add r0, #1

        @ Test 6 - load r15 as the last step of a LDM instruction
        ldr r3, .llabels + 6*4
        movs r1, #0
        movs r2, #0
        ldmia r3, {r4-r8, r15}          @jump to label6
        movs r1, #4
        movs r2, #2
.label6:
        bne fail
        bne fail

        mov r0, #0
        bx lr

.align 8
.llabels:
        .word .label1, .label2, .label3, .label4, .label5, .label6, .llabels

test_rti:
        mov r0, #1
        mov r12, #14

        @ Test 1 - test normal RTI
        msr cpsr, #0xd1                 @ enter into FIQ mode (interrupt disabled)
        msr spsr, #0x4000001f   @ emulate a saved CPSR in SYS mode, with NZCV = {0100}

        movs r8, #-12                   @ now the FIQ sets it's CPSR to NZCV = {1000}
        ldr r8, .rtilabels              @ simulate an interrupt return
        movs r15, r8                    @ return from interrupt and move SPSR to CPSR

.rtilabel1:
        mov r12, #1000
        bmi .rtifail                    @ ?!? WTF !?!
        bne .rtifail
        mov r12, #2000
        add r0, #1

        @ Test 2 - test LDM instruction with S flag
        msr cpsr, #0xd1
        ldr r8, .rtilabels + 20
        ldmib r8!, {r9, r10}            @ fiq_r9 = 1, fiq_r10 = 2
        ldmib r8, {r9, r10}^            @ r8 = 3, r9 = 4 ( ^ => load to user registers )
        cmp r9, #1
        bne .rtifail
        cmp r10, #2
        bne .rtifail
        msr cpsr, #0x1f
        cmp r9, #3
        bne .rtifail
        cmp r10, #4
        bne .rtifail
        add r0, #1

        mov r12, #4000

        @ Test 3 - test LDM instruction with S flag for returning from an interrupt
        msr cpsr, #0xd1                         @ FIQ mode, NZCV = {0000}
        msr spsr, #0x80000010           @ saved is normal mode with NZCV = {1000}

        ldr r8, .rtilabels + 20
        add r8, #8

        movs r9, #0                                     @ NZCV = {0100}
        ldmib r8, {r9-r11, r15}^        @ This should return to user mode and restore CPSR to NZCV = {1000}

.rtilabel2:
        bpl .rtifail
        beq .rtifail
        b passed

.rtifail:
        msr cpsr, #0x10
        mov r12, #100
        b .rtifail
        bx lr


.rtilabels:
        .word .rtilabel1, 1, 2, 3, 4, .rtilabels, .rtilabel2
