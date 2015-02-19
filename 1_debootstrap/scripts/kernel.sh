#!/bin/sh

ver=$(dpkg -l|grep linux-image-|grep ^ii|head -n1| cut -d" " -f3|sed s/linux-image-//)
dtb=/boot/dtb/kirkwood-lswxl.dtb

echo "devio > /tmp/foo 'wl 0xe3a01c02,4' 'wl 0xe381100f,4'"
devio > /tmp/foo 'wl 0xe3a01c02,4' 'wl 0xe381100f,4'

echo "cat /tmp/foo /boot/vmlinuz-$ver $dtb > /tmp/vmlinuz"
cat /tmp/foo /boot/vmlinuz-$ver $dtb > /tmp/vmlinuz

echo mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n $ver -d /tmp/vmlinuz /boot/vmlinuz.uimg-$ver
mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n $ver -d /tmp/vmlinuz /boot/vmlinuz.uimg-$ver
rm /tmp/foo /tmp/vmlinuz

echo mkimage -A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0 -n $ver -d /boot/initrd.img-$ver /boot/initrd.uimg-$ver
mkimage -A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0 -n $ver -d /boot/initrd.img-$ver /boot/initrd.uimg-$ver

ls -l /boot/uImage.buffalo /boot/initrd.buffalo
if [ "x$1" = "x1" ]; then
	(cd /boot;
	echo ln -sf vmlinuz.uimg-$ver uImage.buffalo;
	ln -sf vmlinuz.uimg-$ver uImage.buffalo;
	echo ln -sf initrd.uimg-$ver initrd.buffalo;
	ln -sf initrd.uimg-$ver initrd.buffalo)
	ls -l /boot/uImage.buffalo /boot/initrd.buffalo
else
	echo cd /boot
	echo ln -sf vmlinuz.uimg-$ver uImage.buffalo
	echo ln -sf initrd.uimg-$ver initrd.buffalo
fi
