#!/bin/bash
# sudo pacman -S ukify cpio zstd curl base64
if [ -z "$1" ]; then
  echo "Please provide the path to your tar.xz."
  exit 1
fi
TYPE="txz"
if [ "${1##*.}" = "sfs" ]; then TYPE=sfs; fi
echo "${TYPE}boot.maker"
mkdir rootfs
mkdir rootfs/bin
echo "<[busybox]>" | base64 -d > rootfs/bin/busybox
chmod a+x rootfs/bin/busybox
mkdir rootfs/etc
ln -s ../proc/self/mounts rootfs/etc/mtab
echo "${TYPE}boot.loader dependancies installed"
cd rootfs/bin
./busybox --install .
cd ../..
if [ "$TYPE" = "sfs" ]; then
  echo "<[sfsboot.loader]>" | base64 -d > rootfs/bin/sfsboot.loader
  ln rootfs/bin/sfsboot.loader rootfs/init
else
  echo "<[txzboot.loader]>" | base64 -d > rootfs/bin/txzboot.loader
  ln rootfs/bin/txzboot.loader rootfs/init
fi
chmod a+x rootfs/init
echo "${TYPE}boot.loader installed"
if [ "$TYPE" = "sfs" ]; then
  cp "$1" rootfs/boot.sfs
  echo "boot.sfs added"
elif [ "$1" != 'shell' ]; then
  if [ "${1##*.}" = "xz" ]; then
    cp "$1" rootfs/boot.txz
    echo "boot.txz added"
  elif [ "${1##*.}" = "gz" ]; then
    cp "$1" rootfs/boot.tgz
    echo "boot.tgz added"
  else
    cp "$1" rootfs/boot.tar
    echo "boot.tar added"
  fi
fi
cd rootfs
find . -print0 \
 | cpio --null -o --format=newc \
 | zstd -19 -T0 > ../initramfs-full.cpio.zst
cd ..
echo "<[vmlinuz]>" | base64 -d > vmlinuz.tmp
ukify build \
  --linux vmlinuz.tmp \
  --initrd initramfs-full.cpio.zst \
  --cmdline "rw" --output "${TYPE}boot.uki.efi"
rm vmlinuz.tmp
echo "${TYPE}boot.loader created"
if [ "$2" != "--nocleanup" ]; then
  echo "Cleaning up..."
  rm -rf rootfs initramfs-full.cpio.zst
fi
