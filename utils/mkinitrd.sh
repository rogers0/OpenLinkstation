#!/bin/bash

. `readlink -fn $(dirname $0)/../lib/shell_lib`

mount -o remount,rw /boot
CreateInitrd 0x802 /boot/initrd.uimg_debian_dev-sda2
CreateInitrd 0x806 /boot/initrd.uimg_debian_dev-sda6
CreateInitrd 0x901 /boot/initrd.uimg_debian_dev-md1
CreateInitrd 0x902 /boot/initrd.uimg_debian_dev-md2
CreateInitrd 0x915 /boot/initrd.uimg_debian_dev-md21
mount -o remount,ro /boot
