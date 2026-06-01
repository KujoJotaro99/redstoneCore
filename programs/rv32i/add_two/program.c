__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 5;
volatile unsigned int input_b = 7;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    result = input_a + input_b;

    while (1) {
    }
}
