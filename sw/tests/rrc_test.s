// Simple assembly program to check RRC.

.global _Reset

_Reset:

// Set carry bit in CPSR.
mrs r0, cpsr
mov r1, #1
orr r0, r0, r1, lsl #29
msr cpsr, r0

// Move it through r0 via carry.
bic r0, r0, #1    // Clear LSB.
movs r0, r0, rrx  // Will clear carry.

// Switch to user mode.
mrs r0, cpsr
bic r0, r0, #31
orr r0, r0, #16
msr cpsr, r0

// Set carry bit in CPSR.
mrs r0, cpsr
mov r1, #1
orr r0, r0, r1, lsl #29
msr cpsr, r0

// Move it through r0 via carry.
movs r0, r0, rrx

// Loop
here: b here
