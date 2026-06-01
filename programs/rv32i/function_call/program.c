__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int input_a = 11;
volatile unsigned int input_b = 4;
unsigned int (*volatile selected_fn)(unsigned int, unsigned int);

__attribute__((noinline))
unsigned int add_fn(unsigned int a, unsigned int b)
{
    return a + b;
}

__attribute__((noinline))
unsigned int mix_fn(unsigned int a, unsigned int b)
{
    return (a << 2) - b;
}

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    selected_fn = add_fn;
    unsigned int x = selected_fn(input_a, input_b);

    selected_fn = mix_fn;
    result = selected_fn(x, input_b);

    while (1) {
    }
}
