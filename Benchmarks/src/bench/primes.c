#define N 30 
#define DTYPE unsigned long long

#include "../debug.h"

DTYPE arr[N];

void initArray(){
    for (char i = 0; i < N; i++){
        arr[i] = (DTYPE) N - i;
    }
}

void bubbleSort(){
    char sorted = 0;
    char count = 0;
    while (!sorted) {
        sorted = 1;
        for (char i = 1; i < N - count; i++){
            if (arr[i-1] <= arr[i]) continue;
            sorted = 0;
            DTYPE tmp = arr[i-1];
            arr[i-1]=arr[i];
            arr[i] = tmp;
        }
        count++;
        dprint_intvar("count: ", count);
    }
}

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
