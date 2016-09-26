.global _Reset

// Set up an interrupt vector table.
_Reset   : b there
_Undef   : b __undef
_Swi     : b __swi
_Pabt    : b __pabt
_Dabt    : b __dabt
reserved : b _Reset
irq      : b __irq
fiq      : b __fiq

there:
mov sp, #8000
bl factorial
here: b here

