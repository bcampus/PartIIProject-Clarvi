# RISC-V baremetal init.s
# This code is executed first.
.macro  DEBUG_PRINT     reg
	csrw 0x7B2, \reg
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

    li      a0, 1       # return value if this test fails

    lui     t0, 0x80000

    #Load expected value into t1 without using LUI
    addi    t1, zero, 0x1
    slli    t1, t1, 31
    sub     t1, zero, t1

    DEBUG_PRINT t0
    DEBUG_PRINT t1

    #Assert
    bne     t0, t1, lui_ret

    li      a0, 2       # return value if this test fails

    lui t0, 0x70000

    #Load expected value into t1 without using LUI
    addi    t1, zero, 0x7
    slli    t1, t1, 28

    DEBUG_PRINT t0
    DEBUG_PRINT t1
    
    #Assert
    bne     t0, t1, lui_ret

    li      a0, 0
lui_ret:
    ret

    
.global test_auipc
test_auipc:

    li      a0,     1   # return value if this test fails

    #Use AUIPC and load equivalent value into t0
    AUIPC   t0,     0         
    AUIPC   t1, 0x1     # Add 0x1000 to PC
    addi    t0, t0, 4   # Account for different load times
    lui     t2, 0x1
    add     t0, t0, t2  # Use alternative method to get the same value

    DEBUG_PRINT t0
    DEBUG_PRINT t1

    #Assert
    bne     t0, t1, auipc_ret

    li      a0, 2       # return value if this test fails

    #Use AUIPC and load equivalent value into t0
    AUIPC   t0,     0         
    AUIPC   t1, 0xafafa     # Add 0xffffffffafafa000 to PC
    addi    t0, t0, 4   # Account for different load times
    lui     t2, 0xafafa
    add     t0, t0, t2  # Use alternative method to get the same value

    DEBUG_PRINT t0
    DEBUG_PRINT t1

    # Assert
    bne     t0, t1, auipc_ret
    # Pass
    addi    a0, zero, 0x0
auipc_ret:
    ret


