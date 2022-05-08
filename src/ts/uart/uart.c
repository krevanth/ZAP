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

#include "uart.h"

/* Sets up rate as 1 baud = 16 CPU clocks. Also resets TX and RX logic */
void UARTInit()
{
        // Set up frequency of operation. 1 bit time = 16 CPU clocks.
        *UART0_LCR        = (*UART0_LCR) | (1 << 7);
        *UART0_DLAB1      = 1;
        *UART0_DLAB2      = 0;
        *UART0_LCR        = (*UART0_LCR) & ~(1 << 7);

        // Enable TX and RX.
        UARTEnableTX();
        UARTEnableRX();
}

/* Write a string to the UART device. This is an open loop function. */
void UARTWrite(char* s)
{
        int len;
        int i;

        len = strlen(s);

        for(i=0;i<len;i++)        {
                UARTWriteByte(s[i]);
        }       
}

/* Write a byte to the UART. This is an open loop function. */
void UARTWriteByte(char c)
{
        *UART0_THR = c;
}

/* Length of a string */
int strlen(char* s)
{
        int i;
        i = 0;

        while(s[i] != '\0')        
                i++;

        return i;
}

/* UART Enable RX interrupt */
void UARTEnableRXInterrupt (void) {
        *UART0_IER = *UART0_IER | 1;
}

/* Enable TX */
void UARTEnableTX (void) {
        *UART0_FCR = *UART0_FCR | 4;
}

/* Enablt RX */
void UARTEnableRX (void) {
        *UART0_FCR = *UART0_FCR | 1;
}

/* Check if transmit is empty */
int UARTTransmitEmpty (void) {
        char x = *UART0_LSR;
        
        if ( x & (1 << 6) ) 
                return 1;
        else
                return 0;
}

/* Get a character from uart */
char UARTGetChar (void) {
        return *UART0_RBR;
}
