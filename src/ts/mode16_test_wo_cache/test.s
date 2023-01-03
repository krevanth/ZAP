// Based on the 16bit instruction tests by jsmolka. See github.com/jsmolka 

.text

_Reset:
    b disable_cache

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

   ////////////////////////////////////////////////////////////////////////////

   disable_cache:

   mov sp, #4000

   ldr r0, =myThFunction+1
   mov lr, pc
   bx r0 // Jump to 16-bit code

   mvn r0, #0
  
   ldr r0,= myThFunction+1
   blx r0 // Jump to 16-bit code

   mvn r0, #0
   mov r1, r0
   mov r2, r0
   mov r3, r0
   mov r4, r0
   mov r5, r0
   mov r6, r0
   mov r7, r0
 
   here: b here
   
.macro m_exit test 
        mov     r7, #\test
        bl      myThFunctionEnd
.endm

///////////////////////////////////////////////////////////////////////////////
// 16-bit Function
///////////////////////////////////////////////////////////////////////////////

.thumb_func
myThFunction:
        // Reset test register
        mov     r7, #0

        // Tests start at 1

        ///////////////////////////////////////////////////////////////////////

        logical:
                // Tests for logical operations
        
        t001:
                // Zero flag
                mov     r0, #0
                bne     f001
        
                mov     r0, #1
                beq     f001
        
                b       t002
        
        f001:
                m_exit  1       
 
        t002:
                // Negative flag
                mov     r0, #1
                lsl     r0, #31
                mov     r0, r0
                bpl     f002
        
                mov     r0, #0
                bmi     f002
        
                b       t003
        
        f002:
                m_exit  2
        
        t003:
                // 16_BIT_ISA 3: mov rd, imm8
                mov     r0, #32
                cmp     r0, #32
                bne     f003
        
                b       t004
        
        f003:
                m_exit  3
        
        t004:
                // 16_BIT_ISA 2: mov rd, rs
                mov     r0, #32
                mov     r1, r0
                cmp     r1, r0
                bne     f004
        
                b       t005
        
        f004:
                m_exit  4
        
        t005:
                // 16_BIT_ISA 5: mov rd, rs (high registers)
                mov     r0, #32
                mov     r8, r0
                mov     r9, r8
                mov     r0, r9
                cmp     r0, #32
                bne     f005
        
                b       t006
        
        f005:
                m_exit  5
        
        t006:
                // 16_BIT_ISA 4: mvn rd, rs
                mov     r0, #0
                mvn     r0, r0
                add     r0, #1
                bne     f006
        
                b       t007
        
        f006:
                m_exit  6
        
        t007:
                // 16_BIT_ISA 4: and rd, rs
                mov     r0, #0xFF
                mov     r1, #0x0F
                and     r0, r1
                cmp     r0, r1
                bne     f007
        
                b       t008
        
        f007:
                m_exit  7
        
        t008:
                // 16_BIT_ISA 4: tst rd, rs
                mov     r0, #0xF0
                mov     r1, #0x0F
                tst     r0, r1
                bne     f008
        
                b       t009
        
        f008:
                m_exit  8
        
        t009:
                // 16_BIT_ISA 4: bic rd, rs
                mov     r0, #0xFF
                mov     r1, #0xF0
                bic     r0, r1
                cmp     r0, #0x0F
                bne     f009
        
                b       t010
        
        f009:
                m_exit  9
        
        t010:
                // 16_BIT_ISA 4: orr rd, rs
                mov     r0, #0xF0
                mov     r1, #0x0F
                orr     r0, r1
                cmp     r0, #0xFF
                bne     f010
        
                b       t011
        
        f010:
                m_exit  10
        
        t011:
                // 16_BIT_ISA 4: eor rd, rs
                mov     r0, #0xFF
                mov     r1, #0x0F
                eor     r0, r1
                cmp     r0, #0xF0
                bne     f011
        
                b       t012
        
        f011:
                m_exit  11
        
        t012:
                // 16_BIT_ISA 5: Write to PC
                adr     r0, t013
                mov     pc, r0
        
        f012:
                m_exit  12
        
        .align 4
        t013:
                // 16_BIT_ISA 5: PC Alignment
                adr     r0, logical_passed
                add     r0, #1
                mov     pc, r0
        
        f013:
                m_exit  13
        
        .align 4
        logical_passed:

        ///////////////////////////////////////////////////////////////////////

        // Tests start at 50

        shifts:
                // Tests for shift operations
        
        t050:
                // 16_BIT_ISA 1: lsl rd, rs, imm5
                mov     r0, #1
                lsl     r0, #6
                cmp     r0, #64
                bne     f050
        
                b       t051
        
        f050:
                m_exit  50
        
        t051:
                // 16_BIT_ISA 4: lsl rd, rs
                mov     r0, #1
                mov     r1, #6
                lsl     r0, r1
                cmp     r0, #64
                bne     f051
        
                b       t052
        
        f051:
                m_exit  51
        
        t052:
                // Logical shift left carry
                mov     r0, #1
                lsl     r0, #31
                bcs     f052
        
                mov     r0, #2
                lsl     r0, #31
                bcc     f052
        
                b       t053
        
        f052:
                m_exit  52
        
        t053:
                // 16_BIT_ISA 4: Logical shift left by 32
                mov     r0, #1
                mov     r1, #32
                lsl     r0, r1
                bcc     f053
                bne     f053
        
                b       t054
        
        f053:
                m_exit  53
        
        t054:
                // 16_BIT_ISA 4: Logical shift left by greater 32
                mov     r0, #1
                mov     r1, #33
                lsl     r0, r1
                bne     f054
                bcs     f054
        
                b       t055
        
        f054:
                m_exit  54
        
        t055:
                // 16_BIT_ISA 1: lsr rd, rs, imm5
                mov     r0, #64
                lsr     r0, #6
                cmp     r0, #1
                bne     f055
        
                b       t056
        
        f055:
                m_exit  55
        
        t056:
                // 16_BIT_ISA 4: lsr rd, rs
                mov     r0, #64
                mov     r1, #6
                lsr     r0, r1
                cmp     r0, #1
                bne     f056
        
                b       t057
        
        f056:
                m_exit  56
        
        t057:
                // Logical shift right carry
                mov     r0, #2
                lsr     r0, #1
                bcs     f057
        
                mov     r0, #1
                lsr     r0, #1
                bcc     f057
        
                b       t058
        
        f057:
                m_exit  57
        
        t058:
                // 16_BIT_ISA 1: Logical shift right special
                mov     r0, #1
                lsr     r0, #32
                bne     f058
                bcs     f058
        
                mov     r0, #1
                lsl     r0, #31
                lsr     r0, #32
                bne     f058
                bcc     f058
        
                b       t059
        
        f058:
                m_exit  58
        
        t059:
                // 16_BIT_ISA 4: Logical shift right by greater 32
                mov     r0, #1
                lsl     r0, #31
                mov     r1, #33
                lsr     r0, r1
                bne     f059
                bcs     f059
        
                b       t060
        
        f059:
                m_exit  59
        
        t060:
                // 16_BIT_ISA 1: asr rd, rs, imm5
                mov     r0, #64
                asr     r0, #6
                cmp     r0, #1
                bne     f060
        
                mov     r0, #1
                lsl     r0, #31
                asr     r0, #31
                mov     r1, #0
                mvn     r1, r1
                cmp     r1, r0
                bne     f060
        
                b       t061
        
        f060:
                m_exit  60
        
        t061:
                // 16_BIT_ISA 4: asr rd, rs
                mov     r0, #64
                mov     r1, #6
                asr     r0, r1
                cmp     r0, #1
                bne     f061
        
                mov     r0, #1
                lsl     r0, #31
                mov     r1, #31
                asr     r0, r1
                mov     r1, #0
                mvn     r1, r1
                cmp     r1, r0
                bne     f061
        
                b       t062
        
        f061:
                m_exit  61
        
        t062:
                // Arithmetic shift right carry
                mov     r0, #2
                asr     r0, #1
                bcs     f062
        
                mov     r0, #1
                asr     r0, #1
                bcc     f062
        
                b       t063
        
        f062:
                m_exit  62
        
        t063:
                // 16_BIT_ISA 1: Arithmetic shift right special
                mov     r0, #1
                asr     r0, #32
                bne     f063
                bcs     f063
        
                mov     r0, #1
                lsl     r0, #31
                asr     r0, #32
                bcc     f063
                mov     r1, #0
                mvn     r1, r1
                cmp     r1, r0
                bne     f063
        
                b       t064
        
        f063:
                m_exit  63
        
        t064:
                // 16_BIT_ISA 4: ror rd, rs
                mov     r0, #1
                mov     r1, #1
                ror     r0, r1
                lsl     r1, #31
                cmp     r1, r0
                bne     f064
        
                b       t065
        
        f064:
                m_exit  64
        
        t065:
                // Rotate right carry
                mov     r0, #2
                mov     r1, #1
                ror     r0, r1
                bcs     f065
        
                mov     r0, #1
                mov     r1, #1
                ror     r0, r1
                bcc     f065
        
                b       t066
        
        f065:
                m_exit  65
        
        t066:
                // 16_BIT_ISA 4: Rotate right by 32
                mov     r0, #1
                lsl     r0, #31
                mov     r1, r0
                mov     r2, #32
                ror     r0, r2
                bcc     f066
                cmp     r0, r1
                bne     f066
        
                b       t067
        
        f066:
                m_exit  66
        
        t067:
                // 16_BIT_ISA 4: Rotate right by greater 32
                mov     r0, #2
                mov     r1, #33
                ror     r0, r1
                cmp     r0, #1
                bne     f067
        
                b       t068
        
        f067:
                m_exit  67
        
        t068:
                // 16_BIT_ISA 4: Shifts by 0
                mov     r0, #1
                mov     r1, #0
                cmp     r0, r0
                lsl     r0, r1
                lsr     r0, r1
                asr     r0, r1
                ror     r0, r1
                bcc     f068
                cmp     r0, #1
                bne     f068
        
                b       t069
        
        f068:
                m_exit  68
        
        t069:
                // Logical shift right by 32
                mov     r0, #1
                lsl     r0, #31
                mov     r1, #32
                lsr     r0, r1
                bcc     f069
        
                b       shifts_passed
        
        f069:
                m_exit  69

shifts_passed:

        ///////////////////////////////////////////////////////////////////////

        // Tests start at 100

        arithmetic:
                // Tests for arithmetic operations
        
        t100:
                // Carry flag addition
                mov     r0, #0
                mvn     r0, r0
                add     r0, #1
                bcc     f100
        
                mov     r0, #0
                add     r0, #1
                bcs     f100
        
                b       t101
        
        f100:
                m_exit  100
        
        t101:
                // Carry flag subtraction
                mov     r0, #1
                sub     r0, #0
                bcc     f101
        
                mov     r0, #1
                sub     r0, #1
                bcc     f101
        
                mov     r0, #1
                sub     r0, #2
                bcs     f101
        
                b       t102
        
        f101:
                m_exit  101
        
        t102:
                // Overflow flag addition
                mov     r0, #1
                lsl     r0, #31
                sub     r0, #1
                add     r0, #1
                bvc     f102
        
                mov     r0, #0
                add     r0, #1
                bvs     f102
        
                b       t103
        
        f102:
                m_exit  102
        
        t103:
                // Overflow flag subtraction
                mov     r0, #1
                lsl     r0, #31
                sub     r0, #1
                bvc     f103
        
                mov     r0, #1
                sub     r0, #1
                bvs     f103
        
                b       t104
        
        f103:
                m_exit  103
        
        t104:
                // 16_BIT_ISA 2: add rd, rs, imm3
                mov     r0, #0
                add     r0, #4
                cmp     r0, #4
                bne     f104
        
                b       t105
        
        f104:
                m_exit  104
        
        t105:
                // 16_BIT_ISA 3: add rd, imm8
                mov     r0, #32
                add     r0, #32
                cmp     r0, #64
                bne     f105
        
                b       t106
        
        f105:
                m_exit  105
        
        t106:
                // 16_BIT_ISA 5: add rd, rs (high registers)
                mov     r0, #32
                mov     r1, #0
                mov     r8, r1
                mov     r9, r1
                add     r8, r0
                add     r9, r8
                add     r0, r9
                cmp     r0, #64
                bne     f106
        
                b       t107
        
        f106:
                m_exit  106
        
        t107:
                // 16_BIT_ISA 12: add rd, sp, imm8 << 2
                add     r0, sp, #32
                mov     r1, sp
                add     r1, #32
                cmp     r1, r0
                bne     f107
        
                b       t108
        
        f107:
                m_exit  107
        
        t108:
                // 16_BIT_ISA 12: add rd, pc, imm8 << 2
                mov     r0, r0
                add     r0, pc, #32
                mov     r1, pc
                add     r1, #28
                cmp     r1, r0
                bne     f108
        
                b       t109
        
        f108:
                m_exit  108
        
        t109:
                // 16_BIT_ISA 13: add sp, imm7 << 2
                mov     r0, sp
                add     sp, #32
                add     sp, #-32
                cmp     sp, r0
                bne     f109
        
                b       t110
        
        f109:
                m_exit  109
        
        t110:
                // 16_BIT_ISA 4: adc rd, rs
                mov     r0, #16
                cmn     r0, r0
                adc     r0, r0
                cmp     r0, #32
                bne     f110
        
                mov     r0, #16
                cmp     r0, r0
                adc     r0, r0
                cmp     r0, #33
                bne     f110
        
                b       t111
        
        f110:
                m_exit  110
        
        t111:
                // 16_BIT_ISA 2: sub rd, rs, imm3
                mov     r0, #8
                sub     r0, #4
                cmp     r0, #4
                bne     f111
        
                b       t112
        
        f111:
                m_exit  111
        
        t112:
                // 16_BIT_ISA 3: sub rd, imm8
                mov     r0, #64
                sub     r0, #32
                cmp     r0, #32
                bne     f112
        
                b       t113
        
        f112:
                m_exit  112
        
        t113:
                // 16_BIT_ISA 2: sub rd, rs, rn
                mov     r0, #64
                mov     r1, #32
                sub     r0, r1
                cmp     r0, r1
                bne     f113
        
                b       t114
        
        f113:
                m_exit  113
        
        t114:
                // 16_BIT_ISA 4: sbc rd, rs
                mov     r0, #32
                mov     r1, #16
                cmn     r0, r0
                sbc     r0, r1
                cmp     r0, #15
                bne     f114
        
                mov     r0, #32
                mov     r1, #16
                cmp     r0, r0
                sbc     r0, r1
                cmp     r0, #16
                bne     f114
        
                b       t115
        
        f114:
                m_exit  114
        
        t115:
                // 16_BIT_ISA 4: neg rd, rs
                mov     r0, #32
                mov     r1, #0
                sub     r1, r0
                neg     r0, r0
                cmp     r0, r1
                bne     f115
        
                b       t116
        
        f115:
                m_exit  115
        
        t116:
                // 16_BIT_ISA 3: cmp rd, imm8
                mov     r0, #32
                cmp     r0, #32
                bne     f116
        
                b       t117
        
        f116:
                m_exit  116
        
        t117:
                // 16_BIT_ISA 4: cmp rd, rs
                mov     r0, #32
                cmp     r0, r0
                bne     f117
        
                b       t118
        
        f117:
                m_exit  117
        
        t118:
                // 16_BIT_ISA 5: cmp rd, rs (high registers)
                mov     r0, #32
                mov     r8, r0
                cmp     r8, r8
                bne     f118
        
                b       t119
        
        f118:
                m_exit  118
        
        t119:
                // 16_BIT_ISA 4: cmn rd, rs
                mov     r0, #0
                mvn     r0, r0
                mov     r1, #1
                cmn     r0, r1
                bne     f119
        
                b       t120
        
        f119:
                m_exit  119
        
        t120:
                // 16_BIT_ISA 4: mul rd, rs
                mov     r0, #32
                mov     r1, #2
                mul     r0, r1
                cmp     r0, #64
                bne     f120
        
                b       t121
        
        f120:
                m_exit  120
        
        t121:
                // 16_BIT_ISA 5: Add to PC Alignment and flush
                mov     r0, #3
                add     pc, r0
                b       f121
                b       f121
        
                b       arithmetic_passed
        
        f121:
                m_exit  121

arithmetic_passed:


        ///////////////////////////////////////////////////////////////////////

        // Tests start at 150

        branches:
                // Tests for branches
        
        t150:
                // 16_BIT_ISA 18: b label
                mov     r7, #150
                b       t151
        
        t152:
                mov     r7, #152
                b       t153
        
        t151:
                mov     r7, #151
                b       t152
        
        t153:
                // 16_BIT_ISA 19: bl label
                mov     r7, #153
                bl      t154
        
        t155:
                mov     r7, #155
                mov     pc, lr
        
        t154:
                mov     r7, #154
                bl      t155
        
        t156:
                // 16_BIT_ISA 16: b<cond> label
                mov     r7, #156
                bne     t157
        
        t158:
                mov     r7, #158
                b       t159
        
        t157:
                mov     r7, #157
                bne     t158
        
        t159:
                mov     r0, #0
                beq     t160
        
        f159:
                m_exit  159
        
        t160:
                mov     r0, #1
                bne     t161
        
        f160:
                m_exit  160
        
        t161:
                mov     r0, #0
                cmp     r0, r0
                bcs     t162
        
        f161:
                m_exit  161
        
        t162:
                mov     r0, #0
                cmn     r0, r0
                bcc     t163
        
        f162:
                m_exit  162
        
        t163:
                mov     r0, #0
                mvn     r0, r0
                bmi     t164
        
        f163:
                m_exit  163
        
        t164:
                mov     r0, #0
                bpl     t165
        
        f164:
                m_exit  164
        
        t165:
                mov     r0, #1
                lsl     r0, #31
                sub     r0, #1
                bvs     t166
        
        f165:
                m_exit  165
        
        t166:
                mov     r0, #1
                lsl     r0, #31
                sub     r0, #1
                cmp     r0, r0
                bvc     t167
        
        f166:
                m_exit  166
        
        t167:
                // 16_BIT_ISA 5: bx label
                mov     r7, #167
                adr     r0, t168
                bx      r0
       
        .arm 
        .align 4
        t168:
                mov     r7, #168
                adr     r0, t169+1
                bx      r0
       
        .thumb_func
        .align 2 
        t169:
                mov     r7, #169
                adr     r0, branches_passed
                add     r0, #1
                bx      r0
        
        .align 4
        branches_passed:
                mov     r7, #0

        ///////////////////////////////////////////////////////////////////////

        // Tests start at 200

        r6ory:
                // Tests for r6ory operations
                mov     r6, #2
                lsl     r6, #24
        
        t200:
                // 16_BIT_ISA 6: ldr rd, [pc, imm8 << 2]
                mov     r0, #0
                mvn     r0, r0
                ldr     r1, [pc, #8]    // 5DA
                cmp     r1, r0          // 5DC
                bne     f200            // 5DE
        
                add     r6, #32         // 5E0
                b       t201            // 5E2

                .byte      0xFF         // 5E4
                .byte      0xFF
                .byte      0xFF
                .byte      0xFF
        
        f200:
                m_exit  200
        
        t201:
                // 16_BIT_ISA 7: <ldr|str> rd, [rb, ro]
                mov     r0, #0
                mvn     r0, r0
                mov     r1, #4
                str     r0, [r6, r1]
                ldr     r2, [r6, r1]
                cmp     r2, r0
                bne     f201
        
                add     r6, #32
                b       t202
        
        f201:
                m_exit  201
        
        t202:
                // 16_BIT_ISA 7: strb rd, [rb, ro]
                mov     r0, #0
                mvn     r0, r0
                mov     r1, #4
                strb    r0, [r6, r1]
                ldr     r2, [r6, r1]
                cmp     r2, #0xFF
                bne     f202
        
                add     r6, #32
                b       t203
        
        f202:
                m_exit  202
        
        t203:
                // 16_BIT_ISA 7: ldrb rd, [rb, ro]
                mov     r0, #0
                mvn     r0, r0
                mov     r1, #4
                str     r0, [r6, r1]
                ldrb    r2, [r6, r1]
                cmp     r2, #0xFF
                bne     f203
        
                add     r6, #32
                b       t204
        
        f203:
                m_exit  203
        
        t204:
                // 16_BIT_ISA 7: MisAligned load (rotated)
                mov     r0, #0
                mov     r1, #0xFF
                str     r1, [r6, r0]
                mov     r0, #1
                mov     r3, #8
                ror     r1, r3
                ldr     r2, [r6, r0]
                cmp     r2, r1
                bne     f204
        
                add     r6, #32
                b       t205
        
        f204:
                m_exit  204
        
        t205:
                // 16_BIT_ISA 8: strh rd, [rb, ro]
                mov     r0, #0
                mvn     r0, r0
                lsr     r1, r0, #16
                mov     r2, #4
                strh    r0, [r6, r2]
                ldr     r3, [r6, r2]
                cmp     r3, r1
                bne     f205
        
                add     r6, #32
                b       t206
        
        f205:
                m_exit  205
        
        t206:
                // 16_BIT_ISA 8: ldrh rd, [rb, ro]
                mov     r0, #0
                mvn     r0, r0
                lsr     r1, r0, #16
                mov     r2, #4
                str     r0, [r6, r2]
                ldrh    r3, [r6, r2]
                cmp     r3, r1
                bne     f206
        
                add     r6, #32
                b       t207
        
        f206:
                m_exit  206
        
        t207:
                // 16_BIT_ISA 8: ldrsb rd, [rb, ro]
                mov     r0, #0x7F
                mov     r1, #4
                str     r0, [r6, r1]
                ldrsb   r2, [r6, r1]
                cmp     r2, r0
                bne     f207
        
                add     r6, #32
                b       t208
        
        f207:
                m_exit  207
        
        t208:
                mov     r0, #0xFF
                mov     r1, #0
                mvn     r1, r1
                mov     r2, #4
                str     r0, [r6, r2]
                ldrsb   r3, [r6, r2]
                cmp     r3, r1
                bne     f208
        
                add     r6, #32
                b       t209
        
        f208:
                m_exit  208
        
        t209:
                // 16_BIT_ISA 8: ldrsh rd, [rb, ro]
                mov     r0, #0xFF
                lsl     r0, #4
                mov     r1, #4
                str     r0, [r6, r1]
                ldrsh   r2, [r6, r1]
                cmp     r2, r0
                bne     f209
        
                add     r6, #32
                b       t210
        
        f209:
                m_exit  209
        
        t210:
                mov     r0, #0xFF
                lsl     r0, #8
                mov     r1, #4
                str     r0, [r6, r1]
                ldrsh   r2, [r6, r1]
                mov     r3, #1
                lsl     r3, #31
                asr     r3, #23
                cmp     r3, r2
                bne     f210
        
                add     r6, #32
                b       t211
        
        f210:
                m_exit  210
        
        t211:
                // 16_BIT_ISA 8: MisAligned load half (rotated)
                mov     r0, #0
                mov     r1, #0xFF
                strh    r1, [r6, r0]
                add     r0, #1
                mov     r2, #8
                ror     r1, r2
                ldrh    r2, [r6, r0]
                cmp     r2, r1
                bne     f211
        
                add     r6, #32
                b       t212
        
        f211:
                m_exit  211
        
        t212:
                // 16_BIT_ISA 8: MisAligned load half signed (signed byte)
                mov     r0, #0
                mov     r1, #0xFF
                lsl     r1, #8
                strh    r1, [r6, r0]
                mvn     r1, r0
                add     r0, #1
                ldrsh   r2, [r6, r0]
                cmp     r2, r1
                bne     f212
        
                add     r6, #32
                b       t213
        
        f212:
                m_exit  212
        
        t213:
                // 16_BIT_ISA 9: <ldr|str> rd, [rb, imm5 << 2]
                mov     r0, #0
                mvn     r0, r0
                str     r0, [r6, #4]
                ldr     r1, [r6, #4]
                cmp     r1, r0
                bne     f213
        
                add     r6, #32
                b       t214
        
        f213:
                m_exit  213
        
        t214:
                // 16_BIT_ISA 9: strb rd, [rb, imm5]
                mov     r0, #0
                mvn     r0, r0
                strb    r0, [r6, #4]
                ldr     r1, [r6, #4]
                cmp     r1, #0xFF
                bne     f214
        
                add     r6, #32
                b       t215
        
        f214:
                m_exit  214
        
        t215:
                // 16_BIT_ISA 9: ldrb rd, [rb, imm5]
                mov     r0, #0
                mvn     r0, r0
                str     r0, [r6, #4]
                ldrb    r1, [r6, #4]
                cmp     r1, #0xFF
                bne     f215
        
                add     r6, #32
                b       t216
        
        f215:
                m_exit  215
        
        t216:
                // 16_BIT_ISA 9: MisAligned load (rotated)
                mov     r0, #0xFF
                str     r0, [r6]
                mov     r1, #8
                ror     r0, r1
                mov     r3, r6
                add     r3, #1
                ldr     r1, [r3]
                cmp     r1, r0
                bne     f216
        
                add     r6, #32
                b       t217
        
        f216:
                m_exit  216
        
        t217:
                // 16_BIT_ISA 10: strh rd, [rb, imm5 << 1]
                mov     r0, #0
                mvn     r0, r0
                lsr     r1, r0, #16
                strh    r0, [r6, #4]
                ldr     r2, [r6, #4]
                cmp     r2, r1
                bne     f217
        
                add     r6, #32
                b       t218
        
        f217:
                m_exit  217
        
        t218:
                // 16_BIT_ISA 10: ldrh rd, [rb, imm5 << 1]
                mov     r0, #0
                mvn     r0, r0
                lsr     r1, r0, #16
                str     r0, [r6, #4]
                ldrh    r2, [r6, #4]
                cmp     r2, r1
                bne     f218
        
                add     r6, #32
                b       t219
        
        f218:
                m_exit  218
        
        t219:
                // 16_BIT_ISA 10: MisAligned load half (rotated)
                mov     r0, #0xFF
                strh    r0, [r6]
                mov     r1, #8
                ror     r0, r1
                mov     r2, r6
                add     r2, #1
                ldrh    r1, [r2]
                cmp     r1, r0
                bne     f219
        
                add     r6, #32
                b       t220
        
        f219:
                m_exit  219
        
        t220:
                // 16_BIT_ISA 11: <ldr|str> rd, [sp, imm8 << 2]
                mov     r0, #0
                mvn     r0, r0
                str     r0, [sp, #4]
                ldr     r1, [sp, #4]
                cmp     r1, r0
                bne     f220
        
                add     r6, #32
                b       t221
        
        f220:
                m_exit  220
        
        t221:
                // 16_BIT_ISA 11: MisAligned load (rotated)
                mov     r0, #0xFF
                str     r0, [sp, #4]
                mov     r2, #8
                ror     r0, r2
                mov     r1, sp
                add     r1, #1
                mov     sp, r1
                ldr     r2, [sp, #4]
                sub     r1, #1
                mov     sp, r1
                cmp     r2, r0
                bne     f221
        
                add     r6, #32
                b       t222
        
        f221:
                m_exit  221
        
        t222:
                // 16_BIT_ISA 14: <push|pop> {rlist}
                mov     r0, #32
                mov     r1, #64
                push    {r0, r1}
                pop     {r2, r3}
                cmp     r0, r2
                bne     f222
                cmp     r1, r3
                bne     f222
        
                add     r6, #32
                b       t223
        
        f222:
                m_exit  222
        
        t223:
                // 16_BIT_ISA 14: Store LR / load PC
                adr     r0, t224
                mov     r0, r0
                mov     lr, r0
                push    {r1, lr}
                pop     {r1, pc}
        
        f223:
                m_exit  223
        
        .align 4
        t224:
                // 16_BIT_ISA 14: PC Alignment
                adr     r0, t225
                add     r0, #1
                mov     lr, r0
                push    {r1, lr}
                pop     {r1, pc}
        
        f224:
                m_exit  224
        
        .align 4
        t225:
                // 16_BIT_ISA 14: Push / pop do not Align base
                mov     r0, sp
                mov     r1, sp
                add     r1, #1
                mov     sp, r1
                push    {r2, r3}
                pop     {r2, r3}
                mov     r2, sp
                mov     sp, r0
                sub     r2, #1
                cmp     r2, r0
                bne     f225
        
                add     r6, #32
                b       t226
        
        f225:
                m_exit  225
        
        t226:
                // 16_BIT_ISA 15: <ldmia|stmia> rd!, {rlist}
                mov     r0, #1
                mov     r1, #2
                mov     r3, r6
                stmia   r3!, {r0, r1}
                sub     r3, #8
                cmp     r3, r6
                bne     f226
                ldmia   r3!, {r2, r4}
                sub     r3, #8
                cmp     r3, r6
                bne     f226
                cmp     r0, r2
                bne     f226
                cmp     r1, r4
                bne     f226
        
                add     r6, #32
                b       t227
        
        f226:
                m_exit  226
        
        t227:
                // 16_BIT_ISA 15: Load empty rlist
                adr     r0, t228
                mov     r0, r0
                str     r0, [r6]
                mov     r0, r6

                .hword 0xC800
        
        f227:
                m_exit  227
        
        .align 4
        t228:
                sub     r0, #0x40
                cmp     r0, r6
                bne     f228
        
                add     r6, #32
                b       t229
        
        f228:
                m_exit  228
        
        t229:
                // 16_BIT_ISA 15: Store empty rlist
                mov     r0, r6

                .hword 0xC000

                mov     r1, pc
                ldr     r2, [r6]
                cmp     r2, r1
                bne     f229
 
                sub     r0, #0x40
                cmp     r0, r6
                bne     f229
        
                add     r6, #32
                b       t230
        
        f229:
                m_exit  229
        
        t230:
                // 16_BIT_ISA 15: Base in rlist
                mov     r1, r6
                stm r1!, {r0-r3}
                sub     r1, #0x10
                ldm     r1!, {r2-r5}
                cmp     r1, r3
                bne     f230
        
                add     r6, #32
                b       t231
        
        f230:
                m_exit  230
        
        t231:
                // 16_BIT_ISA 15: Base in rlist
                mov     r2, r6
                stm r2!, {r0, r1, r2,r3}
                sub     r1, #0x10
                ldm     r1!, {r3-r6}
                cmp     r1, r4
                bne     f231
        
                add     r6, #32
                b       t232
        
        f231:
                m_exit  231
        
        t232:
                // 16_BIT_ISA 15: Base first in rlist
                mov     r1, r6
                stm r1!, {r1-r4}
                sub     r1, #0x10
                ldm     r1!, {r2-r5}
                cmp     r2, r6
                bne     f232
        
                add     r6, #32
                b       t233
        
        f232:
                m_exit  232
        
        t233:
                // 16_BIT_ISA 15: Load / store do not Align base
                mov     r0, r6
                add     r0, #1
                stm     r0!, {r1, r2}
                sub     r0, #8
                ldm     r0!, {r1, r2}
                sub     r0, #9
                cmp     r0, r6
                bne     f233
        
                add     r6, #32
                b       r6ory_passed
        
        f233:
                m_exit  233
        
        r6ory_passed:

///////////////////////////////////////////////////////////////////////////////

myThFunctionEnd:
        bx      lr

