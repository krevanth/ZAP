#include "uart.h"

void UARTInit()
{
        *UART_LCR        = (*UART_LCR) | (1 << 7);
        *UART_DLAB1      = 1;
        *UART_DLAB2      = 0;
        *UART_LCR        = (*UART_LCR) & ~(1 << 7);
        return 0;
}

void UARTWrite(char* s)
{
        int len;

        len = strlen(s);

        for(int i=0;i<len;i++)
        {
                UARTWriteByte(s[i]);
        }       
}

void UARTWriteByte(char c)
{
        *UART_THR = c;
}

int strlen(char* s)
{
        int i;
        i = 0;

        while(s[i] != '\0')        
                i++;

        return i;
}
