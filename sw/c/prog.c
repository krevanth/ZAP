void prog(void)
{
        int i = 0;
        int j = 23;

        int *x = (int *)300;

        for(i=0;i<10;i++)
                x[i] = j++;
        
        while(1);
}

void undef(void) {
        return;
} 

void swi (void) {
        return;
}

void pabt (void) {
        return;
}

void dabt (void) {
        return;
}

void irq (void) {
        return;
}

void fiq (void) {
        return;
}

