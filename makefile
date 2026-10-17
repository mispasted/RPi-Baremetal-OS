FILES := $(wildcard *.c) $(wildcard *.S)
OFILES := $(FILES:.c=.o)
OFILES := $(OFILES:.S=.o)

GCCFLAGS = -Wall -O0 -ffreestanding -nostdinc -nostdlib -nostartfiles -g
GCCPATH = aarch64-none-elf-gcc
Q=""

all: clean kernel8.img

%.o: %.S
	aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

%.o: %.c
	aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

kernel8.img: $(OFILES) config.txt start4.elf fixup4.dat
	aarch64-none-elf-ld -nostdlib $(OFILES) -T link.ld -o kernel8.elf
	aarch64-none-elf-objcopy -O binary kernel8.elf kernel8.img
	cp kernel8.img /tftpboot
	chmod 777 /tftpboot/kernel8.img

clean:
	/bin/rm kernel8.elf *.o *.img > /dev/null 2> /dev/null || true

run: kernel8.img
	@qemu-system-aarch64 -M raspi4b -display none -serial null -serial mon:stdio -kernel kernel8.img -semihosting-config enable=on,target=native

qemu: kernel8.img
	@echo "[QEMU] running with $<"
	@echo "Ctrl-a x' to exit!"
	qemu-system-aarch64 -M raspi4b -display none -serial null -serial mon:stdio -kernel $< -S -s 


gdb: kernel8.elf
	@echo "[GDB]     running with $<"
	${Q}gdb -ex "target remote :1234" $<

config.txt:
	cp config.txt /tftpboot
	chmod 777 /tftpboot/config.txt

start4.elf: 
	wget https://github.com/raspberrypi/firmware/blob/master/boot/start4.elf
	cp start4.elf /tftpboot
	chmod 777 /tftpboot/start4.elf
	
fixup4.dat: 
	wget https://github.com/raspberrypi/firmware/blob/master/boot/fixup4.dat
	cp fixup4.dat /tftpboot
	chmod 777 /tftpboot/fixup4.dat



