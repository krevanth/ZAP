#ifndef UART_H

#define UART_H
#define UART_DLAB1 ((char*)0xFFFFFFE0)
#define UART_DLAB2 ((char*)0xFFFFFFE1)
#define UART_THR   ((char*)0xFFFFFFE0)
#define UART_LCR   ((char*)0xFFFFFFE3)

void UARTInit(void);
void UARTWrite(char*);
void UARTWriteByte(char c);
int strlen(char*);

#endif
