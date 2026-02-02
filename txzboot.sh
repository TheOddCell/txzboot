#!/bin/bash
# sudo pacman -S ukify cpio zstd curl
if [ -z "$1" ]; then
  echo "Please provide the path to your tar.xz."
  exit 1
fi
echo "txzboot.maker"
mkdir rootfs
mkdir rootfs/bin
[ ! -f "/tmp/busybox-static" ] && curl -fL https://files.obsidianos.xyz/~odd/static/busybox -o /tmp/busybox-static
[ -f "/tmp/busybox-static" ] && chmod +x /tmp/busybox-static
cp /tmp/busybox-static rootfs/bin/busybox
mkdir rootfs/etc
ln -s ../proc/self/mounts rootfs/etc/mtab
echo "txzboot.loader dependancies installed"
cd rootfs/bin
./busybox --install .
cd ../..
cat > rootfs/init << 'EOF'
#!/bin/sh
export PATH="/bin"
echo "txzboot.loader"

mkdir -p /proc /sys /dev /mnt /mnt/proc /mnt/sys /mnt/dev

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

tar -vxJf /boot.txz -C /mnt

mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -t devtmpfs dev /mnt/dev

echo "txzboot.loader ready"

[ -f /mnt/init ] && exec chroot /mnt /init
[ -f /mnt/linuxrc ] && exec chroot /mnt /linuxrc
[ -f /mnt/sbin/init ] && exec chroot /mnt /sbin/init
[ -f /mnt/bin/init ] && exec chroot /mnt /bin/init

echo "ERROR: No valid init found. Type path or Ctrl+D to drop to shell."
echo "       Use the command 'proper' to get an init which miiiiiiiight work in a pinch."

if ! read nextsteps; then echo "Good luck"; exec sh; fi
[ "${nextsteps#/}" = "$nextsteps" ] && nextsteps="/$nextsteps"
[ -f "/mnt$nextsteps" ] && exec chroot /mnt "$nextsteps"
[ "$nextsteps" = "proper" ] && exec init
echo "ERROR: not valid, dropping to txzboot pid 1 shell."
echo "Good luck"
exec sh
EOF
chmod a+x rootfs/init
echo "txzboot.loader installed"
cp "$1" rootfs/boot.txz
echo "boot.txz added"
cd rootfs
#bash
find . -print0 \
 | cpio --null -ov --format=newc \
 | zstd -19 -T0 > ../initramfs-full.cpio.zst
cd ..
ukify build --linux /boot/vmlinuz-linux --initrd initramfs-full.cpio.zst --cmdline "rw" --output "txzboot.uki.efi"
echo "txzboot.loader created"
echo "Cleaning up..."
rm -rf rootfs initramfs-full.cpio.zst
