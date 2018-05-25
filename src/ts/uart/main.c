#include "uart.h"

char* str = "Hello World";

int main(void)
{
        UARTInit();
        UARTWrite(str);
        return 0;
}


