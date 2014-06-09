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

ROOTPW=password
DISTRO=squeeze
NEWHOST=LS-Squeeze

MIRROR=http://ftp.jp.debian.org/debian
TARGET=/mnt/disk1/rootfs
TARGET_DEV=/dev/sda6
BOOT_DEV=/dev/sda1
MNT_DEV=/dev/sda2
SWAP_DEV=/dev/sda5
INITRD_ROOT_DEV=0x806

ARRAY=0	# condition intended to be so complex due to fit various cases: 1st run / 2nd run in chroot w/ or w/o RAID
[ "x$2" != "x0" -a "x$2" = "x1" ] && ARRAY=1
[ $ARRAY -eq 0 ] && [ -f /proc/mdstat ] && [ `wc -l /proc/mdstat | awk '{print $1}'` -gt 2 ] && ARRAY=1
if [ $ARRAY -eq 1 ]; then
TARGET=/mnt/array1/rootfs
TARGET_DEV=/dev/md2
BOOT_DEV=/dev/md0
MNT_DEV=/dev/md1
SWAP_DEV=/dev/md10
INITRD_ROOT_DEV=0x902	# 0x806:sda6; 0x822:sdb6; 0x901:md1; 0x902:md2;
fi

# package detail can be found on: https://packages.debian.org/squeeze/all/debootstrap/download
DEBOOTSTRAP_PATH=/pool/main/d/debootstrap
if [ $DISTRO = "squeeze" ]; then
DEBOOTSTRAP_DEB=debootstrap_1.0.26+squeeze1_all.deb
DEB_INCLUDE=uboot-mkimage,uboot-envtools
elif [ $DISTRO = "wheezy" ]; then
DEBOOTSTRAP_DEB=debootstrap_1.0.48+deb7u1_all.deb
DEB_INCLUDE=u-boot-tools
fi
DEB_EXCLUDE=aptitude,tasksel,tasksel-data,vim-tiny
DEB_INCLUDE=${DEB_INCLUDE},makedev,jfsutils,xfsprogs,ssh,nfs-common,vim-nox,locales,screen,less,hddtemp,smartmontools,rsync,file,mdadm,dialog,busybox


CreateFstab() {
FS1=$1		# $1 is the FS type for $TARGET_DEV
FS2=$2		# $2 is the FS type for $MNT_DEV
[ -z $1 ] && FS1=xfs
[ -z $2 ] && FS2=xfs
cat << EOT > $TARGET/etc/fstab
# dev_file	mount point	type	options		dump pass
$TARGET_DEV	/		$FS1	noatime		0    1
$BOOT_DEV	/boot		ext3	ro,relatime,errors=continue 0    2
$SWAP_DEV	none		swap	sw		0    0
proc		/proc		proc	defaults	0    0
$MNT_DEV	/mnt		$FS2	noatime		0    2
EOT
}

CreateInitrd() {
cd /tmp
dd if=/dev/zero of=initrd bs=1k count=0 seek=3K
mke2fs -F -m 0 -b 1024 initrd
tune2fs -c0 -i0 initrd
mkdir INITRD
mount -o loop initrd INITRD
mkdir -p INITRD/{bin,lib,sbin,proc}
cp -aL /bin/busybox INITRD/bin/
cp -aL /sbin/pivot_root INITRD/sbin/
if [ $ARRAY -eq 1 ]; then
mkdir -p INITRD/{dev,etc/mdadm}
(cd INITRD/dev/; MAKEDEV sd{a,b,c,d} md)
cp -aL /sbin/mdadm INITRD/sbin/
fi
libs2install=$( ldd INITRD/*bin/* | grep -v "^INITRD/" | sed -e 's/.*=> *//'  -e 's/ *(.*//' | sort -u )
echo cp -aL $libs2install INITRD/lib/
cp -aL $libs2install INITRD/lib/
(cd INITRD/bin; ln -s busybox sh)
if [ $ARRAY -eq 0 ]; then
cat << EOT > INITRD/linuxrc
#!/bin/sh
mount -t proc none /proc
echo $INITRD_ROOT_DEV > /proc/sys/kernel/real-root-dev
umount /proc
EOT
elif [ $ARRAY -eq 1 ]; then
cat << EOT > INITRD/linuxrc
#!/bin/sh
mount -t proc none /proc
echo 'DEVICE /dev/sd??*' > /etc/mdadm/mdadm.conf
mdadm -Eb /dev/sd[abcd]* >> /etc/mdadm/mdadm.conf
mdadm -As --force
echo $INITRD_ROOT_DEV > /proc/sys/kernel/real-root-dev
umount /proc
EOT
fi
chmod 755 INITRD/linuxrc
umount INITRD
rmdir INITRD
echo gzip -9 initrd
gzip -9 initrd
mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 -n initrd -d initrd.gz /boot/initrd.buffalo_debian
rm initrd.gz
(cd /boot; if [ ! -e initrd.buffalo -o -h initrd.buffalo ]; then
	echo ln -sf initrd.buffalo_debian initrd.buffalo
	ln -sf initrd.buffalo_debian initrd.buffalo
	echo ls -l /boot/initrd.buffalo\*
	ls -l /boot/initrd.buffalo*
fi)
}


if [ -z "$1" ]; then

echo Start datetime: `date`
echo 1st stage: debootstrap

mkdir -p $TARGET/etc/default/ $TARGET/etc/apt/ $TARGET/etc/ssh/ $TARGET/lib/modules/
echo $NEWHOST > $TARGET/etc/hostname
echo en_US.UTF-8 UTF-8 > $TARGET/etc/locale.gen
echo LANG=en_US.UTF-8 > $TARGET/etc/default/locale
cp -a /etc/localtime $TARGET/etc/
echo -e "0.0 0 0.0\n0\nLOCAL" > $TARGET/etc/adjtime
cp -a /etc/ssh_host_{dsa,rsa}* $TARGET/etc/ssh/
chmod 400 $TARGET/etc/ssh/ssh_host_{dsa,rsa}_key
chmod 444 $TARGET/etc/ssh/ssh_host_{dsa,rsa}_key.pub
rsync -a /lib/modules/`uname -r` $TARGET/lib/modules/

wget -nv -O /tmp/$DEBOOTSTRAP_DEB $MIRROR$DEBOOTSTRAP_PATH/$DEBOOTSTRAP_DEB
dpkg -i /tmp/$DEBOOTSTRAP_DEB
rm /tmp/$DEBOOTSTRAP_DEB
debootstrap --arch=armel --exclude=aptitude,tasksel,tasksel-data,vim-tiny --include=makedev,jfsutils,xfsprogs,ssh,nfs-common,vim-nox,locales,screen,less,hddtemp,smartmontools,rsync,file,uboot-mkimage,uboot-envtools,mdadm,dialog,busybox $DISTRO $TARGET $MIRROR
dpkg -r debootstrap

cat << EOT > $TARGET/etc/apt/sources.list
deb $MIRROR squeeze main contrib non-free
deb http://security.debian.org squeeze/updates main contrib non-free
EOT
CreateFstab xfs ext3
cat << EOT > $TARGET/etc/network/interfaces
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
auto eth1
iface eth1 inet dhcp
EOT

cp `basename $0` $TARGET
echo Chroot datetime: `date`
LANG=C chroot $TARGET /`basename $0` chrooted $ARRAY
cd $TARGET
echo tar cf ../rootfs.tar .
tar cf ../rootfs.tar .
echo move all files under $TARGET to real root \(`readlink -f $TARGET/..`\)
echo mv $TARGET/\* `readlink -f $TARGET/..`/\; rm -r $TARGET/
mv $TARGET/* `readlink -f $TARGET/..`/
rmdir $TARGET
echo End datetime: `date`

elif [ "$1" = "chrooted" ]; then

echo 2nd stage: CHROOT: build initrd image to boot from temp device

mount -t proc proc /proc
(cd /dev/; [ -d .udev ] && mv .udev .oldudev; MAKEDEV sd{a,b,c,d} md; [ -d .oldudev ] && mv .oldudev .udev)
mount -t sysfs sysfs /sys
mount -t devpts devpts /dev/pts
mount $BOOT_DEV /boot
echo "echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd"
echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd
sed -i 's/^1:2345:respawn:/#1:2345:respawn:/' /etc/inittab
sed -i 's/^2:23:respawn:/#2:23:respawn:/' /etc/inittab
sed -i 's/^3:23:respawn:/#3:23:respawn:/' /etc/inittab
sed -i 's/^4:23:respawn:/#4:23:respawn:/' /etc/inittab
sed -i 's/^5:23:respawn:/#5:23:respawn:/' /etc/inittab
sed -i 's/^6:23:respawn:/#6:23:respawn:/' /etc/inittab
echo "T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100" >> /etc/inittab
depmod -a `uname -r`
apt-get update
apt-get dist-upgrade -y
apt-get clean

(cd /boot; [ -f initrd.buffalo -a ! -h initrd.buffalo ] && mv initrd.buffalo initrd.buffalo_orig)
CreateInitrd

umount /boot
umount /dev/pts
umount /sys
umount /proc

elif [ "$1" = "debian" ]; then

echo 3rd stage: Build Debian rootfs on final target device

TARGET=/mnt
TARGET_DEV=/dev/sda2
MNT_DEV=/dev/sda6
INITRD_ROOT_DEV=0x802
if [ $ARRAY -eq 1 ]; then
TARGET_DEV=/dev/md1
MNT_DEV=/dev/md2
INITRD_ROOT_DEV=0x901	# 0x806:sda6; 0x822:sdb6; 0x901:md1; 0x902:md2;
fi

echo ARRAY=$ARRAY TARGET=$TARGET TARGET_DEVICE=$TARGET_DEV INITRD_ROOT_DEVICE=$INITRD_ROOT_DEV

(cd $TARGET
if [ ! -d stock_rootfs_backup ]; then
	echo mkdir stock_rootfs_backup
	mkdir stock_rootfs_backup
	echo mv .\* \* stock_rootfs_backup/
	mv .* * stock_rootfs_backup/
fi
echo tar xf /rootfs.tar
tar xf /rootfs.tar)

CreateFstab ext3 xfs
mount -o remount,rw /boot
initrd_bak=initrd.buffalo_debian_tmp-`basename $MNT_DEV`
(cd /boot; [ -f $initrd_bak ] && rm $initrd_bak;
[ -f initrd.buffalo_debian ] && mv initrd.buffalo_debian $initrd_bak)
CreateInitrd
mount -o remount,ro /boot

fi
