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

#define KNRM  "\x1B[0m"
#define KRED  "\x1B[31m"
#define KGRN  "\x1B[32m"

int main(int argc, char** argv, char** env) {
    if (false && argc && argv && env) {}

    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    contextp->debug(0);
    contextp->randReset(2);
    contextp->traceEverOn(true);

    contextp->commandArgs(argc, argv);
    const std::unique_ptr<Vzap_test> zap_test{new Vzap_test{contextp.get(), "ZAP_TEST"}};

    zap_test->i_reset = 0;
    zap_test->i_clk   = 0;
    zap_test->i_hold  = rand() & 0x1;

    while (!contextp->gotFinish()) 
    {
        contextp->timeInc(1);  
        zap_test->i_clk = !zap_test->i_clk;

        if (!zap_test->i_clk) 
        {
            if (contextp->time() > 1 && contextp->time() < 10) 
            {
                zap_test->i_reset = 1;  
            } 
            else 
            {
                zap_test->i_reset = 0;  
            }
        }
        else
        {
                zap_test->i_hold = rand() & 0x1;
        }

        zap_test->eval();

        if ( zap_test->o_sim_err ) 
        {
                printf("%sSimulation failed!\n%s", KRED, KNRM);
                zap_test->final();
                return 1;
        } 
        else if ( zap_test->o_sim_ok )
        {
                printf("%sSimulation passed!\n%s", KGRN, KNRM);
                zap_test->final();
                return 0;
        }
    }

    zap_test->final();
    printf("%sSimulation failed!\n%s", KRED, KNRM);
    return 2;
}
