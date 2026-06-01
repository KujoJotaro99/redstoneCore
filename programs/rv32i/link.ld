ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        *(.text.start)
        *(.text.start.*)
        *(.text)
        *(.text.*)
    } > IMEM

    .rodata : {
        *(.srodata)
        *(.srodata.*)
        *(.rodata)
        *(.rodata.*)
    } > DMEM

    .data : {
        *(.data.result)
        *(.data.result.*)
        *(.sdata)
        *(.sdata.*)
        *(.data)
        *(.data.*)
    } > DMEM

    .bss (NOLOAD) : {
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > DMEM
}
