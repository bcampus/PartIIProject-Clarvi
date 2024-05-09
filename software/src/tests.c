#include "test_helpers.h"
#include "debug.h"

int y1=0xaaaaaaaa;
int y2=0x7aaaaaaa;
unsigned int y3=0xaaaaaaaa;
unsigned WORD y4 = -1;


int test_shifts(int id){
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

int test_load(int id){
    
    long x1 = 0x0; 
    long x2 = 0x0; 
    long *x1_ptr = &x1;
    long *x2_ptr = &x2;

    //MSB of D,W,H,B = 0
    *x1_ptr = 0x08192a3b4c5d6e7f;
    *x2_ptr = 0x8091a2b3c4d5e6f7; //Should force SD

    return helper_loadTest(id, x1_ptr, x2_ptr, x1, x2);
}

int test_store(int id){
    
    long x = 0x0; 
    long *x_ptr = &x;

    *x_ptr = 0x08192a4b4c5d6e7f;

    return helper_storeTest(id, x_ptr, x);
}

int test_addSub(int id){
    return helper_addSubTest(id);
}

void test(int id, char *name, int test(int)){
    dprint_str(name);
    int result = test(id << 16);
    if (result == 0){
        dprint_str("PASS\n");
    }else{
        dprint_str("FAIL: ret = ");
        dprint_int(result);
        dprint_char('\n');
        asm("ECALL");
    }
}

void test_all(){
    test(1, "lui tests:\n", test_lui);
    test(2, "auipc tests:\n", test_auipc);
    test(3, "ADD/SUB tests:\n", test_addSub);
    test(4, "load tests:\n", test_load);
    test(5, "store tests:\n", test_store);
    test(6, "SLT tests:\n", test_slt);
    test(7, "Shift tests:\n", test_shifts);
}
