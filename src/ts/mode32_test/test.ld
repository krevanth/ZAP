/*
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
*/

ENTRY(_Reset)                   /* _Reset is the entry point. This is the entry point in the bootstrap assembler */

/* Define how sections of the program are organized. */
SECTIONS
{
 . = 0x00000;                   /* Location Counter. */
 .text : { *(.text) }           /* Text section is expected to be starting at 0x0.*/
 .data : { *(.data) }           /* Immediately followed  by data section */
 .bss : { *(.bss) *(COMMON) }   /* Immediately followed by BSS section. Common sections are also included in BSS. */
 . = ALIGN(8);                  /* Align the location counter. */
 . = . + 0x1000;                /* 4kB of descending stack memory */
 stack_top = .;                 /* Make stack_top same as location counter. */
}
