__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile int signed_a = -5;
volatile int signed_b = 7;
volatile unsigned int unsigned_a = 0xfffffff0;
volatile unsigned int unsigned_b = 16;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int score = 0;

    if (signed_a < signed_b) {
        score = score + 1;
    }

    if (signed_b >= signed_a) {
        score = score + 2;
    }

    if (unsigned_a > unsigned_b) {
        score = score + 4;
    }

    if (unsigned_b <= unsigned_a) {
        score = score + 8;
    }

    result = score;

    while (1) {
    }
}
