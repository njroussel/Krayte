/* Entry point of the bootstrap code. This is what will be loaded at address
 * 0x7C00 by the BIOS */
ENTRY(entry)

SECTIONS
{
    . = 0x7C00;
    BOOTSTRAP_START = .;

    .text :
    {
        SECTION_TEXT_START = .;

        /* The .text section of the first sector is put first. This is what will
         * be loaded by the BIOS. */
        *(.text.first_sector)

        /* Put the remaining .text sections in the back. */
        *(.text)

        SECTION_TEXT_END = .;
    }

    .data :
    {
        SECTION_DATA_START = .;
        *(.data)
        SECTION_DATA_END = .;
    }

    BOOTSTRAP_END = .;
}
