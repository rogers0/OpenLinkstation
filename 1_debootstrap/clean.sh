#!/bin/sh

cd /mnt/array1/ &> /dev/null || cd /mnt/disk1/ &> /dev/null || cd /mnt/disk2/ &> /dev/null
pwd
rm -rf bin boot dev etc home lib linkstation media mnt opt proc root rootfs* run sbin selinux srv sys tmp usr var vmlinuz initrd.img
ls -l
cd ~
