// Shift type.
parameter [1:0] LSL  = 0;
parameter [1:0] LSR  = 1;
parameter [1:0] ASR  = 2;
parameter [1:0] ROR  = 3;
parameter [2:0] RRC  = 4; // Encoded as ROR #0.
parameter [2:0] RORI = 5;
parameter [2:0] ROR_1= 6; // ROR with instruction specified shift.
