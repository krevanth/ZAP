.text
.global _Reset

_Reset:

ldr sp, =#3500
bl main
here: b here

