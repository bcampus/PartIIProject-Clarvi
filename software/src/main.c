#include "bubbleSort.h"

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
    x = mult(x, x);
    bubbleSortBenchMark();
}
