__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile int signed_a = -2;
volatile int signed_b = 5;
volatile unsigned int unsigned_a = 2;
volatile unsigned int unsigned_b = 5;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    unsigned int score = 0;

    if (signed_a != signed_b) {
        score = score + 1;
    }

    if (signed_b == 5) {
        score = score + 2;
    }

    if (signed_a < signed_b) {
        score = score + 4;
    }

    if (signed_b >= signed_a) {
        score = score + 8;
    }

    if (unsigned_a < unsigned_b) {
        score = score + 16;
    }

    if (unsigned_b >= unsigned_a) {
        score = score + 32;
    }

    result = score;

    while (1) {
    }
}
