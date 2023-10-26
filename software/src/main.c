#include "tests.h"
#include "types.h"
#include "bubbleSort.h"
#include "debug.h"

int x=20;

int mult(int a, int b){
    int result = 0;
    int c=b;
    for (int i = 0; c > 0; i++,c=c>>1){
        if (c%2) result += a << i;
    }
    return result;
}

int main(void) {
    //test(test_shifts);
    test_all();
    //dprint_str("Mult tst:\n");
    //dprint_intvar("x", x);
    //x = mult(x, x);
    //dprint_intvar("x^2", x);
    //bubbleSortBenchMark();
}
