#include "types.h"

extern void dprint(WORD value);
extern void dprint_hex(WORD value);
extern void dprint_char(char value);
extern void dprint_int(WORD value);
extern void dprint_str(char *str);
extern void dprint_intvar(char *name, WORD value);
extern void dprint_hexvar(char *name, WORD value);
void hex_output(unsigned long value);
