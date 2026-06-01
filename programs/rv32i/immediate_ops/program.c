__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 0x12345678;
volatile int input_b = -3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int x = input_a;
    unsigned int y = (x & 0x0ff) | 0x500;
    unsigned int z = y ^ 0x155;
    unsigned int score = z;

    if (input_b < 4) {
        score = score + 0x10;
    }

    if ((unsigned int)input_b > 4u) {
        score = score + 0x20;
    }

    result = score;

    while (1) {
    }
}
