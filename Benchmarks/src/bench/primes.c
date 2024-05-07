#define N 30 
#define DTYPE unsigned long long

#include "../debug.h"

DTYPE arr[N];

DTYPE mod(DTYPE a, DTYPE b){
    while (a >= b) a -= b;
    return a;
}

void n_primes(){
    arr[0] = 2;
    char found = 1;
    for (DTYPE candidate = 3; found < N; candidate++){
        char valid = 1;
        for (char i = 0; i < found; i++){
            if (mod(candidate, arr[i]) == 0){
                valid = 0;
                break;
            }
        }
        if (!valid) continue;
        arr[found++] = candidate;
        dprint_intvar("i", found);
        dprint_intvar("p(i)", candidate);
    }
}

void main(void){
    n_primes();
}
