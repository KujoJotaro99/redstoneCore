ENTRY(rvtest_entry_point)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 512K
    DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 512K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text.init.*)
        *(.text.rvtest)
        *(.text.rvtest.*)
        *(.text.rvmodel)
        *(.text.rvmodel.*)
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
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > DMEM

    .bss (NOLOAD) : {
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > DMEM
}
