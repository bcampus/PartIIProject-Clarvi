# RISC-V baremetal init.s
# This code is executed first.
.macro  DEBUG_PRINT     reg
	csrw 0x7B2, \reg
.endm

.macro  ASSERT          r1, r2, err_val
    li      a0, \err_val # return value if test fails

    DEBUG_PRINT \r1 
    DEBUG_PRINT \r2
.endm

.macro  ASSERT_NEQ      r1, r2, err_val, jmp
    ASSERT  \r1, \r2, \err_val
    beq     \r1, \r2, \jmp
.endm

.macro  ASSERT_EQ       r1, r2, err_val, jmp
    ASSERT  \r1, \r2, \err_val
    bne    \r1, \r2, \jmp
.endm

.section .text.init
entry:

    la    sp, __sp-32   # set up the stack pointer, using a constant defined in the linker script.

    la    t0, end       # on hardware, ECALL doesn't stop the CPU, so define
                        # a handler to catch the ECALL and spin
    csrrw zero,0x305,t0 # set the address of the handler (CSR 0x305 is the trap handler base register)

    call  main          # call the main function
    ecall               # halt the simluation when it returns


end:
    j end               # loop when finished if there is no environment to return to.

.global test_lui
test_lui:


    lui     t0, 0x80000

    #Load expected value into t1 without using LUI
    addi    t1, zero, 0x1
    slli    t1, t1, 31
    sub     t1, zero, t1

    ASSERT_EQ t0, t1, 1, lui_ret

    lui t0, 0x70000

    #Load expected value into t1 without using LUI
    addi    t1, zero, 0x7
    slli    t1, t1, 28

    ASSERT_EQ t0, t1, 2, lui_ret

    li      a0, 0
lui_ret:
    ret

    
.global test_auipc
test_auipc:


    #Use AUIPC and load equivalent value into t0
    AUIPC   t0,     0         
    AUIPC   t1, 0x1     # Add 0x1000 to PC
    addi    t0, t0, 4   # Account for different load times
    lui     t2, 0x1
    add     t0, t0, t2  # Use alternative method to get the same value

    ASSERT_EQ t0, t1, 1, auipc_ret

    #Use AUIPC and load equivalent value into t0
    AUIPC   t0,     0         
    AUIPC   t1, 0xafafa     # Add 0xffffffffafafa000 to PC
    addi    t0, t0, 4   # Account for different load times
    lui     t2, 0xafafa
    add     t0, t0, t2  # Use alternative method to get the same value

    ASSERT_EQ t0, t1, 2, auipc_ret
    # Pass
    addi    a0, zero, 0x0
auipc_ret:
    ret


.global helper_loadTest
helper_loadTest:
    #a0 -> t0: memory location containing a2 -> t2
    #a1 -> t1: memory location containing a3 -> t3
    #Values loaded from a0 should sign extend 0
    #Values loaded from a1 should sign extend 1
    mv      t0, a0
    mv      t1, a1
    mv      t2, a2
    mv      t3, a3


    # 64-bit test
    ld      t4, 0(t0)
    ld      t5, 0(t1)

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 1, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 2, lTest_ret


    # 32-bit tests
    lw      t4, 0(t0)
    lw      t5, 0(t1)

    sext.w  t2, t2       #Should produce expected value for load
    sext.w  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 3, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 4, lTest_ret

    lwu     t4, 0(t0)
    lwu     t5, 0(t1)

    zext.w  t2, t2       #Should produce expected value for load
    zext.w  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 5, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 6, lTest_ret

    
    # 16-bit tests
    lh      t4, 0(t0)
    lh      t5, 0(t1)

    sext.h  t2, t2       #Should produce expected value for load
    sext.h  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 7, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 8, lTest_ret

    lhu     t4, 0(t0)
    lhu     t5, 0(t1)

    zext.h  t2, t2       #Should produce expected value for load
    zext.h  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 9, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 10, lTest_ret

    

    # 8-bit tests
    lb      t4, 0(t0)
    lb      t5, 0(t1)

    sext.b  t2, t2       #Should produce expected value for load
    sext.b  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 11, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 12, lTest_ret

    lbu     t4, 0(t0)
    lbu     t5, 0(t1)

    zext.b  t2, t2       #Should produce expected value for load
    zext.b  t3, t3

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t4, t2, 13, lTest_ret

    #ASSERT Loaded value is equal to passed value
    ASSERT_EQ t5, t3, 14, lTest_ret


    li      a0, 0
lTest_ret:
    ret


.global helper_storeTest
helper_storeTest:
    #a0 -> t0: memory location containing a1 -> t1
    mv      t0, a0
    mv      t1, a1


    # 8-bit test
    sb      zero, 0(t0)
    ld      t3, 0(t0)
    srli    t1, t1, 8 #Set lower 8 bits to zero
    slli    t1, t1, 8

    #ASSERT stored value (t3) equals expected value (t1)
    ASSERT_EQ t3, t1, 1, sTest_ret

    # 16-bit test
    sh      zero, 0(t0)
    ld      t3, 0(t0)
    srli    t1, t1, 16 #Set lower 8 bits to zero
    slli    t1, t1, 16

    #ASSERT stored value (t3) equals expected value (t1)
    ASSERT_EQ t3, t1, 2, sTest_ret

    # 32-bit test
    sw      zero, 0(t0)
    ld      t3, 0(t0)
    srli    t1, t1, 32 #Set lower 8 bits to zero
    slli    t1, t1, 32 

    #ASSERT stored value (t3) equals expected value (t1)
    ASSERT_EQ t3, t1, 3, sTest_ret

    # 64-bit test
    sd      zero, 0(t0)
    ld      t3, 0(t0)

    #ASSERT stored value (t3) equals expected value (zero)
    ASSERT_EQ t3, zero, 4, sTest_ret

    li      a0, 0
sTest_ret:
    ret

