#include "uart.h"

void irq_handler () 
{
       // Wait for space to be available.
       while ( !UARTTransmitEmpty() );

       // Write character
       UARTWriteByte ( UARTGetChar() );
                 
       // Clear interrupt pending register in VIC.
       *VIC_INT_CLEAR = 0xffffffff;
}

