__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int count = 8;
volatile unsigned int step = 3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int sum = 0;

    for (unsigned int i = 0; i < count; i = i + 1) {
        sum = sum + step;
    }

    result = sum;

    while (1) {
    }
}
