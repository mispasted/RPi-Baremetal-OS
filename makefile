# Options include "qemu", "rpi"
PLATFORM ?= qemu
# Directory for tftp boot (files are copied there)
TFTPDIR:=/tftpboot

# Quiet
Q ?= @ 

PLATFORM_ASM := platform_rpi.S platform_qemu.S
ASM_SRCS := $(filter-out $(PLATFORM_ASM),$(wildcard *.S))

ifeq ($(PLATFORM),qemu) # No additional firmware files, and don't need copied to the $TFTPDIR
	ASM_SRCS := $(ASM_SRCS) platform_qemu.S
	FIRMWARE :=
else ifeq ($(PLATFORM),rpi) # Only download and copy files to $TFTPDIR if it's for the physical rpi
	ASM_SRCS := $(ASM_SRCS) platform_rpi.S
	FIRMWARE := boot-config $(TFTPDIR)/start4.elf $(TFTPDIR)/fixup4.dat $(TFTPDIR)/bcm2711-rpi-4-b.dtb
endif

FILES := $(wildcard *.c) $(ASM_SRCS)
OFILES := $(FILES:.c=.o)
OFILES := $(OFILES:.S=.o)

GCCFLAGS = -Wall -O0 -ffreestanding -nostdinc -nostdlib -nostartfiles -g
GCCPATH = aarch64-none-elf-gcc

.PHONY: all clean firmware boot-config

all: clean kernel8.img 

%.o: %.S
	${Q}aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

%.o: %.c
	${Q}aarch64-none-elf-gcc $(GCCFLAGS) -c $< -o $@

kernel8.img: $(OFILES) firmware
	${Q}aarch64-none-elf-ld -nostdlib $(OFILES) -T link.ld -o kernel8.elf
	${Q}aarch64-none-elf-objcopy -O binary kernel8.elf kernel8.img
	${Q}cp kernel8.img /tftpboot

clean:
	${Q}/bin/rm fixup4.dat bcm2711-rpi-4-b.dtb *.elf *.o *.img > /dev/null 2> /dev/null || true

run: kernel8.img
	@qemu-system-aarch64 -M raspi4b -display none -serial null -serial \
	mon:stdio -kernel kernel8.img -semihosting-config enable=on,target=native

qemu: kernel8.img
	@echo "[QEMU] running with $<"
	@echo "Ctrl-a x' to exit!"
	${Q}qemu-system-aarch64 -M raspi4b -display none -serial null -serial mon:stdio -kernel $< -S -s 


gdb: kernel8.elf
	@echo "[GDB]     running with $<"
	${Q}gdb -ex "target remote :1234" $<

firmware: $(FIRMWARE) 

boot-config: boot-config.txt
	${Q}cp boot-config.txt /tftpboot/config.txt

$(TFTPDIR)/start4.elf: 
	${Q}wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/start4.elf
	${Q}cp start4.elf $(TFTPDIR)
	
$(TFTPDIR)/fixup4.dat: 
	${Q}wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/fixup4.dat
	${Q}cp fixup4.dat $(TFTPDIR)

$(TFTPDIR)/bcm2711-rpi-4-b.dtb:
	${Q}wget https://raw.githubusercontent.com/raspberrypi/firmware/master/boot/bcm2711-rpi-4-b.dtb
	${Q}cp bcm2711-rpi-4-b.dtb $(TFTPDIR)


