// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2022 Revanth Kamaraj (krevanth)              --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 2          --
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

.text

_Reset:
    b enable_cache        

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

   mov sp, #4000

   ldr r0, =myThumbFunction+1
   mov lr, pc
   bx r0 // Jump to Thumb code

   mvn r0, #0
  
   ldr r0,= myThumbFunction+1
   blx r0

   mvn r0, #0
   
   here: b here
   
   .thumb_func
   myThumbFunction:
   
   # Test MOV
   
   mov r0, #10
   mov r1, #10
   mov r2, #10
   mov r3, #10
   mov r4, #10
   mov r5, #10
   mov r6, #10
   mov r7, #10
   
   # Test addition.
   
   # r0 = 20
   # r1 = 20
   # r2 = 20
   
   add r0, r1
   add r1, r2
   add r2, r3
   
   # r4 = 40
   # r5 = 30
   
   add r6, r7
   add r5, r6
   add r4, r5
   
   # Test shift
   
   # r6 = 40
   # r7 = 1
   
   mov r7, #1
   lsl r6, r7
   
   # Return back.
   bx lr

