#!/bin/sh
export PATH="/bin"
exec </dev/console >/dev/console 2>&1

mkdir -p /proc /sys /dev /mnt

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
exec 5>/dev/kmsg
echo "<0>sfsboot.loader: loading">&5
echo "sfsboot">/proc/sys/kernel/hostname
echo "<0>sfsboot.loader: set hostname to 'sfsboot'">&5
echo "<0>sfsboot.loader: core filesystems mounted">&5

if ! [ -f /boot.sfs ]; then
  echo "<0>sfsboot.loader: no boot.sfs found, dropping to shell">&5
  exec sh
fi
printf "Press enter within 5 seconds to configure\r"
CONFIGPATH=""
CONFIGPATHSET="false"
CONFIGDELROOTPASSWD="false"
if IFS= read -r -t 5 _; then
  unset key
  printf "\r                                                                          "
  printf "\rCONFIG: debug: exec [pid 1] shell now (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    exec sh
  fi
  unset key
  printf "\r                                                                 "
  printf "\rCONFIG: init: add extra init path (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    printf "init path: "
    read CONFIGPATH
    CONFIGPATHSET="true"
  fi
  unset key
  printf "\rCONFIG: user: delete root password (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    CONFIGDELROOTPASSWD="true"
  fi
else
  printf "\r                                                                            \r"
fi
mkdir -p /mnt/sfs /mnt/rw /mnt/rw/upper /mnt/rw/work /mnt/newroot
mount -t squashfs /boot.sfs /mnt/sfs
mount -t overlay overlay \
  -o lowerdir=/mnt/sfs,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work \
  /mnt/newroot
mkdir -p /mnt/newroot/proc /mnt/newroot/sys /mnt/newroot/dev
mount -t proc proc /mnt/newroot/proc
mount -t sysfs sys /mnt/newroot/sys
mount -t devtmpfs dev /mnt/newroot/dev
echo "<0>sfsboot.loader: filesystems mounted at target">&5

if $CONFIGDELROOTPASSWD; then
  echo "<0>sfsboot.loader: deleted root password">&5
  chroot /mnt passwd -d root
fi

echo "<0>sfsboot.loader: ready">&5

if $CONFIGPATHSET; then
  echo "<0>sfsboot.loader: searching for init $CONFIGPATH">&5
  [ -f /mnt/newroot/init ] && exec chroot /mnt/newroot/ "$CONFIGPATH"
fi
echo "<0>sfsboot.loader: searching for init /init">&5
[ -f /mnt/newroot/init ] && exec chroot /mnt/newroot/ /init
echo "<0>sfsboot.loader: searching for init /linuxrc">&5
[ -f /mnt/newroot/linuxrc ] && exec chroot /mnt/newroot/ /linuxrc
echo "<0>sfsboot.loader: searching for init /sbin/init">&5
[ -f /mnt/newroot/sbin/init ] && exec chroot /mnt/newroot/ /sbin/init
echo "<0>sfsboot.loader: searching for init /bin/init">&5
[ -f /mnt/newroot/bin/init ] && exec chroot /mnt/newroot/ /bin/init
echo "<0>sfsboot.loader: could not find init">&5

echo "ERROR: No valid init found. Type path or Ctrl+D to drop to a shell."

if ! read nextsteps; then echo "Good luck"; exec sh; fi
[ "${nextsteps#/}" = "$nextsteps" ] && nextsteps="/$nextsteps"
[ -f "/mnt$nextsteps" ] && exec chroot /mnt "$nextsteps"
[ "$nextsteps" = "proper" ] && exec init
echo "ERROR: not valid, dropping to sfsboot pid 1 shell."
echo "Good luck"
exec sh
