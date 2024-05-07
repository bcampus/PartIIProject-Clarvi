#include "debug.h"

void dprint(WORD value)
{
	asm ("csrw	0x7B2, %0" : : "r" (value) );
}

void dprint_hex(WORD value)
{
	asm ("csrw	0x800, %0" : : "r" (value) );
}

void dprint_char(char value)
{
	asm ("csrw	0x801, %0" : : "r" (value) );
}

void dprint_int(WORD value)
{
	asm ("csrw	0x802, %0" : : "r" (value) );
}

void dprint_str(char *str){
    for (int i = 0; str[i] != '\0'; i++){
        dprint_char(str[i]);
    }
}

void dprint_intvar(char *name, WORD value){
    dprint_str(name);
    dprint_char('=');
    dprint_int(value);
    dprint_char('\n');
}

void dprint_hexvar(char *name, WORD value){
    dprint_str(name);
    dprint_char('=');
    dprint_hex(value);
    dprint_char('\n');
}

void hex_output(unsigned long value){
    volatile unsigned long *hex_leds = (unsigned long *) 0x04000080;
    *hex_leds = value;
}

