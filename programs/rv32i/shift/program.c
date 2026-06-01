__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 0x80000010;
volatile unsigned int input_b = 3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int left = input_a << input_b;
    unsigned int right = input_a >> input_b;
    int signed_right = ((int)input_a) >> input_b;

    result = left ^ right ^ (unsigned int)signed_right;

    while (1) {
    }
}
