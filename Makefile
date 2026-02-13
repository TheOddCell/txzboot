all: .busybox .vmlinuz txzboot

txzboot: .vmlinuz.b64 .busybox.b64 .txzboot.loader.b64 .sfsboot.loader.b64
	awk ' \
	BEGIN { \
		getline bb < ".busybox.b64"; \
		getline l  < ".txzboot.loader.b64"; \
		getline s  < ".sfsboot.loader.b64"; \
		getline v  < ".vmlinuz.b64"; \
	} \
	{ \
		gsub(/<\[busybox\]>/, bb); \
		gsub(/<\[txzboot\.loader\]>/, l); \
		gsub(/<\[sfsboot\.loader\]>/, s); \
		gsub(/<\[vmlinuz\]>/, v); \
		print; \
	} \
	' txzboot.maker.sh > txzboot; \
	chmod +x txzboot

clean: nodepclean
	rm -rf linux
	rm -rf busybox

nodepclean:
	rm -rf txzboot .busybox.b64 .txzboot.loader.b64 txzboot.uki.efi rootfs initramfs-full.cpio.zst .vmlinuz .vmlinuz.b64 .busybox .sfsboot.loader.b64

.busybox.b64: .busybox
	base64 -w0 .busybox>.busybox.b64

.txzboot.loader.b64:
	base64 -w0 ./txzboot.loader.sh > .txzboot.loader.b64

.sfsboot.loader.b64:
	base64 -w0 ./sfsboot.loader.sh > .sfsboot.loader.b64

.PHONY: all clean nodepclean

.vmlinuz: linux
	cd linux && \
	make defconfig && \
	sed -i 's/=m$$/=y/'							.config && \
	sed -i 's/(none)/txzboot/g' 						.config && \
	sed -i 's/# CONFIG_SQUASHFS is not set/CONFIG_SQUASHFS=y/'		.config && \
	sed -i 's/# CONFIG_OVERLAY_FS is not set/CONFIG_OVERLAY_FS=y/'		.config && \
	sed -i 's/# CONFIG_FUSE_FS is not set/CONFIG_FUSE_FS=y/'		.config && \
	sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-txzboot"/'	.config && \
	yes '' | make oldconfig && \
	sed -i 's/# CONFIG_SQUASHFS_LZ4 is not set/CONFIG_SQUASHFS_LZ4=y/'	.config && \
	sed -i 's/# CONFIG_SQUASHFS_LZO is not set/CONFIG_SQUASHFS_LZO=y/'	.config && \
	sed -i 's/# CONFIG_SQUASHFS_XZ is not set/CONFIG_SQUASHFS_XZ=y/'	.config && \
	sed -i 's/# CONFIG_SQUASHFS_ZSTD is not set/CONFIG_SQUASHFS_ZSTD=y/'	.config && \
	yes '' |make oldconfig && \
	make -j$$(nproc)
	cp linux/arch/$$(uname -m)/boot/bzImage .vmlinuz

.vmlinuz.b64: .vmlinuz
	base64 -w0 .vmlinuz>.vmlinuz.b64

linux:
	curl -fL https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.19.tar.xz | tar -xvJ
	mv linux-6.19 linux

.busybox: busybox
	cd busybox && \
	make defconfig && \
	sed -i 's/CONFIG_TC=y/CONFIG_TC=n/g' .config && \
	yes | make oldconfig && \
	LDFLAGS='-static' make -j$(nproc)
	cp busybox/busybox .busybox

busybox:
	curl -fL https://busybox.net/downloads/busybox-1.37.0.tar.bz2 | tar -xvj
	mv busybox-1.37.0 busybox
