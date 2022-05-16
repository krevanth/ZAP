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

# Initialize registers.
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

# r6 = 20
# r5 = 30
# r4 = 40
add r6, r7
add r5, r6
add r4, r5

# Return back.
bx lr

