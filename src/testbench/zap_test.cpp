// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2022 Revanth Kamaraj (krevanth)              --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 2          --
// -- of the License, or (at your option) any later version.                  --
// --                                                                         --
// -- This program is distributed in the hope that it will be useful,         --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
// -- GNU General Public License for more details.                            --
// --                                                                         --
// -- You should have received a copy of the GNU General Public License       --
// -- along with this program; if not, write to the Free Software             --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
// -- 02110-1301, USA.                                                        --
// --                                                                         --
// -----------------------------------------------------------------------------

#include <memory>
#include <verilated.h>
#include "Vzap_test.h"
#include <stdio.h>

#define KNRM            "\x1B[0m"
#define KRED            "\x1B[31m"
#define KGRN            "\x1B[32m"
#define RESET_CYCLES    10

char mem [65536]; // 64KB buffer.
FILE *ptr;

unsigned int seq;
unsigned int saved_we;
unsigned int saved_adr;
unsigned int end_nxt;

int main(int argc, char** argv, char** env) {
    srand((unsigned int)time(0));

    seq      = 0;
    end_nxt  = 0; 

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    contextp->debug(0);
    contextp->randReset(2);
    contextp->traceEverOn(true);

    const std::unique_ptr<Vzap_test> zap_test{new Vzap_test{contextp.get(), "ZAP_TEST"}};

    if ( argc > 1 ) 
    {
        ptr=fopen(argv[1], "rb");
    }
    else
    {
        printf("Failed to get binary file.");
        return 1;
    }

    if ( ptr == NULL ) 
    {
        printf("Failed to open file %s", argv[0]);
        return 2;
    }

    fread(mem, 1, sizeof(mem), ptr);    

    zap_test->i_reset  = 1;
    zap_test->i_clk    = 0;
    zap_test->i_wb_dat = rand();
    zap_test->i_wb_ack = rand() & 0x1;

    while (!contextp->gotFinish()) 
    {
        contextp->timeInc(1);  
        zap_test->i_clk = !zap_test->i_clk;

        zap_test->eval();

        if(!zap_test->i_clk)
        {
                // End simulation on falling edge of clock.                

                if ( end_nxt ) 
                {
                        printf("%sError: Ending simulation.%s", KRED, KNRM);
                        return end_nxt;
                }
        }
        else if (zap_test->i_clk) 
        {
            // Operate everything on rising edge of clock.

            if ( contextp->time() < RESET_CYCLES ) 
            {
                zap_test->i_reset = 1;  
            } 
            else 
            {
                zap_test->i_reset = 0;  
            }

            if ( seq && (!zap_test->o_wb_cyc || !zap_test->o_wb_stb) ) 
            {
                printf("Error: WB_CYC/STB going low in the middle of a burst.");
                end_nxt = 3;
            }

            // Simulate a Wishbone RAM.
            if ( zap_test->o_wb_cyc && zap_test->o_wb_stb && !zap_test -> i_reset ) 
            {
                    if ( rand() & 0x1 )
                    {
                            zap_test->i_wb_ack = 0;
                            zap_test->i_wb_dat = rand();
                    }
                    else
                    {
                            if( !zap_test->o_wb_we )
                            {
                                    zap_test->i_wb_ack = 1;      
                                    zap_test->i_wb_dat = 0;

                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 0) & 0xFFFF]) & 0xFF) << (8 * 0);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 1) & 0xFFFF]) & 0xFF) << (8 * 1);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 2) & 0xFFFF]) & 0xFF) << (8 * 2);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 3) & 0xFFFF]) & 0xFF) << (8 * 3);
                            }
                            else
                            {
                                    zap_test->i_wb_ack   = 1;
                                    zap_test->i_wb_dat   = rand();

                                    if ( zap_test->o_wb_sel & 1 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 0) & 0xFFFF ] = (zap_test->o_wb_dat >> (8 * 0)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 2 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 1) & 0xFFFF ] = (zap_test->o_wb_dat >> (8 * 1)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 4 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 2) & 0xFFFF ] = (zap_test->o_wb_dat >> (8 * 2)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 8 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 3) & 0xFFFF ] = (zap_test->o_wb_dat >> (8 * 3)) & 0xFF;
                            }

                            if ( seq && zap_test->i_wb_ack ) 
                            {
                                if ( zap_test->o_wb_adr != saved_adr + 4 ) 
                                {
                                        printf("Error: Burst addresses not sequential. Rec=%x Exp=%x", zap_test->o_wb_adr, saved_adr + 4);
                                        end_nxt = 4;
                                }

                                if ( zap_test->o_wb_we != saved_we )
                                {
                                        printf("Error: Burst does not hold sense constant. Exp=%x Rec=%x", saved_we, zap_test->o_wb_we);
                                        end_nxt = 5;
                                }
                            }
                    }

                    if ( zap_test->o_wb_cti == 2 && zap_test->i_wb_ack ) 
                    {
                        seq       = 1;
                        saved_adr = zap_test->o_wb_adr;
                        saved_we  = zap_test->o_wb_we;
                    }
                    else
                    {
                        seq      = 0;
                    }
            }
            else
            {
                    zap_test->i_wb_ack = 0;
                    zap_test->i_wb_dat = rand();
            }
        }

        for(int j=0;j<65536;j++)
        {
                zap_test->i_mem[j] = mem[j];
        }

        if ( zap_test->o_sim_err && !zap_test->i_reset ) 
        {
                printf("%sError: Simulation failed!\n%s", KRED, KNRM);
                zap_test->final();
                return 6;
        } 
        else if ( zap_test->o_sim_ok && !zap_test->i_reset )
        {
                printf("%sOK: Simulation passed!\n%s", KGRN, KNRM);
                zap_test->final();
                return 0;
        }
    }

    zap_test->final();
    printf("%sError: Simulation failed!\n%s", KRED, KNRM);
    return 7;
}
