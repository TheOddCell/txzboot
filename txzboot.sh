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
exec </dev/console >/dev/console 2>&1
echo "txzboot.loader"

mkdir -p /proc /sys /dev /mnt /mnt/proc /mnt/sys /mnt/dev

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

if ! [ -f /boot.txz ]; then exec sh; fi
#trap 'exec sh' TSTP
i=5
while [ $i -gt 0 ]; do
  printf '\rPress any key within %d second(s) to get a shell... ' "$i"
  read -r -n 1 -t 1 _ && { echo; exec sh; break; }
  i=$((i-1))
done
echo "                                                     "
tar -vxJf /boot.txz -C /mnt

mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -t devtmpfs dev /mnt/dev

echo "txzboot.loader ready"
i=5
while [ $i -gt 0 ]; do
  printf '\rPress any key within %d second(s) to get a shell... ' "$i"
  read -r -n 1 -t 1 _ && { echo; exec sh; break; }
  i=$((i-1))
done
echo "                                                     "

[ -f /mnt/init ] && exec chroot /mnt /init
[ -f /mnt/linuxrc ] && exec chroot /mnt /linuxrc
[ -f /mnt/sbin/init ] && exec chroot /mnt /sbin/init
[ -f /mnt/bin/init ] && exec chroot /mnt /bin/init

echo "ERROR: No valid init found. Type path or Ctrl+D to drop to a shell."

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
if [ "$1" != '--shellonly' ]; then
  cp "$1" rootfs/boot.txz
  echo "boot.txz added"
fi
cd rootfs
find . -print0 \
 | cpio --null -ov --format=newc \
 | zstd -19 -T0 > ../initramfs-full.cpio.zst
cd ..
ukify build --linux /boot/vmlinuz-linux --initrd initramfs-full.cpio.zst --cmdline "rw" --output "txzboot.uki.efi"
echo "txzboot.loader created"
echo "Cleaning up..."
rm -rf rootfs initramfs-full.cpio.zst
