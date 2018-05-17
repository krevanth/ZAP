char* UART_DLAB1 = 0xFFFFFFE0;
char* UART_DLAB2 = 0xFFFFFFE1;
char* UART_THR   = 0xFFFFFFE0;
char* UART_LCR   = 0xFFFFFFE3;

char* str = "I am the ZAP CPU :-). Hello World.";

int main(void)
{
        UARTInit();
        return 0;
}

void UARTInit()
{
        *UART_LCR        = (*UART_LCR) | (1 << 7);
        *UART_DLAB1      = 1;
        *UART_DLAB2      = 0;
        *UART_LCR        = (*UART_LCR) & ~(1 << 7);
        
        UARTWrite(str);

        return 0;
}

void UARTWrite(char* s)
{
        for(int i=0;i<strlen(s);i++)
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
