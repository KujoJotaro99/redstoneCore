__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 0x55aa00ff;
volatile unsigned int input_b = 0x0f0ff0f0;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int x = input_a ^ input_b;
    unsigned int y = input_a & input_b;
    unsigned int z = x | y;

    result = z;

    while (1) {
    }
}
