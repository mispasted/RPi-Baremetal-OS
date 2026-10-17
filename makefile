FILES := $(wildcard *.c) $(wildcard *.S)
OFILES := $(FILES:.c=.o)
OFILES := $(OFILES:.S=.o)

GCCFLAGS = -Wall -O0 -ffreestanding -nostdinc -nostdlib -nostartfiles -g
GCCPATH = aarch64-none-elf-gcc
Q=""
TFTPDIR = /tftpboot

.PHONY: all clean firmware

all: clean kernel8.img 

%.o: %.S
	aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

%.o: %.c
	aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

kernel8.img: $(OFILES) firmware
	aarch64-none-elf-ld -nostdlib $(OFILES) -T link.ld -o kernel8.elf
	aarch64-none-elf-objcopy -O binary kernel8.elf kernel8.img
	cp kernel8.img /tftpboot

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

firmware: config.txt $(TFTPDIR)/start4.elf $(TFTPDIR)/fixup4.dat $(TFTPDIR)/bcm2711-rpi-4-b.dtb

config.txt:
	cp config.txt /tftpboot

$(TFTPDIR)/start4.elf: 
	wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/start4.elf
	mv start4.elf $(TFTPDIR)
	
$(TFTPDIR)/fixup4.dat: 
	wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/fixup4.dat
	mv fixup4.dat $(TFTPDIR)

$(TFTPDIR)/bcm2711-rpi-4-b.dtb:
	wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/bcm2711-rpi-4-b.dtb
	mv bcm2711-rpi-4-b.dtb $(TFTPDIR)


