// ===============================
// Instruction Patterns.
// ===============================

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

