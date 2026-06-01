__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int values[5] = {3, 1, 4, 1, 5};

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int running = 0;

    for (unsigned int i = 0; i < 5; i++) {
        running = running + values[i];
        values[i] = running;
    }

    unsigned int checksum = values[0];
    checksum = checksum + (values[1] << 1);
    checksum = checksum + values[2] + values[2] + values[2];
    checksum = checksum + (values[3] << 2);
    checksum = checksum + (values[4] << 2) + values[4];

    result = checksum;

    while (1) {
    }
}
