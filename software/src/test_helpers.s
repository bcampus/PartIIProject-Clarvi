#asmsyntax=asm

#Test helpers designed to ensure that specific instructions are being used and
#that they are being compared to the results of *different* instructions.

.macro  DEBUG_PRINT     reg
	csrw 0x7B2, \reg
.endm

.macro  ASSERT          r1, r2, err_val
    li      a0, \err_val # return value if test fails
    addi    s3, s2, \err_val
    
    sw s3, 0(s1)

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

.macro  ASSERT_TRUE       r1, err_val, jmp
    li      a0, \err_val # return value if test fails

    DEBUG_PRINT \r1 
    beqz    \r1, \jmp
.endm

.macro  ASSERT_FALSE       r1, err_val, jmp
    li      a0, \err_val # return value if test fails

    DEBUG_PRINT \r1 
    bgtz    \r1, \jmp
.endm

.global test_lui
test_lui:

    li s1, 0x04000080
    mv s2, a0 #a0 contains the test ID

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

.global test_slt
test_slt:
    #unsigned t0 > t1 > t2 > t3 > t4 > zero
    #  signed t2 > t3 > t4 > zero > t0 > t1  
    li t0, 0xffffffffffffffff
    li t1, 0xfffffffffffffffe
    li t2, 0x7fffffffffffffff
    li t3, 0x0000000100000000
    li t4, 0x0000000080000000

    slt t5, t0, t1
    ASSERT_FALSE t5, 1, slt_ret
    slt t5, t1, t0
    ASSERT_TRUE  t5, 2, slt_ret
    slt t5, t2, t1
    ASSERT_FALSE t5, 3, slt_ret
    slt t5, t3, t2
    ASSERT_TRUE  t5, 4, slt_ret
    slt t5, t4, t3
    ASSERT_TRUE  t5, 5, slt_ret
    slt t5, t4, zero
    ASSERT_FALSE t5, 6, slt_ret
    slt t5, t0, zero
    ASSERT_TRUE  t5, 7, slt_ret

    sltu t5, t0, t1
    ASSERT_FALSE t5, 8, slt_ret
    sltu t5, t1, t0
    ASSERT_TRUE  t5, 9, slt_ret
    sltu t5, t2, t1
    ASSERT_TRUE t5, 10, slt_ret
    sltu t5, t3, t2
    ASSERT_TRUE  t5, 11, slt_ret
    sltu t5, t4, t3
    ASSERT_TRUE  t5, 12, slt_ret
    sltu t5, t4, zero
    ASSERT_FALSE t5, 13, slt_ret
    sltu t5, t0, zero
    ASSERT_FALSE  t5, 14, slt_ret

    # Pass
    addi    a0, zero, 0x0
slt_ret:
    ret
    

.global helper_loadTest
helper_loadTest:
    li s1, 0x04000080
    mv s2, a0 #a0 contains the test ID

    #a1 -> t0: memory location containing a3 -> t2
    #a2 -> t1: memory location containing a4 -> t3
    #Values loaded from a1 should sign extend 0
    #Values loaded from a2 should sign extend 1
    mv      t0, a1
    mv      t1, a2
    mv      t2, a3
    mv      t3, a4



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
    mv      t0, a1
    mv      t1, a2


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

.global helper_addSubTest
helper_addSubTest:
    li t0, 0x7a547fffffffffff
    li t1, 0x15a2000000000001
    li t2, 0x8ff6800000000000
    li t3, 0x7a54800000000000

    #Add/Sub tests
    add t4, t0, t1
    ASSERT_EQ t4, t2, 1, addTest_ret
    sub t4, t2, t0
    ASSERT_EQ t4, t1, 2, addTest_ret
    sub t4, t2, t1
    ASSERT_EQ t4, t0, 3, addTest_ret

    
    #Demonstrate ADDI/SUBI
    addi t4, t0, 1
    ASSERT_EQ t4, t3, 4, addTest_ret
    addi t4, t3, -1
    ASSERT_EQ t4, t0, 5, addTest_ret

    li t2, 0xfffffffffffffffe
    li t3, 0x00000000ffffffff
    #Demonstrate ADDW/SUBW
    ADDW t4, t0, t1
    ASSERT_EQ t4, zero, 6, addTest_ret
    ADDW t4, t0, t3
    ASSERT_EQ t4, t2, 7, addTest_ret
    SUBW t4, t0, t1
    ASSERT_EQ t4, t2, 8, addTest_ret
    SUBW t4, t0, t3
    ASSERT_EQ t4, zero, 9, addTest_ret

    #Demonstrate ADDIW
    ADDIW t4, t0, 1
    ASSERT_EQ t4, zero, 10, addTest_ret
    ADDIW t4, t0, -1
    ASSERT_EQ t4, t2, 11, addTest_ret

    #Demonstrate sext.w (=addiw) pseudoinstruction
    li t0, 0x0000000080000000
    li t1, 0xffffffff80000000
    sext.w t2, t0
    ASSERT_EQ t1, t2, 12, addTest_ret

    li      a0, 0
addTest_ret:
    ret
