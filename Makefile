.DELETE_ON_ERROR:
.PHONY: all clean qemu netboot iso

ifeq ($(shell uname),Linux)
ACCEL ?= "kvm"
SMM ?= on
else ifeq ($(shell uname),Darwin)
ACCEL ?= "hvf"
SMM ?= off
else
ACCEL ?= "tcg"
SMM ?= on
endif


all: netboot

iso: build/out/tateru-boot.iso

.iid: Dockerfile $(shell find profile -type f)
	[ -s .iid ] && docker rmi --no-prune --force $(shell cat .iid) || true
	rm -f .iid
	docker build profile -f Dockerfile --iidfile .iid

.cid: .iid
	[ -s .cid ] && docker rm $(shell cat .cid) || true
	rm -f .cid
	docker run --privileged --cidfile .cid -ti \
		$(shell cat .iid) /usr/bin/mkarchiso -v /profile

build/.dummy: .cid
	rm -fr build
	mkdir build
	docker export $(shell cat .cid) | tar -xf - -C build out/ work/iso/arch/boot
	touch $@

build/out/tateru-boot.iso: build/.dummy
	cp build/out/tateru-boot-*.iso $@
	@# Check the filesize to ensure the copytoram FS can fit it
	@[ $(shell bsdtar tvf build/out/tateru-boot-*.iso arch/x86_64/airootfs.sfs | awk '{print $$5}') -gt "400000000" ] && \
		echo '****************\nWARNING! The size of the airootfs has exceeded 400M, please adjust the ipxe.cfg.j2 template accordingly\n****************' \
		|| true

netboot: iso
	mkdir -p build/work/netboot/installer build/out
	bsdtar -x -C build/work/netboot/installer -f build/out/tateru-boot.iso \
		arch/x86_64/airootfs.sfs \
		arch/x86_64/airootfs.sha512 \
		arch/boot/x86_64/initramfs-linux.img \
		arch/boot/x86_64/vmlinuz-linux
	tar --create \
		--gzip \
		--file build/out/tateru-netboot.tar.gz \
		--directory build/work/netboot \
		installer

clean:
	\rm -fr .iid .cid build/

qemu: build/out/tateru-boot.iso
	qemu-system-x86_64 \
		-m 2048 \
		-cpu host \
		-uuid 00000000-0000-0000-0000-000000000001 \
		-device virtio-scsi-pci,id=scsi0 \
		-device "scsi-cd,bus=scsi0.0,drive=cdrom0" \
		-drive "id=cdrom0,if=none,format=raw,media=cdrom,readonly=on,file=build/out/tateru-boot.iso" \
		-kernel build/work/iso/arch/boot/x86_64/vmlinuz-linux \
		-initrd build/work/iso/arch/boot/x86_64/initramfs-linux.img \
		-append "cow_spacesize=768M loglevel=3 console=ttyS0 archisobasedir=arch archisolabel=TATERU svc=http://10.0.2.2:7708/" \
		-device virtio-net-pci,romfile=,netdev=net0 \
		-netdev user,hostfwd=tcp::5555-:22,id=net0 \
		-accel "$(ACCEL)" \
		-machine "type=q35,smm=$(SMM),usb=on" \
		-serial mon:stdio \
		-no-reboot \
		-nographic

