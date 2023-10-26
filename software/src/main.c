#include "test_helpers.h"
#include "types.h"
#include "bubbleSort.h"
#include "debug.h"

int x=20;
int y1=0xaaaaaaaa;
int y2=0x7aaaaaaa;
unsigned int y3=0xaaaaaaaa;
unsigned WORD y4 = -1;

int mult(int a, int b){
    int result = 0;
    int c=b;
    for (int i = 0; c > 0; i++,c=c>>1){
        if (c%2) result += a << i;
    }
    return result;
}

int test_shifts(){
    dprint_str("Shift tst:\n");
    dprint_hexvar("y1", y1);
    dprint_str("SLL\n");
    for (int i = 1; i < 4; i++){
        y1 = y1 << i;
        dprint_hexvar("y1", (long long) y1);
    }
    if (y1!=0xaaaaaa80) return 1;
    dprint_str("SRA\n");
    dprint_hexvar("y1", y1);
    y1 = y1>>1;
    dprint_hexvar("y1>>1", (long long) y1);
    if (y1!=0xd5555540) return 2;
    dprint_hexvar("y2", y2);
    y2 = y2>>1;
    dprint_hexvar("y2>>1", (long long) y2);
    if (y2!=0x3d555555) return 3;
    dprint_str("SRL\n");
    dprint_hexvar("y3", y3);
    y3 = y3>>1;
    dprint_hexvar("y3>>1", (long long) y3);
    if (y3!=0x55555555) return 4;
    dprint_hexvar("y4", y4);
    y4 = ((unsigned int) y4)>>1;
    dprint_hexvar("y4>>1", (long long) y4);
    if (y4!=0x7fffffff) return 5;
    return 0;
}

int test_load(){
    
    long x1 = 0x0; 
    long x2 = 0x0; 
    long *x1_ptr = &x1;
    long *x2_ptr = &x2;

    //MSB of D,W,H,B = 0
    *x1_ptr = 0x08192a4b4c5d6e7f;
    *x2_ptr = 0x8091a2b3c4d5e6f7; //Should force SD

    return helper_loadTest(x1_ptr, x2_ptr, x1, x2);
    
}

int test_store(){
    
    long x = 0x0; 
    long *x_ptr = &x;

    *x_ptr = 0x08192a4b4c5d6e7f;

    return helper_storeTest(x_ptr, x);
    
}

void test(char *name, int test(void)){
    dprint_str(name);
    int result = test();
    if (result == 0){
        dprint_str("PASS\n");
    }else{
        dprint_str("FAIL: ret = ");
        dprint_int(result);
        dprint_char('\n');
    }
}

int main(void) {
    //test(test_shifts);
    test("lui tests:\n", test_lui);
    test("auipc tests:\n", test_auipc);
    test("load tests:\n", test_load);
    test("store tests:\n", test_store);
    //dprint_str("Mult tst:\n");
    //dprint_intvar("x", x);
    //x = mult(x, x);
    //dprint_intvar("x^2", x);
    //bubbleSortBenchMark();
}
