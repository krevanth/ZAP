// Shift type.
parameter [1:0] LSL  = 0;
parameter [1:0] LSR  = 1;
parameter [1:0] ASR  = 2;
parameter [1:0] ROR  = 3;
parameter [2:0] RRC  = 4; // Encoded as ROR #0.

// Instruction specified shifts (Except ROTI).
parameter [2:0] RORI = 5;
parameter [2:0] LSRI = 6;
parameter [2:0] ASRI = 7;
parameter [3:0] LSLI = 8;

// Immediate.
parameter [3:0] ROTI = 9;
