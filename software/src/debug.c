void dprint_hex(int value)
{
	asm ("csrw	0x800, %0" : : "r" (value) );
}

void dprint_char(char value)
{
	asm ("csrw	0x801, %0" : : "r" (value) );
}

void dprint_int(int value)
{
	asm ("csrw	0x802, %0" : : "r" (value) );
}

void dprint_str(char *str){
    for (int i = 0; str[i] != '\0'; i++){
        dprint_char(str[i]);
    }
}

