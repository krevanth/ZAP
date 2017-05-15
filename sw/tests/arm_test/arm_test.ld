/* Linker Script */

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
