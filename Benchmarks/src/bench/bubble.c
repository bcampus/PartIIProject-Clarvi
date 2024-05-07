#define SORT_SIZE 100
#define DTYPE long

#include "../debug.h"

DTYPE arr[SORT_SIZE];

void initArray(){
    for (char i = 0; i < SORT_SIZE; i++){
        arr[i] = (DTYPE) SORT_SIZE - i;
    }
}

void bubbleSort(){
    char sorted = 0;
    char count = 0;
    while (!sorted) {
        sorted = 1;
        for (char i = 1; i < SORT_SIZE - count; i++){
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

void main(void){
    dprint_str("BSort\n");
    initArray();
    dprint_str("Arr Init\n");
    bubbleSort();
    dprint_str("Arr Sorted\n");
}
