#![no_std]
#![no_main]

use core::panic::PanicInfo;

fn log(msg: &str) -> () {
    let vga_buffer_base = 0xB8000;
    let mut i = 0;
    for c in msg.bytes() {
        let add = (vga_buffer_base + i) as *mut u16;
        i += 1;
        unsafe {
            *add = ((7 << 16) as u16) | (c as u16);
        }
    }
}

#[no_mangle] // Tell the compiler not to mangle the name of this function.
pub extern "C" fn _start() -> ! {
    let msg: &'static str = "Hello World baremetal";
    log(msg);
    loop {}
}

// This function is called on panic.
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
