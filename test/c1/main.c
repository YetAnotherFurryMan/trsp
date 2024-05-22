#include <stdio.h>
#include <stdint.h>

extern int32_t add(int32_t, int32_t);

int main(int argc, const char** argv){
    printf("Hello World!\n");
    printf("1 + 3 = %d\n", add(1, 3));
    return 0;
}
