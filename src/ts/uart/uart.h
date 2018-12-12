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
