#include "uart.h"

char* str  = "Hello\n";

int main(void)
{
        int i;

        UARTInit();
        UARTWrite(str);
        UARTWrite("World");
        return 0;
}


