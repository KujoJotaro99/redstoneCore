__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int outer_count = 4;
volatile unsigned int inner_count = 3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int sum = 0;

    for (unsigned int i = 0; i < outer_count; i = i + 1) {
        for (unsigned int j = 0; j < inner_count; j = j + 1) {
            sum = sum + i + j;
        }
    }

    result = sum;

    while (1) {
    }
}
