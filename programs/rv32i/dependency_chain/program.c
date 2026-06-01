__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 1;
volatile unsigned int input_b = 2;
volatile unsigned int input_c = 3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int x = input_a;
    x = x + input_b;
    x = x << input_c;
    x = x - input_a;
    x = x ^ input_c;
    x = x + input_b;

    result = x;

    while (1) {
    }
}
