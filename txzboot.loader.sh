#!/bin/sh
export PATH="/bin"
exec </dev/console >/dev/console 2>&1

mkdir -p /proc /sys /dev /mnt

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
exec 5>/dev/kmsg
echo "<0>txzboot.loader: loading">&5
echo "txzboot">/proc/sys/kernel/hostname
echo "<0>txzboot.loader: set hostname to 'txzboot'">&5
echo "<0>txzboot.loader: core filesystems mounted">&5

if ! [ -f /boot.txz ] && ! [ -f /boot.tgz ] && ! [ -f /boot.tar ]; then
  echo "<0>txzboot.loader: no boot.txz/tgz/tar found, dropping to shell">&5
  exec sh
fi
printf "Press c within 5 seconds to configure, or press any other key to skip\r"
CONFIG1SHELL="false"
CONFIGSHELL="false"
CONFIGPATH=""
CONFIGPATHSET="false"
CONFIGTARPROGRESS="false"
CONFIGNORAMFS="false"
CONFIGDELROOTPASSWD="false"
read -t 5 -n 1 key 2>/dev/null
if [ "$key" = "c" ]; then
  unset key
  printf "\r                                                                          "
  printf "\rCONFIG: debug: exec [pid 1] shell now (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    exec sh
  fi
  unset key
  printf "\rCONFIG: debug: exec [pid 1] shell after tar (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    CONFIG1SHELL="true"
  else
    unset key
    printf "\rCONFIG: debug: run regular shell after tar (not pid 1) (y/n): "
    read -n 1 key 2>/dev/null
    if [ "$key" = "y" ]; then
      CONFIGSHELL="true"
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
    printf "\r                                            \r"
  fi
  unset key
  printf "\rCONFIG: tar: show untar progress (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    CONFIGTARPROGRESS="true"
  fi
  printf "\r                                         \r"
  printf "\rCONFIG: fs: don't use ramfs (y/n): "
  read -n 1 key 2>/dev/null
  if [ "$key" = "y" ]; then
    CONFIGNORAMFS="true"
  fi
  printf "\r                                         \r"
else
  printf "\r                                                                            \r"
fi
TAREXT="tar"
if [ -f "/boot.txz" ]; then
  TARFLAG="J"
  TAREXT="txz"
elif [ -f "/boot.tgz" ]; then
  TARFLAG="z"
  TAREXT="tgz"
fi
if ! $CONFIGNORAMFS; then
  mount -t ramfs ramfs /mnt
fi
mkdir /mnt/proc /mnt/sys /mnt/dev
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -t devtmpfs dev /mnt/dev
echo "<0>txzboot.loader: core filesystems mounted at target">&5
echo "<0>txzboot.loader: starting untar">&5
if $CONFIGTARPROGRESS; then
  tar "-vx${TARFLAG}f" "/boot.${TAREXT}" -C /mnt
else
  tar "-x${TARFLAG}f" "/boot.${TAREXT}" -C /mnt
fi
echo "<0>txzboot.loader: done untar">&5
if $CONFIG1SHELL; then
  exec sh
elif $CONFIGSHELL; then
  sh
fi

if $CONFIGDELROOTPASSWD; then
  echo "<0>txzboot.loader: deleted root password">&5
  chroot /mnt passwd -d root
fi

echo "<0>txzboot.loader: ready">&5

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
