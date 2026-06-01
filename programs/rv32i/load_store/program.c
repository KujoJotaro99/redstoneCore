__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int word = 0x11223344;
volatile unsigned char byte_data[4] = {1, 2, 3, 4};
volatile unsigned short half_data[2] = {0x0010, 0x0020};

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int byte_sum = byte_data[0] + byte_data[1] + byte_data[2] + byte_data[3];
    unsigned int half_sum = half_data[0] + half_data[1];

    byte_data[2] = (unsigned char)byte_sum;
    half_data[1] = (unsigned short)half_sum;

    result = word + byte_data[2] + half_data[1];

    while (1) {
    }
}
