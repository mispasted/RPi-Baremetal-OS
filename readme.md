A very simple baremetal project based on MIT's xv6.

Useful references: 
- [MIT's xv6](https://pdos.csail.mit.edu/6.828/2025/xv6.html)
- [Baremetal RPI guide](https://rpi4os.com/part1-bootstrapping/)

Dependances:
- The Aarch64 GCC build toolchain.
    - `aarch64-none-elf-gcc`
    - `aarch64-none-elf-ld`
    - `aarch64-none-elf-objcopy`
- `qemu-system-aarch64`
- `gnumake`

Running the project in QEMU:
Clone the project and run `> make run` in the project directory. 


