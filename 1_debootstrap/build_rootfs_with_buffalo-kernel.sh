#!/bin/bash

# Purpose:
#	To install Debian Squeeze on Linkstation with Buffalo's stock kernel
#	(the stock kernel could be / intent to be replaced later)
# Usage:
#	Place this script in /mnt/array1/share or /mnt/disk1/share, then run it
# Dependency:
#	Need to obtain ssh access first
# Credit:
#	http://buffalo.nas-central.org/wiki/Debian_Squeeze_on_LS-WXL
#	http://buffalo.nas-central.org/wiki/Initrd_for_Raid-Boot


SCRIPT_ROOT=$(readlink -f $(dirname $0))
SRC_ROOT=$(readlink -f $(dirname $0)/..)

. $SCRIPT_ROOT/config
. $SRC_ROOT/lib/config_apt
. $SRC_ROOT/lib/shell_lib

if [ -z "$1" ]; then

echo Start datetime: `date`
echo 1st stage: debootstrap

InitVal

mkdir -p $TARGET/etc/default/ $TARGET/etc/apt/ $TARGET/etc/ssh/ $TARGET/lib/modules/
echo $NEWHOST > $TARGET/etc/hostname
echo en_US.UTF-8 UTF-8 > $TARGET/etc/locale.gen
echo LANG=en_US.UTF-8 > $TARGET/etc/default/locale
cp -a /etc/localtime $TARGET/etc/
if [ -d /etc/ssh/ ]; then
cp -a /etc/ssh/ssh_host_{dsa,rsa,key,ecdsa}* $TARGET/etc/ssh/ &> /dev/null
else
cp -a /etc/ssh_host_{dsa,rsa,key,ecdsa}* $TARGET/etc/ssh/ &> /dev/null
fi
chmod 400 $TARGET/etc/ssh/ssh_host_{dsa,rsa,ecdsa}_key $TARGET/etc/ssh/ssh_host_key &> /dev/null
chmod 444 $TARGET/etc/ssh/ssh_host_{dsa,rsa,ecdsa}_key.pub $TARGET/etc/ssh/ssh_host_key.pub &> /dev/null
rsync -a /lib/modules/`uname -r` $TARGET/lib/modules/

[ ! -d /tmp ] && if [ -d /mnt/ram ]; then
	ln -s /mnt/ram /tmp
else
	ln -s $SRC_ROOT /tmp
fi
wget -nv -O /tmp/$DEBOOTSTRAP_DEB $MIRROR$DEBOOTSTRAP_PATH/$DEBOOTSTRAP_DEB
dpkg -i $DPKG_DEBOOTSTRAP_OPT /tmp/$DEBOOTSTRAP_DEB
rm /tmp/$DEBOOTSTRAP_DEB
[ $ARRAY -eq 1 ] && DEB_INCLUDE=${DEB_INCLUDE},mdadm
[ $(GetFS $TARGET_DEV) = "xfs" ] && DEB_INCLUDE=${DEB_INCLUDE},xfsprogs
[ $(GetFS $TARGET_DEV) = "jfs" ] && DEB_INCLUDE=${DEB_INCLUDE},jfsutils

echo $DEBOOTSTRAP --arch=armel $DEBOOTSTRAP_OPT --exclude=$DEB_EXCLUDE --include=$DEB_INCLUDE $DISTRO $TARGET $MIRROR
$DEBOOTSTRAP --arch=armel $DEBOOTSTRAP_OPT --exclude=$DEB_EXCLUDE --include=$DEB_INCLUDE $DISTRO $TARGET $MIRROR
dpkg -r $DEBOOTSTRAP

cat << EOT > $TARGET/etc/apt/sources.list
deb $MIRROR $DISTRO main contrib non-free
deb $MIRROR ${DISTRO}-updates main contrib non-free
deb $MIRROR ${DISTRO}-backports main contrib non-free
deb http://security.debian.org $DISTRO/updates main contrib non-free
EOT
# TODO: only this kernel boots well now..
[ $DISTRO = "wheezy" ] && echo "deb http://snapshot.debian.org/archive/debian/20141214T100745Z/ wheezy-backports main" >> $TARGET/etc/apt/sources.list
[ $DISTRO = "jessie" ] && echo "deb http://snapshot.debian.org/archive/debian/20141104T041106Z/ jessie main" >> $TARGET/etc/apt/sources.list
CreateFstab $STOCK_KERNEL
cat << EOT > $TARGET/etc/network/interfaces
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
#auto eth1
#iface eth1 inet dhcp
EOT

#dd if=/boot/initrd.buffalo of=$TARGET/tmp/initrd.gz ibs=64 skip=1
cp -a $SRC_ROOT $TARGET
echo Chroot datetime: `date`
mount --bind /dev $TARGET/dev
echo LANG=C chroot $TARGET /$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0) chrooted $ARRAY
LANG=C chroot $TARGET /$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0) chrooted $ARRAY
[ $? -gt 0 ] && exit 0
umount $TARGET/dev
cd $TARGET
echo tar cf ../rootfs.tar .
tar cf ../rootfs.tar .
echo move all files under $TARGET to real root \($(readlink -f $TARGET/..)\)
echo mv $TARGET/\* $(readlink -f $TARGET/..)/\; rm -r $TARGET/
mv $TARGET/* `readlink -f $TARGET/..`/
rmdir $TARGET
echo End datetime: `date`

elif [ "$1" = "chrooted" ]; then

echo 2nd stage: CHROOT: build initrd image to boot from temp device

mount -t proc proc /proc
#(cd /dev/; [ -d .udev ] && mv .udev .oldudev; MAKEDEV sd{a,b,c,d} md; [ -d .oldudev ] && mv .oldudev .udev)
mount -t sysfs sysfs /sys
mount -t devpts devpts /dev/pts
mount $BOOT_DEV /boot || (mount -o ro $BOOT_DEV /boot; mount -o remount,rw /boot)
echo df -h; df -h

InitVal

echo "echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd"
echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd
[ $DISTRO = "jessie" ] && sed -i '/PermitRootLogin/s/without-password/yes/' /etc/ssh/sshd_config
echo '/dev/mtd2 0x00000 0x10000 0x10000' >> /etc/fw_env.config
#sed -i 's/exit 0/rmmod ehci_orion ehci_hcd usbcore usb_common md_mod\nrmmod hmac sha1_generic sha1_arm mv_cesa\nrmmod netconsole configfs\n\n&/' /etc/rc.local
echo "PATH=\$PATH:~/bin" >> /root/.bashrc
if [ $DISTRO = "squeeze" ]; then
sed -i 's/^UTC=yes/UTC=no/' /etc/default/rcS
elif [ $DISTRO = "wheezy" ]; then
echo -e "0.0 0 0.0\n0\nLOCAL" > /etc/adjtime
fi
sed -i 's/^#FSCKFIX=no/&\nFSCKFIX=yes/' /etc/default/rcS
[ "x$DEBOOTSTRAP" = "xcdebootstrap-static" ] && dpkg -r cdebootstrap-helper-rc.d
echo 'Acquire::CompressionTypes::Order { "gz"; "bzip2"; "lzma"; };' >> /etc/apt/apt.conf.d/80-roger.conf
apt-get $APT_OPT update
apt-get dist-upgrade -y
if [ $(GetFS $TARGET_DEV) = "btrfs" ]; then
	[ $DISTRO = "wheezy" ] && DEB_BPO="${DEB_BPO} btrfs-tools"
	[ $DISTRO = "jessie" ] && DEB_ADD="${DEB_ADD} btrfs-tools"
fi
[ -n "$DEB_BPO" ] && apt-get install -y --no-install-recommends -t ${DISTRO}-backports $DEB_BPO
[ -n "$DEB_ADD" ] && apt-get install -y --no-install-recommends $DEB_ADD
apt-get clean

if [ -f /etc/inittab ]; then
	sed -i 's/^1:2345:respawn:/#1:2345:respawn:/' /etc/inittab
	sed -i 's/^2:23:respawn:/#2:23:respawn:/' /etc/inittab
	sed -i 's/^3:23:respawn:/#3:23:respawn:/' /etc/inittab
	sed -i 's/^4:23:respawn:/#4:23:respawn:/' /etc/inittab
	sed -i 's/^5:23:respawn:/#5:23:respawn:/' /etc/inittab
	sed -i 's/^6:23:respawn:/#6:23:respawn:/' /etc/inittab
	echo "T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100" >> /etc/inittab
fi
echo 'blacklist ipv6' > /etc/modprobe.d/blacklist_local.conf
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"' > /etc/udev/rules.d/80-local.rules
cp -a /usr/share/initramfs-tools/init /usr/share/initramfs-tools/init.orig
sed -i 's:exec >/run/initramfs/initramfs.debug 2>&1:exec >/dev/kmsg 2>\&1\t# &:' /usr/share/initramfs-tools/init
sed -i 's:for x in \$(cat /proc/cmdline):& Debug:' /usr/share/initramfs-tools/init
sed -i 's/^MODULES=most/MODULES=list/' /etc/initramfs-tools/initramfs.conf
sed -i 's/^BUSYBOX=y/BUSYBOX=n/' /etc/initramfs-tools/initramfs.conf

cat << EOT >> /etc/initramfs-tools/modules
mv643xx_eth
netconsole netconsole=@192.168.11.150/,6666@192.168.11.1/
mvmdio
sata_mv
sd_mod
$(GetFS $TARGET_DEV)
EOT
[ $ARRAY -eq 1 ] && echo raid1 >> /etc/initramfs-tools/modules
[ "x$(GetFS $TARGET_DEV)" = "xbtrfs" ] && echo crc32c >> /etc/initramfs-tools/modules

mkdir -p /root/bin
cp -a $SCRIPT_ROOT/scripts/*.sh /root/bin
cp -a $SCRIPT_ROOT/dtb /boot/
cp -a $SCRIPT_ROOT/scripts/initramfs-tools_hooks_set_root /etc/initramfs-tools/hooks/set_root
cat << EOT >> /etc/initramfs-tools/hooks/set_root
#echo "ROOT=/dev/disk/by-uuid/$(GetUUID $TARGET_DEV)" >> \$DESTDIR/conf/param.conf
echo "ROOT=$RUN_ROOT" >> \$DESTDIR/conf/param.conf
EOT
[ $(GetFS $TARGET_DEV) = "xfs" -o $(GetFS $TARGET_DEV) = "jfs" -o $(GetFS $TARGET_DEV) = "ext4" ] && echo "#echo \"ROOTFLAGS='-o discard'\" >> \$DESTDIR/conf/param.conf" >> /etc/initramfs-tools/hooks/set_root
[ $(GetFS $TARGET_DEV) = "btrfs" ] && echo "#echo \"ROOTFLAGS='-o ssd'\" >> \$DESTDIR/conf/param.conf" >> /etc/initramfs-tools/hooks/set_root
echo "exit 0" >> /etc/initramfs-tools/hooks/set_root

(cd /boot; [ -f initrd.buffalo -a ! -h initrd.buffalo ] && mv initrd.buffalo initrd.buffalo_orig;
[ -f uImage.buffalo -a ! -h uImage.buffalo ] && mv uImage.buffalo uImage.buffalo_orig)
if [ $STOCK_KERNEL -eq 0 ]; then
	update-initramfs -uk all
	/root/bin/kernel.sh 1
else
	#CreateInitrd $INITRD_ROOT_DEV /boot/initrd.buffalo_debian_$(echo $INITRD_ROOT_DEV |cut -dx -f2) 1
	CreateInitrd $TARGET_DEV /boot/initrd.buffalo_debian_$(basename $TARGET_DEV) 1
fi

umount /boot
umount /dev/pts
umount /sys
umount /proc

elif [ "$1" = "debian" ]; then

echo 3rd stage: Build Debian rootfs on final target device

InitVal

TARGET=/mnt
TARGET_DEV=/dev/sda2
MNT_DEV=/dev/sda6
if [ $ARRAY -eq 1 ]; then
TARGET_DEV=/dev/md1
if [ -e /dev/md21 ]; then
MNT_DEV=/dev/md21
else
MNT_DEV=/dev/md2
fi
fi

echo ARRAY=$ARRAY TARGET=$TARGET TARGET_DEVICE=$TARGET_DEV

if [ -f /rootfs.tar ]; then
	ARG=xf;  TAR=/rootfs.tar
elif [ -f /rootfs.tar.gz ]; then
	ARG=xfz; TAR=/rootfs.tar.gz
elif [ -f /rootfs.tar.bz2 ]; then
	ARG=xfj; TAR=/rootfs.tar.bz2
elif [ -f /rootfs.tar.xz ]; then
	ARG=xfJ; TAR=/rootfs.tar.xz
else
	echo cannot find rootfs tarball.
	exit
fi

(cd $TARGET
if [ ! -d stock_rootfs_backup ]; then
	echo mkdir stock_rootfs_backup
	mkdir stock_rootfs_backup
	echo mv .\* \* stock_rootfs_backup/
	mv .* * stock_rootfs_backup/
fi
echo tar $ARG $TAR
tar $ARG $TAR)

CreateFstab $STOCK_KERNEL
mount -o remount,rw /boot
initrd_bak=initrd.buffalo_debian_tmp-`basename $MNT_DEV`
(cd /boot; [ -f $initrd_bak ] && rm $initrd_bak;
[ -f initrd.buffalo_debian ] && mv initrd.buffalo_debian $initrd_bak)
[ $STOCK_KERNEL -eq 1 ] && CreateInitrd $TARGET_DEV /boot/initrd.buffalo_debian_$(basename $TARGET_DEV) 1
mount -o remount,ro /boot

fi
