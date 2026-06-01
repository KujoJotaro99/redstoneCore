__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int word = 0xaabbccdd;
volatile unsigned char *byte_ptr = (volatile unsigned char *)&word;
volatile unsigned short *half_ptr = (volatile unsigned short *)&word;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    byte_ptr[1] = 0x12;
    half_ptr[1] = 0x3456;

    result = word;

    while (1) {
    }
}
