.global _Reset

// Set up an interrupt vector table.
_Reset   : b there
_Undef   : b undef
_Swi     : b swi
_Pabt    : b pabt
_Dabt    : b dabt
reserved : b _Reset
irq      : b irq
fiq      : b fiq

there:
mov sp, #1000
b prog

here: b here

