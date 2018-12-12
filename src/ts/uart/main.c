#include "uart.h"

int main(void)
{
        // Just bringup the UART TX and RX - enable interrupts and exit.
        UARTInit();
        UARTWrite("TX testing...");
        UARTEnableRXInterrupt();
        return 0;
}


