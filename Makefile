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
	chmod +x txzboot; \

clean:
	rm -rf txzboot busybox.b64 txzboot.loader.b64 txzboot.uki.efi rootfs initramfs-full.cpio.zst
	cd linux; \
	make clean

busybox.b64:
	curl -fsSL '$(BUSYBOX_URL)' | base64 -w0 > busybox.b64;

txzboot.loader.b64:
	base64 -w0 ./txzboot.loader.sh > txzboot.loader.b64;

.PHONY: all clean

vmlinuz: linux
	cd linux && \
	make defconfig && \
	sed -i 's/=m$$/=y/' .config && \
	make -j$$(nproc) && \
	cp linux/arch/$$(uname -m)/boot/bzImage vmlinuz

linux:
	git submodule init
	cd linux && \
	git checkout v6.19
