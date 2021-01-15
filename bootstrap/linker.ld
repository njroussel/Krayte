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

    .test_table :
    {
        /* The run_tests routine expects the TEST_TABLE_START and TEST_TABLE_END
         * symbols to indicate the start (respectively end) of the test table.
         */
        TEST_TABLE_START = .;
        *(.data.test_table)
        TEST_TABLE_END = .;
    }

    BOOTSTRAP_END = .;
}
