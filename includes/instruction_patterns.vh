// ===============================
// Instruction Patterns.
// ===============================

/* ARM */

localparam      [31:0]  DATA_PROCESSING_IMMEDIATE                       =                                       32'bzzzz_00_1_zzzz_z_zzzz_zzzz_zzzzzzzzzzzz;
localparam      [31:0]  DATA_PROCESSING_REGISTER_SPECIFIED_SHIFT        =                                       32'bzzzz_00_0_zzzz_z_zzzz_zzzz_zzzz0zz1zzzz;
localparam      [31:0]  DATA_PROCESSING_INSTRUCTION_SPECIFIED_SHIFT     =                                       32'bzzzz_00_0_zzzz_z_zzzz_zzzz_zzzzzzz0zzzz;       

// BL never reaches the unit.
localparam      [31:0]  BRANCH_INSTRUCTION                              =                                       32'bzzzz_101z_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

localparam      [31:0]  MRS                                             =                                       32'bzzzz_00010_z_001111_zzzz_zzzz_zzzz_zzzz;
localparam      [31:0]  MSR_IMMEDIATE                                   =                                       32'bzzzz_00_1_10z10_zzzz_1111_zzzz_zzzz_zzzz;

localparam      [31:0]  MSR                                             =                                       32'bzzzz_00_0_10z10_zzzz_1111_zzzz_zzzz_zzzz;

localparam      [31:0]  LS_INSTRUCTION_SPECIFIED_SHIFT                  =                                       32'bzzzz_01_1_zzzzz_zzzz_zzzz_zzzz_zzzz_zzzz; 
localparam      [31:0]  LS_IMMEDIATE                                    =                                       32'bzzzz_01_0_zzzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

localparam      [31:0]  CLZ_INST                                        =                                       32'bzzzz_00010110000_zzzz_00000001_zzzz;

localparam      [31:0]  BX_INST                                         =                                       32'bzzzz_0001_0010_1111_1111_1111_0001_zzzz;
// Includes MLA too. No xMULLx support (M not implemented)
localparam      [31:0]  MULT_INST                                       =                                       32'bzzzz_0000_00z_z_zzzz_zzzz_zzzz_1001_zzzz;

// Halfword memory.
localparam      [31:0]  HALFWORD_LS                                     =                                       32'bzzzz_000_zzzzz_zzzz_zzzz_zzzz_1zz1_zzzz;

// Software interrupt.
localparam      [31:0]  SOFTWARE_INTERRUPT                              =                                       32'bzzzz_1111_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz;

/* THUMB */

//B
localparam      [15:0]  T_BRANCH_COND                                   =                                       16'b1101_zzzz_zzzzzzzz;
localparam      [15:0]  T_BRANCH_NOCOND                                 =                                       16'b11100_zzzzzzzzzzz;
localparam      [15:0]  T_BL                                            =                                       16'b1111_z_zzzzzzzzzzz;
localparam      [15:0]  T_BX                                            =                                       16'b01000111_0_z_zzz_000;

// SWI
localparam      [15:0]  T_SWI                                           =                                       16'b11011111_zzzzzzzz;

// Shifts.
localparam      [15:0]  T_SHIFT                                         =                                       16'b000_zz_zzzzz_zzz_zzz;

// Add sub LO.
localparam      [15:0]  T_ADD_SUB_LO                                    =                                       16'b00011_z_z_zzz_zzz_zzz;

// MCAS Imm.
localparam      [15:0]  T_MCAS_IMM                                      =                                       16'b001_zz_zzz_zzzzzzzz;

// ALU Lo.
localparam      [15:0]  T_ALU_LO                                        =                                       16'b010000_zzzz_zzz_zzz;

// ALU hi.
localparam      [15:0]  T_ALU_HI                                        =                                       16'b010001_zz_z_z_zzz_zzz;

// PC relative load.
localparam      [15:0]  T_PC_REL_LOAD                                   =                                       16'b01001_zzz_zzzzzzzz;

// LDR_STR_5BIT_OFF
localparam      [15:0] T_LDR_STR_5BIT_OFF                               =                                       16'b011_z_z_zzzzz_zzz_zzz;

// LDRH_STRH_5BIT_OFF
localparam      [15:0] T_LDRH_STRH_5BIT_OFF                             =                                       16'b1000_z_zzzzz_zzz_zzz;

// Signed LDR/STR
localparam      [15:0]  T_LDRH_STRH_REG                                 =                                       16'b0101_zzz_zzz_zzz_zzz;

// SP relative LDR/STR
localparam      [15:0]  T_SP_REL_LDR_STR                                =                                       16'b1001_z_zzz_zzzzzzzz;

// LDMIA/STMIA
localparam      [15:0]  T_LDMIA_STMIA                                   =                                       16'b1100_z_zzz_zzzzzzzz;

// PUSH POP
localparam      [15:0]  T_POP_PUSH                                      =                                       16'b1011_z_10_z_zzzzzzzz;
