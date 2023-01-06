// Based on the 32bit instruction tests by jsmolka. See github.com/jsmolka 

@ CPSR flag masks
.set FLAG_N,         0x80000000
.set FLAG_Z,         0x40000000
.set FLAG_C,         0x20000000
.set FLAG_V,         0x10000000
.set FLAG_NorFLAG_V, 0x90000000
.set FLAG_CorFLAG_V, 0x30000000

@ CPSR mode masks
.set MODE_USR, 0x10
.set MODE_FIQ, 0x11
.set MODE_IRQ, 0x12
.set MODE_SVC, 0x13
.set MODE_ABT, 0x17
.set MODE_SYS, 0x1F

.text

.macro m_exit test 
        ldr r12,=\test
        sub pc, pc, #12
.endm

_Reset:
   mov sp, #4000
   mov r12, #0

   ////////////////////////////////////////////////////////////////////////////

   // Conditionals test

        conditions:
                @ Tests for conditions
        
        t001:
                @ EQ - Z set
                msr     cpsr_f, FLAG_Z
                beq     t002
                m_exit  1
        
        t002:
                @ NE - Z clear
                msr     cpsr_f, 0
                bne     t003
                m_exit  2
        
        t003:
                @ CS - C set
                msr     cpsr_f, FLAG_C
                bcs     t004
                m_exit  3
        
        t004:
                @ CC - C clear
                msr     cpsr_f, 0
                bcc     t005
                m_exit  4
        
        t005:
                @ MI - N set
                msr     cpsr_f, FLAG_N
                bmi     t006
                m_exit  5
        
        t006:
                @ PL - N clear
                msr     cpsr_f, 0
                bpl     t007
                m_exit  6
        
        t007:
                @ VS - V set
                msr     cpsr_f, FLAG_V
                bvs     t008
                m_exit  7
        
        t008:
                @ VC - V clear
                msr     cpsr_f, 0
                bvc     t009
                m_exit  8
        
        t009:
                @ HI - C set and Z clear
                msr     cpsr_f, FLAG_C
                bhi     t010
                m_exit  9
        
        t010:
                @ LS - C clear and Z set
                msr     cpsr_f, FLAG_Z
                bls     t011
                m_exit  10
        
        t011:
                @ GE - N equals V
                msr     cpsr_f, 0
                bge     t012
                m_exit  11
        
        t012:
                msr     cpsr_f, FLAG_NorFLAG_V
                bge     t013
                m_exit  12
        
        t013:
                @ LT - N not equals to V
                msr     cpsr_f, FLAG_N
                blt     t014
                m_exit  13
        
        t014:
                msr     cpsr_f, FLAG_V
                blt     t015
                m_exit  14
        
        t015:
                @ GT - Z clear and (N equals V)
                msr     cpsr_f, 0
                bgt     t016
                m_exit  15
        
        t016:
                msr     cpsr_f, FLAG_NorFLAG_V
                bgt     t017
                m_exit  16
        
        t017:
                @ LE - Z set or (N not equal to V)
                msr     cpsr_f, FLAG_Z
                ble     t018
                m_exit  17
        
        t018:
                msr     cpsr_f, FLAG_N
                ble     t019
                m_exit  18
        
        t019:
                msr     cpsr_f, FLAG_V
                ble     t020
                m_exit  19
        
        t020:
                @ AL - always
                bal     conditions_passed
                m_exit  20
        
        conditions_passed:

   ////////////////////////////////////////////////////////////////////////////

        branches:
                @ Tests for branch operations
        
        t050:
                @ ARM 1: Branch with exchange
                mov     r12, #50
                adr     r0, t051+1
                bx      r0
        
        .thumb_func
        .align 2
        t051:
                @ THUMB 5: Branch with exchange
                mov     r0, #51
                mov     r12, r0
                adr     r0, t052
                bx      r0
        
        .arm
        .align 4
        t052:
                @ ARM 1: Branch without exchange
                mov     r12, #52
                adr     r0, t053
                bx      r0
        
        t053:
                @ ARM 2: Branch forward
                mov     r12, #53
                b       t054
        
        t055:
                @ ARM 2: Branch forward
                mov     r12, #55
                b       t056
        
        t054:
                @ ARM 2: Branch backward
                mov     r12, #54
                b       t055
        
        t057:
                @ ARM 2: Test link
                mov     r12, #57
                mov     pc, lr
        
        t056:
                @ ARM 2: Branch with link
                mov     r12, #56
                bl      t057
        
        branches_passed:
                mov     r12, #0

   ////////////////////////////////////////////////////////////////////////////

        flags:
                @ Tests for flags
        
        t100:
                @ Zero flag
                movs    r0, #0
                bne     f100
        
                movs    r0, #1
                beq     f100
        
                b       t101
        
        f100:
                m_exit  100
        
        t101:
                @ Negative flag
                movs    r0, #0x80000000
                bpl     f101
        
                movs    r0, #0
                bmi     f101
        
                b       t102
        
        f101:
                m_exit  101
        
        t102:
                @ Carry flag addition
                mvn     r0, #0
                adds    r0, #1
                bcc     f102
        
                mov     r0, #0
                adds    r0, #1
                bcs     f102
        
                b       t103
        
        f102:
                m_exit  102
        
        t103:
                @ Carry flag addition with carry
                mvn     r0, #0
                sub     r0, #1
                msr     cpsr_f, FLAG_C
                adcs    r0, #1
                bcc     f103
        
                mov     r0, #0
                msr     cpsr_f, FLAG_C
                adcs    r0, #1
                bcs     f103
        
                b       t104
        
        f103:
                m_exit  103
        
        t104:
                @ Carry flag subtraction
                mov     r0, #1
                subs    r0, #0
                bcc     f104
        
                mov     r0, #1
                subs    r0, #1
                bcc     f104
        
                mov     r0, #1
                subs    r0, #2
                bcs     f104
        
                b       t105
        
        f104:
                m_exit  104
        
        t105:
                @ Carry flag subtraction with carry
                mov     r0, #2
                msr     cpsr_f, #0
                sbcs    r0, #0
                bcc     f105
        
                mov     r0, #2
                msr     cpsr_f, #0
                sbcs    r0, #1
                bcc     f105
        
                mov     r0, #2
                msr     cpsr_f, #0
                sbcs    r0, #2
                bcs     f105
        
                b       t106
        
        f105:
                m_exit  105
        
        t106:
                @ Overflow flag addition
                mov     r0, #0x7FFFFFFF
                adds    r0, #1
                bvc     f106
        
                mov     r0, #0
                adds    r0, #1
                bvs     f106
        
                b       t107
        
        f106:
                m_exit  106
        
        t107:
                @ Overflow flag addition with carry
                mov     r0, #0x7FFFFFFE
                msr     cpsr_f, FLAG_C
                adcs    r0, #1
                bvc     f107
        
                mov     r0, #0
                msr     cpsr_f, FLAG_C
                adcs    r0, #1
                bvs     f107
        
                b       t108
        
        f107:
                m_exit  107
        
        t108:
                @ Overflow flag subtraction
                mov     r0, #0x80000000
                subs    r0, #1
                bvc     f108
        
                mov     r0, #1
                subs    r0, #1
                bvs     f108
        
                b       t109
        
        f108:
                m_exit  108
        
        t109:
                @ Overflow flag subtraction with carry
                mov     r0, #0x80000001
                msr     cpsr_f, #0
                sbcs    r0, #1
                bvc     f109
        
                mov     r0, #2
                msr     cpsr_f, #0
                sbcs    r0, #1
                bvs     f109
        
                b       flags_passed
        
        f109:
                m_exit  109
        
        flags_passed:

        ///////////////////////////////////////////////////////////////////////

        shifts:
                @ Tests for shift operations
        
        t150:
                @ Logical shift left
                mov     r0, #1
                lsl     r0, #6
                cmp     r0, #64
                bne     f150
        
                b       t151
        
        f150:
                m_exit  150
        
        t151:
                @ Logical shift left carry
                mov     r0, #1
                lsls    r0, #31
                bcs     f151
        
                mov     r0, #2
                lsls    r0, #31
                bcc     f151
        
                b       t152
        
        f151:
                m_exit  151
        
        t152:
                @ Logical shift left by 32
                mov     r0, #1
                mov     r1, #32
                lsls    r0, r1
                bne     f152
                bcc     f152
        
                b       t153
        
        f152:
                m_exit  152
        
        t153:
                @ Logical shift left by greater 32
                mov     r0, #1
                mov     r1, #33
                lsls    r0, r1
                bne     f153
                bcs     f153
        
                b       t154
        
        f153:
                m_exit  153
        
        t154:
                @ Logical shift right
                mov     r0, #64
                lsr     r0, #6
                cmp     r0, #1
                bne     f154
        
                b       t155
        
        f154:
                m_exit  154
        
        t155:
                @ Logical shift right carry
                mov     r0, #2
                lsrs    r0, #1
                bcs     f155
        
                mov     r0, #1
                lsrs    r0, #1
                bcc     f155
        
                b       t156
        
        f155:
                m_exit  155
        
        t156:
                @ Logical shift right special
                mov     r0, #1
                lsrs    r0, #32
                bne     f156
                bcs     f156
        
                mov     r0, #0x80000000
                lsrs    r0, #32
                bne     f156
                bcc     f156
        
                b       t157
        
        f156:
                m_exit  156
        
        t157:
                @ Logical shift right by greater 32
                mov     r0, #0x80000000
                mov     r1, #33
                lsrs    r0, r1
                bne     f157
                bcs     f157
        
                b       t158
        
        f157:
                m_exit  157
        
        t158:
                @ Arithmetic shift right
                mov     r0, #64
                asr     r0, #6
                cmp     r0, #1
                bne     f158
        
                mov     r0, #0x80000000
                asr     r0, #31
                mvn     r1, #0
                cmp     r1, r0
                bne     f158
        
                b       t159
        
        f158:
                m_exit  158
        
        t159:
                @ Arithmetic shift right carry
                mov     r0, #2
                asrs    r0, #1
                bcs     f159
        
                mov     r0, #1
                asrs    r0, #1
                bcc     f159
        
                b       t160
        
        f159:
                m_exit  159
        
        t160:
                @ Arithmetic shift right special
                mov     r0, #1
                asrs    r0, #32
                bne     f160
                bcs     f160
        
                mov     r0, #0x80000000
                asrs    r0, #32
                bcc     f160
                mvn     r1, #0
                cmp     r1, r0
                bne     f160
        
                b       t161
        
        f160:
                m_exit  160
        
        t161:
                @ Rotate right
                mov     r0, #1
                ror     r0, #1
                cmp     r0, #0x80000000
                bne     f161
        
                b       t162
        
        f161:
                m_exit  161
        
        t162:
                @ Rotate right carry
                mov     r0, #2
                rors    r0, #1
                bcs     f162
        
                mov     r0, #1
                rors    r0, #1
                bcc     f162
        
                b       t163
        
        f162:
                m_exit  162
        
        t163:
                @ Rotate right special
                msr     cpsr_f, FLAG_C
                mov     r0, #1
                rrxs    r0,r0
                bcc     f163
                bpl     f163
        
                msr     cpsr_f, #0
                mov     r0, #1
                rrxs    r0,r0
                bcc     f163
                bne     f163
        
                b       t164
        
        f163:
                m_exit  163
        
        t164:
                @ Rotate right by 32
                mov     r0, #0x80000000
                mov     r1, #32
                rors    r0, r1
                bcc     f164
                cmp     r0, #0x80000000
                bne     f164
        
                b       t165
        
        f164:
                m_exit  164
        
        t165:
                @ Rotate right by greater 32
                mov     r0, #2
                mov     r1, #33
                ror     r0, r1
                cmp     r0, #1
                bne     f165
        
                b       t166
        
        f165:
                m_exit  165
        
        t166:
                @ Shift by 0 register value
                msr     cpsr_f, FLAG_C
                mov     r0, #1
                mov     r1, #0
                lsls    r0, r1
                lsrs    r0, r1
                asrs    r0, r1
                rors    r0, r1
                bcc     f166
                cmp     r0, #1
                bne     f166
        
                b       t167
        
        f166:
                m_exit  166
        
        t167:
                @ Shift saved in lowest byte
                mov     r0, #1
                mov     r1, #0xF10
                lsl     r0, r1
                cmp     r0, #65536
                bne     f167
        
                b       t168
        
        f167:
                m_exit  167
        
        t168:
                @ Logical shift right by 32
                mov     r0, #0x80000000
                mov     r1, #32
                lsr     r0, r1
                bcc     f168
        
                b       shifts_passed
        
        f168:
                m_exit  168
        
        shifts_passed:

        ///////////////////////////////////////////////////////////////////////

        data_processing:
                @ Tests for the data processing instruction
        
        t200:
                @ ARM 3: Move
                mov     r0, #32
                cmp     r0, #32
                bne     f200
        
                b       t201
        
        f200:
                m_exit  200
        
        t201:
                @ ARM 3: Move negative
                mvn     r0, #0
                adds    r0, #1
                bne     f201
        
                b       t202
        
        f201:
                m_exit  201
        
        t202:
                @ ARM 3: And
                mov     r0, #0xFF
                and     r0, #0x0F
                cmp     r0, #0x0F
                bne     f202
        
                b       t203
        
        f202:
                m_exit  202
        
        t203:
                @ ARM 3: Exclusive or
                mov     r0, #0xFF
                eor     r0, #0xF0
                cmp     r0, #0x0F
                bne     f203
        
                b       t204
        
        f203:
                m_exit  203
        
        t204:
                @ ARM 3: Or
                mov     r0, #0xF0
                orr     r0, #0x0F
                cmp     r0, #0xFF
                bne     f204
        
                b       t205
        
        f204:
                m_exit  204
        
        t205:
                @ ARM 3: Bit clear
                mov     r0, #0xFF
                bic     r0, #0x0F
                cmp     r0, #0xF0
                bne     f205
        
                b       t206
        
        f205:
                m_exit  205
        
        t206:
                @ ARM 3: Add
                mov     r0, #32
                add     r0, #32
                cmp     r0, #64
                bne     f206
        
                b       t207
        
        f206:
                m_exit  206
        
        t207:
                @ ARM 3: Add with carry
                msr     cpsr_f, #0
                movs    r0, #32
                adc     r0, #32
                cmp     r0, #64
                bne     f207
        
                msr     cpsr_f, FLAG_C
                mov     r0, #32
                adc     r0, #32
                cmp     r0, #65
                bne     f207
        
                b       t208
        
        f207:
                m_exit  207
        
        t208:
                @ ARM 3: Subtract
                mov     r0, #64
                sub     r0, #32
                cmp     r0, #32
                bne     f208
        
                b       t209
        
        f208:
                m_exit  208
        
        t209:
                @ ARM 3: Reverse subtract
                mov     r0, #32
                rsb     r0, #64
                cmp     r0, #32
                bne     f209
        
                b       t210
        
        f209:
                m_exit  209
        
        t210:
                @ ARM 3: Subtract with carry
                msr     cpsr_f, 0
                mov     r0, #64
                sbc     r0, #32
                cmp     r0, #31
                bne     f210
        
                msr     cpsr_f, FLAG_C
                mov     r0, #64
                sbc     r0, #32
                cmp     r0, #32
                bne     f210
        
                b       t211
        
        f210:
                m_exit  210
        
        t211:
                @ ARM 3: Reverse subtract with carry
                msr     cpsr_f, 0
                mov     r0, #32
                rsc     r0, #64
                cmp     r0, #31
                bne     f211
        
                msr     cpsr_f, FLAG_C
                mov     r0, #32
                rsc     r0, #64
                cmp     r0, #32
                bne     f211
        
                b       t212
        
        f211:
                m_exit  211
        
        t212:
                @ ARM 3: Compare
                mov     r0, #32
                cmp     r0, r0
                bne     f212
        
                b       t213
        
        f212:
                m_exit  212
        
        t213:
                @ ARM 3: Compare negative
                mov     r0, #0x80000000
                cmn     r0, r0
                bne     f213
        
                b       t214
        
        f213:
                m_exit  213
        
        t214:
                @ ARM 3: Test
                mov     r0, #0xF0
                tst     r0, #0x0F
                bne     f214
        
                b       t215
        
        f214:
                m_exit  214
        
        t215:
                @ ARM 3: Test equal
                mov     r0, #0xFF
                teq     r0, #0xFF
                bne     f215
        
                b       t216
        
        f215:
                m_exit  215
        
        t216:
                @ ARM 3: Operand types
                mov     r0, #0xFF00
                mov     r1, #0x00FF
                mov     r1, r1, lsl #8
                cmp     r1, r0
                bne     f216
        
                b       t217
        
        f216:
                m_exit  216
        
        t217:
                @ ARM 3: Update carry for rotated immediate
                movs    r0, #0xF000000F
                bcc     f217
        
                movs    r0, #0x0FF00000
                bcs     f217
        
                b       t218
        
        f217:
                m_exit  217
        
        t218:
                @ ARM 3: Update carry for rotated register
                mov     r0, #0xFF
                mov     r1, #4
                movs    r2, r0, ror r1
                bcc     f218
        
                mov     r0, #0xF0
                mov     r1, #4
                movs    r2, r0, ror r1
                bcs     f218
        
                b       t219
        
        f218:
                m_exit  218
        
        t219:
                @ ARM 3: Update carry for rotated register
                mov     r0, #0xFF
                movs    r1, r0, ror #4
                bcc     f219
        
                mov     r0, #0xF0
                movs    r1, r0, ror #4
                bcs     f219
        
                b       t220
        
        f219:
                m_exit  219
        
        t220:
                @ ARM 3: Register shift special
                mov     r0, #0
                msr     cpsr_f, FLAG_C
                movs    r0, r0, rrx
                bcs     f220
                cmp     r0, #0x80000000
                bne     f220
        
                b       t221
        
        f220:
                m_exit  220
        
        t221:
                @ ARM 3: PC as operand
                add     r0, pc, #4
                cmp     r0, pc
                bne     f221
        
                b       t222
        
        f221:
                m_exit  221
        
        t222:
                @ ARM 3: PC as destination
                adr     r0, t223
                mov     pc, r0
        
        f222:
                m_exit  222
        
        t223:
                @ ARM 3: PC as destination with S bit
                mov     r8, #32
                msr     cpsr, MODE_FIQ
                mov     r8, #64
                msr     spsr, MODE_SYS
                subs    pc, #4
                cmp     r8, #32
                bne     f223
        
                b       t226
        
        f223:
                m_exit  226
        
       
        t226:
                @ ARM 3: PC as operand 1 with shifted register with immediate shift amount
                mov     r0, #0
                mov     r2, lr
                bl      .get_pc
        .get_pc:
                mov     r1, lr          // R1 points to itself.
                mov     lr, r2          // Restore LR.
                add     r0, pc, r0      // R0 points to CMP R1, R0
                add     r1, #16         // R1 also points to CMP R1, R0
                cmp     r1, r0
                bne     f226
        
                b       t227
        f226:
                m_exit  226
        
        t227:
                @ ARM 3: Rotated immediate logical operation
                msr     cpsr_f, #0
                movs    r0, #0x80000000
                bcc     f227
                bpl     f227
        
                b       t228
        
        f227:
                m_exit  227
        
        t228:
                @ ARM 3: Rotated immediate arithmetic operation
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                adcs    r0, #0x80000000
                cmp     r0, #0x80000001
                bne     f228
        
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                adcs    r0, #0x70000000
                cmp     r0, #0x70000001
                bne     f228
        
                b       t229
        
        f228:
                m_exit  228
        
        t229:
                @ ARM 3: Immediate shift logical operation
                msr     cpsr_f, #0
                mov     r0, #0x80
                movs    r0, r0, ror #8
                bcc     f229
                bpl     f229
        
        
                b       t230
        
        f229:
                m_exit  229
        
        t230:
                @ ARM 3: Immediate shift arithmetic operation
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                mov     r1, #0x80
                adcs    r0, r1, ror #8
                cmp     r0, #0x80000001
                bne     f230
        
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                mov     r1, #0x70
                adcs    r0, r1, ror #8
                cmp     r0, #0x70000001
                bne     f230
        
                b       t231
        
        f230:
                m_exit  230
        
        t231:
                @ ARM 3: Register shift logical operation
                msr     cpsr_f, #0
                mov     r0, #0x80
                mov     r1, #8
                movs    r0, r0, ror r1
                bcc     f231
                bpl     f231
        
                b       t232
        
        f231:
                m_exit  231
        
        t232:
                @ ARM 3: Register shift arithmetic operation
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                mov     r1, #0x80
                mov     r2, #8
                adcs    r0, r1, ror r2
                cmp     r0, #0x80000001
                bne     f232
        
                msr     cpsr_f, FLAG_C
                mov     r0, #0
                mov     r1, #0x70
                mov     r2, #8
                adcs    r0, r1, ror r2
                cmp     r0, #0x70000001
                bne     f232
        
                b       t233
        
        f232:
                m_exit  232
        
        t233:
                @ ARM 3: TST / TEQ setting flags during shifts
                msr     cpsr_f, #0
                tst     r0, #0x80000000
                bcc     f233
        
                msr     cpsr_f, #0
                teq     r0, #0x80000000
                bcc     f233
        
                b       t234
        
        f233:
                m_exit  233
        

        t234:        
        b       data_processing_passed
        
        data_processing_passed:

        psr_transfer:
                @ Tests for the PSR transfer instruction
        
        t250:
                @ ARM 4: Read / write PSR
                mrs     r0, cpsr
                bic     r0, #0xF0000000
                msr     cpsr, r0
                beq     f250
                bmi     f250
                bcs     f250
                bvs     f250
        
                b       t251
        
        f250:
                m_exit  250
        
        t251:
                @ ARM 4: Write flag bits
                msr     cpsr_f, #0xF0000000
                bne     f251
                bpl     f251
                bcc     f251
                bvc     f251
        
                b       t252
        
        f251:
                m_exit  251
        
        t252:
                @ ARM 4: Write control bits
                msr     cpsr_c, MODE_FIQ
                mrs     r0, cpsr
                and     r0, #0x1F
                cmp     r0, #MODE_FIQ
                bne     f252
        
                msr     cpsr_c, MODE_SYS
        
                b       t253
        
        f252:
                m_exit  252
        
        t253:
                @ ARM 4: Register banking
                mov     r0, #16
                mov     r8, #32
                msr     cpsr_c, MODE_FIQ
                mov     r0, #32
                mov     r8, #64
                msr     cpsr_c, MODE_SVC
                cmp     r0, #32
                bne     f253
                cmp     r8, #32
                bne     f253
        
                b       t254
        
        f253:
                m_exit  253
        
        t254:
                @ ARM 4: Accessing SPSR
                mrs     r0, cpsr
                msr     spsr, r0
                mrs     r1, spsr
                cmp     r1, r0
                bne     f254
        
                b       psr_transfer_passed
        
        f254:
                m_exit  254
        
        psr_transfer_passed:

        multiply:
                @ Tests for multiply operations
        
        t300:
                @ ARM 5: Multiply
                mov     r0, #4
                mov     r1, #8
                mul     r0, r1, r0
                cmp     r0, #32
                bne     f300
        
                b       t301
        
        f300:
                m_exit  300
        
        t301:
                mov     r0, #-4
                mov     r1, #-8
                mul     r0, r1, r0
                cmp     r0, #32
                bne     f301
        
                b       t302
        
        f301:
                m_exit  301
        
        t302:
                mov     r0, #4
                mov     r1, #-8
                mul     r0, r1, r0
                cmp     r0, #-32
                bne     f302
        
                b       t303
        
        f302:
                m_exit  302
        
        t303:
                @ ARM 5: Multiply accumulate
                mov     r0, #4
                mov     r1, #8
                mov     r2, #8
                mla     r0, r1, r0, r2
                cmp     r0, #40
                bne     t303f
        
                b       t304
        
        t303f:
                m_exit  303
        
        t304:
                mov     r0, #4
                mov     r1, #8
                mov     r2, #-8
                mla     r0, r1, r0, r2
                cmp     r0, #24
                bne     f304
        
                b       t305
        
        f304:
                m_exit  304
        
        t305:
                @ ARM 6: Unsigned multiply long
                mov     r0, #4
                mov     r1, #8
                umull   r2, r3, r0, r1
                cmp     r2, #32
                bne     f305
                cmp     r3, #0
                bne     f305
        
                b       t306
        
        f305:
                m_exit  305
        
        t306:
                mov     r0, #-1
                mov     r1, #-1
                umull   r2, r3, r0, r1
                cmp     r2, #1
                bne     f306
                cmp     r3, #-2
                bne     f306
        
                b       t307
        
        f306:
                m_exit  306
        
        t307:
                mov     r0, #2
                mov     r1, #-1
                umull   r2, r3, r0, r1
                cmp     r2, #-2
                bne     f307
                cmp     r3, #1
                bne     f307
        
                b       t308
        
        f307:
                m_exit  307
        
        t308:
                @ ARM 6: Unsigned multiply long accumulate
                mov     r0, #4
                mov     r1, #8
                mov     r2, #8
                mov     r3, #4
                umlal   r2, r3, r0, r1
                cmp     r2, #40
                bne     f308
                cmp     r3, #4
                bne     f308
        
                b       t309
        
        f308:
                m_exit  308
        
        t309:
                mov     r0, #-1
                mov     r1, #-1
                mov     r2, #-2
                mov     r3, #1
                umlal   r2, r3, r0, r1
                cmp     r2, #-1
                bne     f309
                cmp     r3, #-1
                bne     f309
        
        
                b       t310
        
        f309:
                m_exit  309
        
        t310:
                @ ARM 6: Signed multiply long
                mov     r0, #4
                mov     r1, #8
                smull   r2, r3, r0, r1
                cmp     r2, #32
                bne     f310
                cmp     r3, #0
                bne     f310
        
                b       t311
        
        f310:
                m_exit  310
        
        t311:
                mov     r0, #-4
                mov     r1, #-8
                smull   r2, r3, r0, r1
                cmp     r2, #32
                bne     f311
                cmp     r3, #0
                bne     f311
        
                b       t312
        
        f311:
                m_exit  311
        
        t312:
                mov     r0, #4
                mov     r1, #-8
                smull   r2, r3, r0, r1
                cmp     r2, #-32
                bne     f312
                cmp     r3, #-1
                bne     f312
        
                b       t313
        
        f312:
                m_exit  312
        
        t313:
                @ ARM 6: Signed multiply long accumulate
                mov     r0, #4
                mov     r1, #8
                mov     r2, #8
                mov     r3, #4
                smlal   r2, r3, r0, r1
                cmp     r2, #40
                bne     f313
                cmp     r3, #4
                bne     f313
        
                b       t314
        
        f313:
                m_exit  313
        
        t314:
                mov     r0, #4
                mov     r1, #-8
                mov     r2, #32
                mov     r3, #0
                smlal   r2, r3, r0, r1
                cmp     r2, #0
                bne     f314
                cmp     r3, #0
                bne     f314
        
                b       t315
        
        f314:
                m_exit  314
        
        t315:
                @ ARM 6: Negative flag
                mov     r0, #2
                mov     r1, #1
                umulls  r2, r3, r0, r1
                bmi     f315
        
                mov     r0, #2
                mov     r1, #-1
                smulls  r2, r3, r0, r1
                bpl     f315
        
                b       t316
        
        f315:
                m_exit  315
        
        t316:
                @ ARM 5: Not affecting carry and overflow
                msr     cpsr_f, 0
                mov     r0, #1
                mov     r1, #1
                mul     r0, r1, r0
                bcs     f316
                bvs     f316
        
                b       t317
        
        f316:
                m_exit  316
        
        t317:
                msr     cpsr_f, FLAG_CorFLAG_V
                mov     r0, #1
                mov     r1, #1
                mul     r0, r1, r0
                bcc     f317
                bvc     f317
        
                b       t318
        
        f317:
                m_exit  317
        
        t318:
                @ ARM 6: Not affecting carry and overflow
                msr     cpsr_f, 0
                mov     r0, #1
                mov     r1, #1
                umull   r2, r3, r0, r1
                bcs     f318
                bvs     f318
        
                b       t319
        
        f318:
                m_exit  318
        
        t319:
                msr     cpsr_f, FLAG_CorFLAG_V
                mov     r0, #1
                mov     r1, #1
                umull   r2, r3, r0, r1
                bcc     f319
                bvc     f319
        
                b       multiply_passed
        
        f319:
                m_exit  319
        
        multiply_passed:

        single_transfer:
                ldr     r11, =#0x02000000
        
        t350:
                @ ARM 7: Load / store word
                mvn     r0, #0
                str     r0, [r11]
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f350
        
                add     r11, #32
                b       t351
        
        f350:
                m_exit  350
        
        t351:
                @ ARM 7: Store byte
                mvn     r0, #0
                strb    r0, [r11]
                ldr     r1, [r11]
                cmp     r1, #0xFF
                bne     f351
        
                add     r11, #32
                b       t352
        
        f351:
                m_exit  351
        
        t352:
                @ ARM 7: Load byte
                mvn     r0, #0
                str     r0, [r11]
                ldrb    r1, [r11]
                cmp     r1, #0xFF
                bne     f352
        
                add     r11, #32
                b       t353
        
        f352:
                m_exit  352
        
        t353:
                @ ARM 7: Indexing, writeback and offset types
                mov     r0, #32
                mov     r1, #1
                mov     r2, r11
                str     r0, [r2], #4
                ldr     r3, [r2, -r1, lsl #2]!
                cmp     r3, r0
                bne     f353
                cmp     r2, r11
                bne     f353
        
                add     r11, #32
                b       t354
        
        f353:
                m_exit  353
        
        t354:
                @ ARM 7: Misaligned store
                mov     r0, #32
                str     r0, [r11, #3]
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f354
        
                add     r11, #32
                b       t355
        
        f354:
                m_exit  354
        
        t355:
                @ ARM 7: Misaligned load (rotated)
                mov     r0, #32
                str     r0, [r11]
                ldr     r1, [r11, #3]
                cmp     r1, r0, ror #24
                bne     f355
        
                add     r11, #32
                b       t356
        
        f355:
                m_exit  355
        
        t356:
                @ ARM 7: Store PC + 4
                str     pc, [r11]      // mem = x+8
                mov     r0, pc         // r0 = y+8 = x+12
                ldr     r1, [r11]      // r1 = x+8
                add     r1, #4         // r1 = x+12
                cmp     r1, r0         
                bne     f356
        
                add     r11, #32
                b       t357
        
        f356:
                m_exit  356
        
        t357:
                @ ARM 7: Load into PC
                adr     r0, t362
                str     r0, [r11]
                ldr     pc, [r11], #32
        
        f357:
                m_exit  362
        
        t362:
                @ ARM 7: Special shifts as offset
                mov     r0, #0
                mov     r1, #0
                msr     cpsr_f, FLAG_C
                ldr     r2, [r1, r0, rrx]!
                cmp     r1, #0x80000000
                bne     f362
                bcc     f362
        
                add     r11, #32
                b       t363
        
        f362:
                m_exit  362
        
        t363:
                @ ARM 7: Load current instruction
                ldr     r0, [pc, #-8]
                ldr     r1,=0xE51F0008
                bne     f363
        
                add     r11, #32
                b       single_transfer_passed
        
        f363:
                m_exit  363
        
        single_transfer_passed:

        halfword_transfer:
                @ Tests for the halfword data transfer instruction
                ldr     r11,=0x02000000
                add     r11, #0x1500
        
        t400:
                @ ARM 8: Store halfword
                mvn     r0, #0
                strh    r0, [r11]
                lsr     r0, #16
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f400
        
                add     r11, #32
                b       t401
        
        f400:
                m_exit  400
        
        t401:
                @ ARM 8: Load halfword
                mvn     r0, #0
                str     r0, [r11]
                lsr     r0, #16
                ldrh    r1, [r11]
                cmp     r1, r0
                bne     f401
        
                add     r11, #32
                b       t402
        
        f401:
                m_exit  401
        
        t402:
                @ ARM 8: Load unsigned halfword
                mov     r0, #0x7F00
                strh    r0, [r11]
                ldrsh   r1, [r11]
                cmp     r1, r0
                bne     f402
        
                add     r11, #32
                b       t403
        
        f402:
                m_exit  402
        
        t403:
                @ ARM 8: Load signed halfword
                mov     r0, #0xFF00
                strh    r0, [r11]
                mvn     r0, #0xFF
                ldrsh   r1, [r11]
                cmp     r1, r0
                bne     f403
        
                add     r11, #32
                b       t404
        
        f403:
                m_exit  403
        
        t404:
                @ ARM 8: Load unsigned byte
                mov     r0, #0x7F
                strb    r0, [r11]
                ldrsb   r1, [r11]
                cmp     r1, r0
                bne     f404
        
                add     r11, #32
                b       t405
        
        f404:
                m_exit  404
        
        t405:
                @ ARM 8: Load signed byte
                mov     r0, #0xFF
                strb    r0, [r11]
                mvn     r0, #0
                ldrsb   r1, [r11]
                cmp     r1, r0
                bne     f405
        
                add     r11, #32
                b       t406
        
        f405:
                m_exit  405
        
        t406:
                @ ARM 8: Indexing, writeback and offset types
                mov     r0, #32
                mov     r1, #4
                mov     r2, r11
                strh    r0, [r2], #4
                ldrh    r3, [r2, -r1]!
                cmp     r3, r0
                bne     f406
                cmp     r2, r11
                bne     f406
        
                add     r11, #32
                b       t407
        
        f406:
                m_exit  406
        
        t407:
                @ ARM 8: Aligned store halfword
                mov     r0, #32
                strh    r0, [r11, #1]
                ldrh    r1, [r11]
                cmp     r1, r0
                bne     f407
        
                add     r11, #32
                b       halfword_transfer_passed
        
        f407:
                m_exit  407
        
        halfword_transfer_passed:

        data_swap:
                @ Tests for the data swap instruction
                ldr     r11, =#0x02000000
                add     r11, #0x3000
        
        t450:
                @ ARM 10: Swap word
                mvn     r0, #0
                str     r0, [r11]
                swp     r1, r0, [r11]
                cmp     r1, r0
                bne     f450
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f450
        
                add     r11, #32
                b       t451
        
        f450:
                m_exit  450
        
        t451:
                @ ARM 10: Swap byte
                mvn     r0, #0
                str     r0, [r11]
                swpb    r1, r0, [r11]
                cmp     r1, #0xFF
                bne     f451
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f451
        
                add     r11, #32
                b       t452
        
        f451:
                m_exit  451
        
        t452:
                @ ARM 10: Misaligned swap
                mov     r0, #32
                mov     r1, #64
                str     r1, [r11]
                add     r2, r11, #1
                swp     r3, r0, [r2]
                cmp     r3, r1, ror #8
                bne     f452
                ldr     r3, [r11]
                cmp     r3, r0
                bne     f452
        
                add     r11, #32
                b       t453
        
        f452:
                m_exit  452
        
        t453:
                @ ARM 10: Same source and destination
                mov     r0, #32
                str     r0, [r11]
                mov     r0, #64
                swp     r0, r0, [r11]
                cmp     r0, #32
                bne     f453
                ldr     r0, [r11]
                cmp     r0, #64
                bne     f453
        
                b       data_swap_passed
        
        f453:
                m_exit  453
        
        data_swap_passed:

        block_transfer:
                @ Tests for the block transfer instruction
                ldr     r11, =0x02000000
                add     r11, #0x4500
        
        t500:
                @ ARM 10: Fully ascending
                mov     r0, #32
                mov     r1, #64
                stmfa   r11!, {r0, r1}
                ldmfa   r11!, {r2, r3}
                cmp     r0, r2
                bne     f500
                cmp     r1, r3
                bne     f500
        
                add     r11, #32
                b       t501
        
        f500:
                m_exit  500
        
        t501:
                @ ARM 10: Empty ascending
                mov     r0, #32
                mov     r1, #64
                stmea   r11!, {r0, r1}
                ldmea   r11!, {r2, r3}
                cmp     r0, r2
                bne     f501
                cmp     r1, r3
                bne     f501
        
                add     r11, #32
                b       t502
        
        f501:
                m_exit  501
        
        t502:
                @ ARM 10: Fully descending
                mov     r0, #32
                mov     r1, #64
                stmfd   r11!, {r0, r1}
                ldmfd   r11!, {r2, r3}
                cmp     r0, r2
                bne     f502
                cmp     r1, r3
                bne     f502
        
                add     r11, #32
                b       t503
        
        f502:
                m_exit  502
        
        t503:
                @ ARM 10: Empty descending
                mov     r0, #32
                mov     r1, #64
                stmed   r11!, {r0, r1}
                ldmed   r11!, {r2, r3}
                cmp     r0, r2
                bne     f503
                cmp     r1, r3
                bne     f503
        
                add     r11, #32
                b       t504
        
        f503:
                m_exit  503
        
        t504:
                @ ARM 10: Location fully ascending
                mov     r0, #32
                stmfa   r11, {r0, r1}
                ldr     r1, [r11, #4]
                cmp     r1, r0
                bne     f504
        
                add     r11, #32
                b       t505
        
        f504:
                m_exit  504
        
        t505:
                @ ARM 10: Location empty ascending
                mov     r0, #32
                stmea   r11, {r0, r1}
                ldr     r1, [r11]
                cmp     r1, r0
                bne     f505
        
                add     r11, #32
                b       t506
        
        f505:
                m_exit  505
        
        t506:
                @ ARM 10: Location fully descending
                mov     r0, #32
                stmfd   r11, {r0, r1}
                ldr     r1, [r11, #-8]
                cmp     r1, r0
                bne     f506
        
                add     r11, #32
                b       t507
        
        f506:
                m_exit  506
        
        t507:
                @ ARM 10: Location empty descending
                mov     r0, #32
                stmed   r11, {r0, r1}
                ldr     r1, [r11, #-4]
                cmp     r1, r0
                bne     f507
        
                add     r11, #32
                b       t508
        
        f507:
                m_exit  507
        
        t508:
                @ ARM 10: Memory alignment
                mov     r0, #32
                mov     r1, #64
                add     r2, r11, #3
                sub     r3, r11, #5
                stmfd   r2!, {r0, r1}
                ldmfd   r3, {r4, r5}
                cmp     r0, r4
                bne     f508
                cmp     r1, r5
                bne     f508
                cmp     r2, r3
                bne     f508
        
                add     r11, #32
                b       t509
        
        f508:
                m_exit  508
        
        t509:
                @ ARM 10: Load PC
                adr     r1, t510
                stmfd   r11!, {r0, r1}
                ldmfd   r11!, {r0, pc}
        
        f509:
                m_exit  509
        
        t510:
                @ ARM 10: Store PC + 4
                stmfd   r11!, {r0, pc}   // x. Store x + 8.
                mov     r0, pc           // r0 = x + 12
                ldmfd   r11!, {r1, r2}   // r2 = x + 8
                add     r2, #4
                cmp     r0, r2            
                bne     f510
        
                add     r11, #32
                b       t511
        
        f510:
                m_exit  510
        
        t511:
                @ ARM 10: Store user registers
                mov     r0, r11
                mov     r8, #32
                msr     cpsr, MODE_FIQ
                mov     r8, #64
                stmfd   r0, {r8, r9}^
                sub     r0, #8
                msr     cpsr, MODE_SYS
                ldmfd   r0, {r1, r2}
                cmp     r1, #32
                bne     f511
        
                add     r11, #32
                b       t512
        
        f511:
                m_exit  511
        
        t512:
                @ ARM 10: Load user registers
                mov     r0, r11
                mov     r1, #0xA
                stmfd   r0!, {r1, r2}
                msr     cpsr, MODE_FIQ
                mov     r8, #0xB
                ldmfd   r0, {r8, r9}^
                cmp     r8, #0xB
                bne     f512
                msr     cpsr, MODE_SYS
                cmp     r8, #0xA
                bne     f512
        
                add     r11, #32
                b       t518
        
        f512:
                m_exit  512
        
        t518:
                @ ARM 10: STMFD base first in rlist
                mov     r0, r11
                stmfd   r0!, {r0, r1}
                ldmfd   r0!, {r1, r2}
                cmp     r1, r11
                bne     f518
        
                add     r11, #32
                b       t519
        
        f518:
                m_exit  518
        
        t519:
                @ ARM 10: STMED base first in rlist
                mov     r0, r11
                stmed   r0!, {r0, r1}
                ldmed   r0!, {r1, r2}
                cmp     r1, r11
                bne     f519
        
                add     r11, #32
                b       t520
        
        f519:
                m_exit  519
        
        t520:
                @ ARM 10: STMFA base first in rlist
                mov     r0, r11
                stmfa   r0!, {r0, r1}
                ldmfa   r0!, {r1, r2}
                cmp     r1, r11
                bne     f520
        
                add     r11, #32
                b       t521
        
        f520:
                m_exit  520
        
        t521:
                @ ARM 10: STMEA base first in rlist
                mov     r0, r11
                stmea   r0!, {r0, r1}
                ldmea   r0!, {r1, r2}
                cmp     r1, r11
                bne     f521
        
                add     r11, #32
                b       block_transfer_passed
        f521:
                m_exit  521
        
        block_transfer_passed:

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

        vmult:

        f522:
                @ ARM 11: Signed multiply accumualte SMLATB
                ldr r1,=0xFFFF0000
                ldr r2,=0x0000FFFF
                ldr r3,=0xFFFF0000
                ldr r4,=0xFFFF0001

                // r1(T)*r2(B) + r3
                smlatb r5, r1, r2, r3

                cmp r4, r5
                bne f523
                b f524

        f523:
                m_exit 523

        f524:
                @ ARM 11: Don't change CPSR flags.
                mrs r4, cpsr
                smlatb r0, r1, r2, r3
                mrs r5, cpsr
                cmp r4, r5
                bne f525       
                b f526
        f525:
                m_exit 525 

        ///////////////////////////////////////////////////////////////////////

        f526:
                @ ARM 11: Signed multiply accumualte SMLABT
                ldr r1,=0x0000FFFF
                ldr r2,=0xFFFF0000
                ldr r3,=0xFFFFFFFF
                ldr r4,=0x0

                // r1(B)*r2(T) + r3
                smlabt r5, r1, r2, r3

                cmp r4, r5
                bne f527
                b f528

        f527:
                m_exit 527

        f528:
                @ ARM 11: Don't change CPSR flags.
                mrs r4, cpsr
                smlabt r0, r1, r2, r3
                mrs r5, cpsr
                cmp r4, r5
                bne f529
                b f530
        f529:
                m_exit 529

        ///////////////////////////////////////////////////////////////////////

        f530:
                @ ARM 12: Signed multiply accumualte SMLATT
                ldr r1,=0xFFFF0000
                ldr r2,=0xFFFF0000
                ldr r3,=0xFFFFFFFE
                ldr r4,=0xFFFFFFFF

                // r1(T)*r2(T) + r3
                smlatt r5, r1, r2, r3

                cmp r4, r5
                bne f531
                b f532

        f531:
                m_exit 531

        f532:
                @ ARM 11: Don't change CPSR flags.
                mrs r4, cpsr
                smlatt r0, r1, r2, r3
                mrs r5, cpsr
                cmp r4, r5
                bne f533
                b f534
        f533:
                m_exit 533

        ///////////////////////////////////////////////////////////////////////

        f534:
                @ ARM 12: Signed multiply accumualte SMLABB
                ldr r1,=0x3000FFFF
                ldr r2,=0x2000FFFF
                ldr r3,=0xFFFFFFFE
                ldr r4,=0xFFFFFFFF

                // r1(B)*r2(B) + r3
                smlabb r5, r1, r2, r3

                cmp r4, r5
                bne f535
                b f536

        f535:
                m_exit 535

        f536:
                @ ARM 11: Don't change CPSR flags.
                mrs r4, cpsr
                smlabb r0, r1, r2, r3
                mrs r5, cpsr
                cmp r4, r5
                bne f537
                b f538
        f537:
                m_exit 537

        f538:
        vmult_passed:

   here: b here

