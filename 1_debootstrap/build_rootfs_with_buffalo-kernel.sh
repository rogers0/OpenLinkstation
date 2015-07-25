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
[ -z "$1" ] && STAGE=0
[ "x$1" = "xchrooted" ] && STAGE=1
[ "x$1" = "xdebian" ] && STAGE=2

. $SRC_ROOT/lib/config
. $SRC_ROOT/lib/shell_lib

if [ $STAGE -eq 0 ]; then

echo Start datetime: `date`
echo 1st stage: debootstrap

InitVal

if [ -z "$TARGET_DEV" ]; then
	echo Error: no TARGET_DEV is specified.
	echo Please mount the device your want to create rootfs on \"/mnt\".
	exit 1
fi

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
[ $BUFFALO_KERNEL -eq 1 ] && DEB_INCLUDE=${DEB_INCLUDE},makedev,busybox
if [ $DISTRO = "jessie" ]; then
	# dirty hack for Jessie. because there's no xz uncompression support on linkstation, but Jessie's deb is packed by xz
	mkdir /tmp/cdebootstrap; cd $_
	tar xfz $SCRIPT_ROOT/lib/cdebootstrap*_${DEB_ARCH}.tar.gz
	DEBOOTSTRAP=./cdebootstrap
else
	wget -nv -O /tmp/$DEBOOTSTRAP_DEB $MIRROR$DEBOOTSTRAP_PATH/$DEBOOTSTRAP_DEB
	dpkg -i $DPKG_DEBOOTSTRAP_OPT /tmp/$DEBOOTSTRAP_DEB
	rm /tmp/$DEBOOTSTRAP_DEB
fi

echo $DEBOOTSTRAP --arch=$DEB_ARCH $DEBOOTSTRAP_OPT --exclude=$DEB_EXCLUDE --include=$DEB_INCLUDE $DISTRO $TARGET $MIRROR
$DEBOOTSTRAP --arch=$DEB_ARCH $DEBOOTSTRAP_OPT --exclude=$DEB_EXCLUDE --include=$DEB_INCLUDE $DISTRO $TARGET $MIRROR
RET=$?
if [ $DISTRO = "jessie" ]; then
	cd -
	rm -rf /tmp/cdebootstrap
else
	dpkg -r $DEBOOTSTRAP
fi
[ $RET -gt 0 ] && echo DEBOOTSTRAP failed. && exit 1

cat << EOT > $TARGET/etc/apt/sources.list
deb $MIRROR $DISTRO main contrib non-free
deb $MIRROR ${DISTRO}-updates main contrib non-free
deb $MIRROR ${DISTRO}-backports main contrib non-free
deb http://security.debian.org $DISTRO/updates main contrib non-free
EOT
CreateFstab $noUUID
cat << EOT > $TARGET/etc/network/interfaces
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOT
[ $BUFFALO_KERNEL -eq 1 ] && echo -e auto eth1\\niface eth1 inet dhcp >> $TARGET/etc/network/interfaces
if [ -n "$MACHINE_ID" ]; then
	mkdir -p $TARGET/etc/flash-kernel/
	cd $_;
	cp -a $SCRIPT_ROOT/dtb .
	cp -a $SCRIPT_ROOT/flash-kernel/db.linkstation .
	ln -sf db.linkstation db
	echo $MACHINE_ID > machine
	echo $DEB_KERNEL > kernel-image
	cd -
fi
echo $TARGET_DEV > $TARGET/target_dev

#dd if=/boot/initrd.buffalo of=$TARGET/tmp/initrd.gz ibs=64 skip=1
cp -a $SRC_ROOT $TARGET
echo Chroot datetime: `date`
ChrootPrepare $TARGET $BOOT_DEV
LANG=C chroot $TARGET df -h
echo LANG=C chroot $TARGET /$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0) chrooted
LANG=C chroot $TARGET /$(basename $SRC_ROOT)/$(basename $SCRIPT_ROOT)/$(basename $0) chrooted
RET=$?
ChrootEnd $TARGET
[ $RET -gt 0 ] && exit 0
cd $TARGET
echo tar cf ../rootfs.tar .
tar cf ../rootfs.tar .
echo move all files under $TARGET to real root \($(readlink -f $TARGET/..)\)
echo mv $TARGET/\* $(readlink -f $TARGET/..)/\; rm -r $TARGET/
mv $TARGET/* `readlink -f $TARGET/..`/
rmdir $TARGET
echo End datetime: `date`

elif [ $STAGE -eq 1 ]; then

echo 2nd stage: CHROOT: build initrd image to boot from temp device

#(cd /dev/; [ -d .udev ] && mv .udev .oldudev; MAKEDEV sd{a,b,c,d} md; [ -d .oldudev ] && mv .oldudev .udev)

InitVal

echo "echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd"
echo -e ${ROOTPW}\\n${ROOTPW}\\n|passwd
echo '/dev/mtd2 0x00000 0x10000 0x10000' >> /etc/fw_env.config
#sed -i 's/exit 0/rmmod ehci_orion ehci_hcd usbcore usb_common md_mod\nrmmod hmac sha1_generic sha1_arm mv_cesa\nrmmod netconsole configfs\n\n&/' /etc/rc.local
cat << EOT >> /root/.bashrc
PATH=\$PATH:~/bin
alias du='du -h --max-depth=1'
alias auu='apt-get update && apt-get upgrade && apt-get clean'
EOT

if [ $DISTRO = "squeeze" ]; then
sed -i 's/^UTC=yes/UTC=no/' /etc/default/rcS
elif [ $DISTRO = "wheezy" ]; then
echo -e "0.0 0 0.0\n0\nLOCAL" > /etc/adjtime
fi
sed -i 's/^#FSCKFIX=no/&\nFSCKFIX=yes/' /etc/default/rcS
echo 'Acquire::CompressionTypes::Order { "gz"; "bzip2"; "lzma"; };' >> /etc/apt/apt.conf.d/80-roger.conf
apt-get $APT_OPT update
[ $ARRAY -eq 1 ] && DEB_ADD="$DEB_ADD mdadm"
[ "$(GetFS $TARGET_DEV)" = "xfs" ] && DEB_ADD="$DEB_ADD xfsprogs"
[ "$(GetFS $TARGET_DEV)" = "jfs" ] && DEB_ADD="$DEB_ADD jfsutils"
if [ "$(GetFS $TARGET_DEV)" = "btrfs" ]; then
	[ $DISTRO = "wheezy" ] && DEB_BPO="${DEB_BPO} btrfs-tools"
	[ $DISTRO = "jessie" ] && DEB_ADD="${DEB_ADD} btrfs-tools"
fi
if [ -n "$MACHINE_ID" ]; then
	[ $DISTRO = "wheezy" ] && DEB_BPO="${DEB_BPO} flash-kernel $DEB_KERNEL"
	[ $DISTRO = "jessie" ] && DEB_ADD="${DEB_ADD} flash-kernel $DEB_KERNEL"
fi
[ -n "$DEB_BPO" ] && apt-get install -y --no-install-recommends -t ${DISTRO}-backports $DEB_BPO
[ -n "$DEB_ADD" ] && apt-get install -y --no-install-recommends $DEB_ADD
if [ -n "$MACHINE_ID" ]; then
	kernel=$(dpkg -l |grep linux-image|head -n1|cut -d" " -f3)
	[ -n "$kernel" -a -d /usr/lib/$kernel ] && ln -sf /etc/flash-kernel/dtb/*.dtb /usr/lib/$kernel/
	rm -f /etc/flash-kernel/kernel-image
fi
rm -f /target_dev

[ $DISTRO = "jessie" ] && sed -i '/PermitRootLogin/s/without-password/yes/' /etc/ssh/sshd_config
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
if [ $BUFFALO_KERNEL -eq 0 ]; then
	cp -a /usr/share/initramfs-tools/init /usr/share/initramfs-tools/init.orig
	sed -i 's:exec >/run/initramfs/initramfs.debug 2>&1:exec >/dev/kmsg 2>\&1\t# &:' /usr/share/initramfs-tools/init
	sed -i 's:for x in \$(cat /proc/cmdline):& Debug:' /usr/share/initramfs-tools/init
	sed -i 's/^MODULES=most/MODULES=list/' /etc/initramfs-tools/initramfs.conf
	sed -i 's/^BUSYBOX=y/BUSYBOX=n/' /etc/initramfs-tools/initramfs.conf
	CreateInitramfsModule "" $TARGET_DEV $ARRAY
	CreateInitramfsHook $SCRIPT_ROOT "" $TARGET_DEV $RUN_ROOT $noUUID
fi

mkdir -p /root/bin
cp -a $SCRIPT_ROOT/scripts/*.sh /root/bin
apt-get dist-upgrade -y
[ -n "$DEB_DEL" ] && apt-get purge -y $DEB_DEL
apt-get clean

(cd /boot; [ -f initrd.buffalo -a ! -h initrd.buffalo ] && mv initrd.buffalo initrd.buffalo_orig;
[ -f uImage.buffalo -a ! -h uImage.buffalo ] && mv uImage.buffalo uImage.buffalo_orig)
ls -l /boot/uImage.buffalo /boot/initrd.buffalo
if [ $BUFFALO_KERNEL -eq 0 ]; then
	#update-initramfs -uk all
	if [ -e /boot/uImage.flash-kernel ]; then
		(cd /boot/;
		echo ln -sf uImage.flash-kernel uImage.buffalo;
		ln -sf uImage.flash-kernel uImage.buffalo;
		echo ln -sf initrd.flash-kernel initrd.buffalo;
		ln -sf initrd.flash-kernel initrd.buffalo)
	fi
else
	#CreateInitrd $INITRD_ROOT_DEV /boot/initrd.buffalo_debian_$(echo $INITRD_ROOT_DEV |cut -dx -f2) 1
	CreateInitrd $TARGET_DEV /boot/initrd.buffalo_debian_$(basename $TARGET_DEV) 1
	if [ ! -h /boot/uImage.buffalo ]; then
		(cd /boot/;
		echo ln -s uImage.buffalo_orig uImage.buffalo;
		ln -s uImage.buffalo_orig uImage.buffalo)
	fi
fi
ls -l /boot/uImage.buffalo /boot/initrd.buffalo

elif [ $STAGE -eq 2 ]; then

echo 3rd stage: Build Debian rootfs on final target device

InitVal

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
	exit 1
fi

(cd $TARGET
old_fs_backup="old_fs_backup"
if [ ! -d $old_fs_backup ]; then
	echo mkdir $old_fs_backup
	mkdir $old_fs_backup
	echo mv .\* \* $old_fs_backup/
	mv .* * $old_fs_backup/
fi
echo tar $ARG $TAR
tar $ARG $TAR)

CreateFstab $noUUID
if [ $BUFFALO_KERNEL -eq 0 ]; then
	ChrootPrepare $TARGET $BOOT_DEV
	chroot $TARGET df -h
	CreateInitramfsHook $SCRIPT_ROOT $TARGET $TARGET_DEV $RUN_ROOT $noUUID
	#CreateInitramfsModule $TARGET $TARGET_DEV $ARRAY
	echo $(GetFS $TARGET_DEV) >> $TARGET//etc/initramfs-tools/modules
	[ "x$(GetFS $TARGET_DEV)" = "xbtrfs" ] && echo crc32c >> $TARGET/etc/initramfs-tools/modules
	chroot $TARGET update-initramfs -utk all
	ChrootEnd $TARGET
else
	mount -o remount,rw /boot
	initrd_bak=initrd.buffalo_debian_tmp-`basename $MNT_DEV`
	(cd /boot; [ -f $initrd_bak ] && rm $initrd_bak;
	[ -f initrd.buffalo_debian ] && mv initrd.buffalo_debian $initrd_bak)
	[ $BUFFALO_KERNEL -eq 1 ] && CreateInitrd $TARGET_DEV /boot/initrd.buffalo_debian_$(basename $TARGET_DEV) 1
fi
mount -o remount,ro /boot

fi
