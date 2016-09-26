void factorial (void)
{
        int *x = (int *)500;
        x[0] = 5;
        x[1] = fact(x[0]);               
        while(1);
}

int fact (int x)
{
        if ( x == 0 )
                return 1;
        else
                return x * fact(x-1);
}

void __undef(void) {
        return;
} 

void __swi (void) {
        return;
}

void __pabt (void) {
        return;
}

void __dabt (void) {
        return;
}

void __irq (void) {
        return;
}

void __fiq (void) {
        return;
}

