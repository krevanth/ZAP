// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C)2016-2024 Revanth Kamaraj (krevanth)              --
// --                                                                         --
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 3          --
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

#ifndef UART_H
#define UART_H

        // Non virtualized addresses for UART0
        #define UART0_DLAB1   ((char*)0xFFFFFFE0)
        #define UART0_DLAB2   ((char*)0xFFFFFFE1)
        #define UART0_THR     ((char*)0xFFFFFFE0)
        #define UART0_RBR     ((char*)0xFFFFFFE0)
        #define UART0_IER     ((char*)0xFFFFFFE1)
        #define UART0_FCR     ((char*)0xFFFFFFE2)
        #define UART0_LCR     ((char*)0xFFFFFFE3)
        #define UART0_LSR     ((char*)0xFFFFFFE5)
        #define VIC_INT_CLEAR ( (int*)0xFFFFFFA8)

        // Initialization functions.
        void UARTInit(void);
        void UARTEnableTX(void);
        void UARTEnableRX(void);

        // Open loop functions.
        void UARTWrite(char*);
        void UARTWriteByte(char x);

        // UART interrupt related functions.
        void UARTEnableTXInterrupt(void);
        void UARTEnableRXInterrupt(void);

        // Check THRE
        int UARTTransmitEmpty(void);

        // Get a character from the UART.
        char UARTGetChar (void );

        // String processing functions.
        int strlen(char*);

#endif
