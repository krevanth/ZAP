// ALU opcodes.
parameter [3:0] AND   = 0;
parameter [3:0] EOR   = 1;
parameter [3:0] SUB   = 2;
parameter [3:0] RSB   = 3;
parameter [3:0] ADD   = 4;
parameter [3:0] ADC   = 5;
parameter [3:0] SBC   = 6;
parameter [3:0] RSC   = 7;
parameter [3:0] TST   = 8;
parameter [3:0] TEQ   = 9;
parameter [3:0] CMP   = 10;
parameter [3:0] CMN   = 11;
parameter [3:0] ORR   = 12;
parameter [3:0] MOV   = 13;
parameter [3:0] BIC   = 14;
parameter [3:0] MVN   = 15;
parameter [4:0] MUL   = 16; // Multiply ( 32 x 32 = 32 ).
parameter [4:0] MLA   = 17; // Multiply-Accumulate ( 32 x 32 + 32 = 32 ). 
parameter [4:0] FMOV  = 18; // Flag MOV. Will write upper 4-bits to flags if mask bit [3] is set to 1. Also writes to target register similarly. Mask bit comes from non-shift operand.
parameter [4:0] MMOV  = 19; // Same as FMOV but does not touch the flags in the ALU. This is MASK MOV. Set to 1 will update, 0 will not (0000 -> No updates, 0001 -> [7:0] update).
parameter [4:0] UMULL = 20; // Unsigned multiply long.
parameter [4:0] UMLAL = 21; // Unsigned multiply accumulate.
parameter [4:0] SMULL = 22; // Signed multiply long.
parameter [4:0] SMLAL = 23; // Signed multiply accumulate.
parameter [4:0] CLZ   = 24; // Count Leading zeros.
