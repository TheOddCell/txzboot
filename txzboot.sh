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

mkdir -p /proc /sys /dev /mnt /mnt/proc /mnt/sys /mnt/dev

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
exec 5>/dev/kmsg
echo "<0>txzboot.loader: loading">&5
echo "txzboot">/proc/sys/kernel/hostname
echo "<0>txzboot.loader: set hostname to 'txzboot'">&5
echo "<0>txzboot.loader: core filesystems mounted">&5

if ! [ -f /boot.txz ]; then
  echo "<0>txzboot.loader: no boot.txz found, dropping to shell">&5
  exec sh
fi
echo "Press any key within 5 seconds to configure"
CONFIG1SHELL="false"
CONFIGSHELL="false"
CONFIGPATH=""
CONFIGPATHSET="false"
CONFIGTARPROGRESS="false"
if read -t 5 -n 1 key 2>/dev/null; then
  echo "CONFIG: debug: exec [pid 1] shell now (press any key within 5 seconds to set)"
  if read -t 5 -n 1 key 2>/dev/null; then
    exec sh
  fi
  echo "CONFIG: debug: exec [pid 1] shell after tar (press any key within 5 seconds to set)"
  if read -t 5 -n 1 key 2>/dev/null; then
    CONFIG1SHELL="true"
  fi
  echo "CONFIG: debug: run regular shell after tar (not pid 1) (press any key within 5 seconds to set)"
  if read -t 5 -n 1 key 2>/dev/null; then
    CONFIGSHELL="true"
  fi
  echo "CONFIG: init: init path (press any key within 5 seconds to set)"
  if read -t 5 -n 1 key 2>/dev/null; then
    printf "init path: "
    read CONFIGPATH
    CONFIGPATHSET="true"
  fi
  echo "CONFIG: tar: show untar progress (press any key within 5 seconds to set)"
  if read -t 5 -n 1 key 2>/dev/null; then
    CONFIGTARPROGRESS="true"
  fi
fi
echo "<0>txzboot.loader: starting untar">&5
if $CONFIGTARPROGRESS; then
  tar -vxJf /boot.txz -C /mnt
else
  tar -xJf /boot.txz -C /mnt
fi
echo "<0>txzboot.loader: done untar">&5
if $CONFIG1SHELL; then
  exec sh
elif $CONFIGSHELL; then
  sh
fi

mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -t devtmpfs dev /mnt/dev
echo "<0>txzboot.loader: core filesystems mounted at target">&5

echo "txzboot.loader ready"

if $CONFIGPATHSET; then
  echo "<0>txzboot.loader: searching for init $CONFIGPATH">&5
  [ -f /mnt/init ] && exec chroot /mnt "$CONFIGPATH"
fi
echo "<0>txzboot.loader: searching for init /init">&5
[ -f /mnt/init ] && exec chroot /mnt /init
echo "<0>txzboot.loader: searching for init /linuxrc">&5
[ -f /mnt/linuxrc ] && exec chroot /mnt /linuxrc
echo "<0>txzboot.loader: searching for init /sbin/init">&5
[ -f /mnt/sbin/init ] && exec chroot /mnt /sbin/init
echo "<0>txzboot.loader: searching for init /bin/init">&5
[ -f /mnt/bin/init ] && exec chroot /mnt /bin/init
echo "<0>txzboot.loader: could not find init">&5

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
 | cpio --null -o --format=newc \
 | zstd -19 -T0 > ../initramfs-full.cpio.zst
cd ..
ukify build --linux /boot/vmlinuz-linux --initrd initramfs-full.cpio.zst --cmdline "rw" --output "txzboot.uki.efi"
echo "txzboot.loader created"
echo "Cleaning up..."
rm -rf rootfs initramfs-full.cpio.zst
