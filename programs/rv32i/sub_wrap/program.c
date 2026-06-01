__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 3;
volatile unsigned int input_b = 9;
volatile unsigned int input_c = 0xffffffff;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int x = input_a - input_b;
    unsigned int y = input_c + 1;
    unsigned int z = x - y;

    result = z;

    while (1) {
    }
}
