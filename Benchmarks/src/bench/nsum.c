#define N 250 
#define DTYPE long long

#include "../debug.h"

void main(void){
    DTYPE sum = 0;
    for (DTYPE i = -N; i <= N; i+=2)
        sum += i;
    dprint_intvar("Signed Sum", sum);
    for (unsigned DTYPE i = 1; i <= N; i++)
        sum += i;
    dprint_intvar("Unsigned Sum", sum);
    for (unsigned DTYPE i = 1; i <= N; i++)
        sum -= i;
    dprint_intvar("Unsigned Sub", sum);
    for (DTYPE i = -N; i <= N; i+=2)
        sum -= i;
    dprint_intvar("Signed Sub", sum);
}
