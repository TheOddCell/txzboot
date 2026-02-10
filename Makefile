BUSYBOX_URL := https://files.obsidianos.xyz/~odd/static/busybox

all: txzboot vmlinuz

txzboot: busybox.b64 txzboot.loader.b64
	awk ' \
	BEGIN { \
		getline bb < "busybox.b64"; \
		getline l  < "txzboot.loader.b64"; \
	} \
	{ \
		gsub(/<\[busybox\]>/, bb); \
		gsub(/<\[txzboot\.loader\]>/, l); \
		print; \
	} \
	' txzboot.maker.sh > txzboot; \
	chmod +x txzboot

clean: nokernclean
	cd linux; \
	make clean
nokernclean:
	rm -rf txzboot busybox.b64 txzboot.loader.b64 txzboot.uki.efi rootfs initramfs-full.cpio.zst vmlinuz

busybox.b64:
	curl -fsSL "$(BUSYBOX_URL)" | base64 -w0 > busybox.b64

txzboot.loader.b64:
	base64 -w0 ./txzboot.loader.sh > txzboot.loader.b64;

.PHONY: all clean nokernclean

vmlinuz:
	git submodule init linux
	cd linux && \
	git checkout v6.19 && \
	make defconfig && \
	sed -i 's/=m$$/=y/' .config && \
	sed -i 's/(none)/txzboot/g' .config && \
	sed -i 's/# CONFIG_SQUASHFS is not set/CONFIG_SQUASHFS=y/' .config && \
	sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-txzboot"/' .config && \
	yes '' |make oldconfig && \
	make -j$$(nproc)
	cp linux/arch/$$(uname -m)/boot/bzImage vmlinuz
