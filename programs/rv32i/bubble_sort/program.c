__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int values[6] = {7, 1, 5, 3, 9, 2};

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    for (unsigned int pass = 0; pass < 5; pass++) {
        for (unsigned int i = 0; i < 5 - pass; i++) {
            unsigned int a = values[i];
            unsigned int b = values[i + 1];

            if (a > b) {
                values[i] = b;
                values[i + 1] = a;
            }
        }
    }

    unsigned int checksum = values[0];
    checksum = checksum + (values[1] << 1);
    checksum = checksum + values[2] + values[2] + values[2];
    checksum = checksum + (values[3] << 2);
    checksum = checksum + (values[4] << 2) + values[4];
    checksum = checksum + (values[5] << 2) + (values[5] << 1);

    result = checksum;

    while (1) {
    }
}
