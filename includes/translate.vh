// ===========================
// Translate FUNCTION.
// ===========================
function [$clog2(PHY_REGS)-1:0] translate ( input [$clog2(ARCH_REGS)-1:0] index, input [4:0] cpu_mode );
begin
        case ( index )
                      0:      translate = PHY_USR_R0; 
                      1:      translate = PHY_USR_R1;                            
                      2:      translate = PHY_USR_R2; 
                      3:      translate = PHY_USR_R3;
                      4:      translate = PHY_USR_R4;
                      5:      translate = PHY_USR_R5;
                      6:      translate = PHY_USR_R6;
                      7:      translate = PHY_USR_R7;
                      8:      translate = PHY_USR_R8;
                      9:      translate = PHY_USR_R9;
                      10:     translate = PHY_USR_R10;
                      11:     translate = PHY_USR_R11;
                      12:     translate = PHY_USR_R12;
                      13:     translate = PHY_USR_R13;
                      14:     translate = PHY_USR_R14;
                      15:     translate = PHY_PC;
                RAZ_REGISTER: translate = PHY_RAZ_REGISTER;
               ARCH_CPSR:     translate = PHY_CPSR;
          ARCH_CURR_SPSR:     translate = PHY_CPSR;
              ARCH_USR2_R8:   translate = PHY_USR_R8;
              ARCH_USR2_R9:   translate = PHY_USR_R9;
              ARCH_USR2_R10:  translate = PHY_USR_R10;
              ARCH_USR2_R11:  translate = PHY_USR_R11;
              ARCH_USR2_R12:  translate = PHY_USR_R12;
              ARCH_USR2_R13:  translate = PHY_USR_R13;
              ARCH_USR2_R14:  translate = PHY_USR_R14;
              ARCH_DUMMY_REG0:translate = PHY_DUMMY_REG0;
              ARCH_DUMMY_REG1:translate = PHY_DUMMY_REG1;
        endcase

        case ( cpu_mode )
                FIQ:
                begin
                        case ( index )
                                8:      translate = PHY_FIQ_R8;
                                9:      translate = PHY_FIQ_R9;
                                10:     translate = PHY_FIQ_R10;
                                11:     translate = PHY_FIQ_R11;
                                12:     translate = PHY_FIQ_R12;
                                13:     translate = PHY_FIQ_R13;
                                14:     translate = PHY_FIQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_FIQ_SPSR;
                        endcase
                end

                IRQ:
                begin
                        case ( index )
                                13:     translate = PHY_IRQ_R13;
                                14:     translate = PHY_IRQ_R14;
                    ARCH_CURR_SPSR:     translate = PHY_IRQ_SPSR;
                        endcase
                end

                ABT:
                begin
                        case ( index )
                                13:     translate = PHY_ABT_R13;
                                14:     translate = PHY_ABT_R14;
                    ARCH_CURR_SPSR:     translate = PHY_ABT_SPSR;
                        endcase
                end

                UND:
                begin
                        case ( index )
                                13:     translate = PHY_UND_R13;
                                14:     translate = PHY_UND_R14;
                    ARCH_CURR_SPSR:     translate = PHY_UND_SPSR;
                        endcase
                end

                SVC:
                begin
                        case ( index )
                                13:     translate = PHY_SVC_R13;
                                14:     translate = PHY_SVC_R14;
                    ARCH_CURR_SPSR:     translate = PHY_SVC_SPSR;
                        endcase
                end
        endcase
end
endfunction

