__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile signed char signed_byte = -2;
volatile unsigned char unsigned_byte = 250;
volatile signed short signed_half = -3;
volatile unsigned short unsigned_half = 500;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    int a = signed_byte;
    unsigned int b = unsigned_byte;
    int c = signed_half;
    unsigned int d = unsigned_half;

    result = (unsigned int)(a + c) + b + d;

    while (1) {
    }
}
