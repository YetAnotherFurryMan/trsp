#include <stdio.h>
#include <stdint.h>

extern int32_t add(int32_t, int32_t);

int main(int argc, const char** argv){
    printf("Hello World!\n");
    int32_t x = add(1, 3);
    printf("1 + 3 = %d\n", x);
    return 0;
}
