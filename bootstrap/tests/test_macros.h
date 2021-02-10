// Register a test in the test table to be executed by the run_tests routine.
// @param test_name: The name of the test routine.
#define REGISTER_TEST(test_name)        ;\
    .section .data                      ;\
    __test_table_str_ ## test_name:     ;\
    .asciz #test_name                   ;\
    .section .data.test_table           ;\
    .byte 32                            ;\
    .long __test_table_str_##test_name  ;\
    .long test_name

// Register a test in the test table to be executed by the run_tests routine.
// 64-bit version.
// @param test_name: The name of the test routine.
#define REGISTER_TEST64(test_name)      ;\
    .section .data                      ;\
    __test_table_str_ ## test_name:     ;\
    .asciz #test_name                   ;\
    .section .data.test_table           ;\
    .byte 64                            ;\
    .long __test_table_str_##test_name  ;\
    .long test_name
