#define N 64

#include "../debug.h"

int mult(int a, int b){
    int result = 0;
    int c=b;
    for (int i = 0; c > 0; i++,c=c>>1){
        if (c%2) result += a << i;
    }
    return result;
}

void main(void){
    for (int i = 0; i < N; i++){
        dprint_int(i);
        dprint_char('*');
        dprint_int(N-i);
        dprint_char('=');
        dprint_int(mult(i, N-i));
        dprint_char('\n');
    }
}
