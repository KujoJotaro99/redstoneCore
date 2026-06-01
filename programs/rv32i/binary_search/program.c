__attribute__((section(".data.result")))
volatile unsigned int result = 0xdead0000;
volatile unsigned int values[7] = {2, 4, 6, 8, 10, 12, 14};
volatile unsigned int target_hit = 10;
volatile unsigned int target_miss = 3;

__attribute__((noreturn, used, section(".text.start")))
void _start(void)
{
    int low = 0;
    int high = 6;
    int hit_index = -1;

    while (low <= high) {
        int mid = low + ((high - low) >> 1);
        unsigned int value = values[mid];

        if (value == target_hit) {
            hit_index = mid;
            break;
        }

        if (value < target_hit) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    low = 0;
    high = 6;
    int miss_index = -1;

    while (low <= high) {
        int mid = low + ((high - low) >> 1);
        unsigned int value = values[mid];

        if (value == target_miss) {
            miss_index = mid;
            break;
        }

        if (value < target_miss) {
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    result = (unsigned int)((hit_index + 1) << 4) + (miss_index == -1 ? 7u : 0u);

    while (1) {
    }
}
