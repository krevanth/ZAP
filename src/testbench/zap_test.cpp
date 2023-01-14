//
// (C) 2016-2022 Revanth Kamaraj (krevanth)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//

#include <memory>
#include <verilated.h>
#include "Vzap_test.h"
#include <stdio.h>
#include <string.h>

#define KNRM            "\x1B[0m"
#define KRED            "\x1B[31m"
#define KGRN            "\x1B[32m"
#define RESET_CYCLES    10


char mem [0x03FFFFFF]; // 64MB buffer.
FILE *ptr;

unsigned int seq;
unsigned int saved_we;
unsigned int saved_adr;
unsigned int end_nxt;

// Data to be expected on UART if the TC is named "uart"
char word0[] = "HELLO WORLD";
char word1[] = "";

int uart0_ctr = 0;
int uart1_ctr = 0;

unsigned int seed;
int delay = -1;

int main(int argc, char** argv, char** env) {

    if ( argc == 4 )
    {
        seed = atoi(argv[3]);
    }
    else
    {
        seed = (unsigned int)time(0);
    }

    printf("\n############# Simulator seed is 'd%d ###############\n", seed);

    srand(seed);

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
                        printf("%s\nError: Ending simulation due to error. Waves are here : obj/ts/%s/zap.vcd\n%s", KRED, argv[2], KNRM);
                        zap_test->final();
                        return end_nxt;
                }
        }
        else if (zap_test->i_clk)
        {
            // Operate everything on rising edge of clock.

            if ( contextp->time() < RESET_CYCLES )
            {
                zap_test->i_reset = 1;
                zap_test->i_int_sel = (rand() & 0x1); // Select IRQ or FIQ port.
            }
            else
            {
                zap_test->i_reset = 0;
            }

            if ( seq && (!zap_test->o_wb_cyc || !zap_test->o_wb_stb) )
            {
                printf("Error: WB_CYC/STB going low in the middle of a burst.\n");
                end_nxt = 3;
            }

            // Simulate a Wishbone RAM.
            if ( zap_test->o_wb_cyc && zap_test->o_wb_stb && !zap_test -> i_reset )
            {
                    // Randomly give delay between 0 and 50 cycles per
                    // transfer, when seed is even. When seed is odd,
                    // give response immediately.

                    if ( (seed % 2 == 0) && delay == -1 && (rand() % 2) )
                    {
                        delay = (rand() % 50) + 1;
                        zap_test->i_wb_ack = 0;
                        zap_test->i_wb_dat = rand();
                    }
                    else if ( delay > 0 )
                    {
                        // Keep holding the bus.
                        delay--;
                        zap_test->i_wb_ack = 0;
                        zap_test->i_wb_dat = rand();
                    }
                    else if (delay <= 0)
                    {
                            delay = -1;

                            // Give bus response.
                            if( !zap_test->o_wb_we )
                            {
                                    zap_test->i_wb_ack = 1;
                                    zap_test->i_wb_dat = 0;

                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 0) & 0x3FFFFFF]) & 0xFF) << (8 * 0);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 1) & 0x3FFFFFF]) & 0xFF) << (8 * 1);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 2) & 0x3FFFFFF]) & 0xFF) << (8 * 2);
                                    zap_test->i_wb_dat |= ((mem[((zap_test->o_wb_adr >> 2)*4 + 3) & 0x3FFFFFF]) & 0xFF) << (8 * 3);
                            }
                            else
                            {
                                    zap_test->i_wb_ack   = 1;
                                    zap_test->i_wb_dat   = rand();

                                    if ( zap_test->o_wb_sel & 1 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 0) & 0x3FFFFFF ] = (zap_test->o_wb_dat >> (8 * 0)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 2 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 1) & 0x3FFFFFF ] = (zap_test->o_wb_dat >> (8 * 1)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 4 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 2) & 0x3FFFFFF ] = (zap_test->o_wb_dat >> (8 * 2)) & 0xFF;
                                    if ( zap_test->o_wb_sel & 8 ) mem [ ((zap_test->o_wb_adr >> 2)*4 + 3) & 0x3FFFFFF ] = (zap_test->o_wb_dat >> (8 * 3)) & 0xFF;
                            }

                            if ( seq && zap_test->i_wb_ack )
                            {
                                if ( zap_test->o_wb_adr != saved_adr + 4 )
                                {
                                        printf("Error: Burst addresses not sequential. Rec=%x Exp=%x\n", zap_test->o_wb_adr, saved_adr + 4);
                                        end_nxt = 4;
                                }

                                if ( zap_test->o_wb_we != saved_we )
                                {
                                        printf("Error: Burst does not hold sense constant. Exp=%x Rec=%x\n", saved_we, zap_test->o_wb_we);
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

            // Print UART output on line 0 and line 1.

            if ( zap_test->UART_SR_DAV_0 )
            {
                printf("%c", zap_test->UART_SR_0);

                if ( (zap_test->UART_SR_0 != word0[uart0_ctr]) || (uart0_ctr >= strlen(word0)) )
                {
                        printf("Error : UART character mismatch or Overflow. Rcvd=%c Exp=%c\n", zap_test->UART_SR_0, word0[uart0_ctr]);
                        end_nxt = 7;
                }

                uart0_ctr++;
            }

           if ( zap_test->UART_SR_DAV_1 )
           {
                printf("%c", zap_test->UART_SR_1);

                if ( (zap_test->UART_SR_1 != word1[uart1_ctr]) || (uart1_ctr >= strlen(word1)) )
                {
                        printf("Error: UART 1 character mismatch or Overflow. Rcvd=%c Exp=%c\n", zap_test->UART_SR_1, word1[uart0_ctr]);
                        end_nxt = 8;
                }

                uart1_ctr++;
           }

            // Run memory checks and register checks.

            for(int j=0;j<65536;j++)
            {
                    zap_test->i_mem[j] = mem[j];
            }

            if ( zap_test->o_sim_err && !zap_test->i_reset )
            {
                    printf("Error : Register/memory mismatch.\n");
                    end_nxt = 6;
            }
            else if ( zap_test->o_sim_ok && !zap_test->i_reset )
            {
                        if ( strcmp(argv[2], "uart") != 0 )
                        {
                                printf("%sOK : Simulation passed!\n%s", KGRN, KNRM);
                                zap_test->final();
                                return 0;
                        }
                        else
                        {
                                if ( uart0_ctr == strlen(word0) && uart1_ctr == strlen(word1))
                                {
                                        printf("%sOK : Simulation passed!\n%s", KGRN, KNRM);
                                        zap_test->final();
                                        return 0;
                                }
                                else
                                {
                                        printf("Error : word[x] not printed correctly on UARTx.");
                                        end_nxt = 9;
                                }
                        }
            }
        } // rising edge of clock
    } // while

    zap_test->final();
    printf("%sError: Simulation failed!\n%s", KRED, KNRM);
    return 7;
}
