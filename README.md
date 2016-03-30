OpenLinkstation
===============


----
NEWS
----

The DeviceTree (DTB) for Linkstation LS-WXL/LS-WSXL & LS-WVL/LS-VL already got merged into mainline Linux!

	Latest status from ML: http://lists.infradead.org/pipermail/linux-arm-kernel/2015-July/357283.html

Thanks Mario Lange, we'll soon support LS-QVL, too!

    http://lists.infradead.org/pipermail/linux-arm-kernel/2016-January/401681.html

With the development on d-i (Debian Installer), now scripts here seems obsolete, because we can install Debian directly.
There's no official release yet, so you need to use daily images. Find images for your Linkstation model here:

    https://d-i.debian.org/daily-images/armel/daily/orion5x/network-console/buffalo/
    https://d-i.debian.org/daily-images/armel/daily/kirkwood/network-console/buffalo/

Put those images into 1st partition of the HDD (/dev/sda1 or /dev/md0), and boot Linkstation, after a few minutes you can access to the d-i via SSH connection:

    ssh installer@<IP address>

the password should be "install".
Then follow the instruction, you can natively install a clean Debian system.

----
Purpose
----

To get system updated on Linkstation series, it's better to replace the stock firmware with system seriously maintained, like Debian.


----
Howto
----

Step0, get SSH shell access. Run on your Linux PC:

	0_get-ssh/get-ssh.sh <Linkstation IP> [Linkstation web login password]

Step1, debootstrap to data partition (/dev/sda6 for one-disk version or /dev/md2 for RAID version). You can set debian distro, hostname, password in "lib/config". Run on Linkstation box:

	vi lib/config
	1_debootstrap/build_rootfs_with_buffalo-kernel.sh
	reboot

Step2, reboot into Debian system on data partition, then build the final rootfs on root partition. Please note the password for ssh login is just 'password', if you didn't change it in previous step. After login, run on Linkstation box:

    mkfs.<FS TYPE> /dev/<ROOT DEV>
	mount /dev/<ROOT DEV> /mnt
	/linkstation/1_debootstrap/build_rootfs_with_buffalo-kernel.sh debian
	reboot

After a few minutes on booting, you should be able to log into your Linkstation with Debian installed. Clean up the stuff we don't need any more:

	cd /mnt
	rm -rf bin boot dev dev etc home lib media mnt opt proc root sbin selinux srv sys tmp usr var run


----
Status
----

Confirmed to be working on the model/firmware below:

 - LS-QVL 1.71 (Debian 3.16-ckt Wheezy-backport / Jessie kernel + own DTB)
 - LS-VL 1.68 ~ 1.71 (Debian 3.16-ckt Wheezy-backport / Jessie kernel + own DTB)
 - LS-WSXL 1.68 ~ 1.71 (Debian 3.16-ckt Wheezy-backport / Jessie kernel + own DTB)
 - LS-WVL 1.68 ~ 1.71 (Debian 3.16-ckt Wheezy-backport / Jessie kernel + own DTB)
 - LS-WXL 1.68 ~ 1.71 (Debian 3.16-ckt Wheezy-backport / Jessie kernel + own DTB)
 - LS-420 1.80 ~ 1.81 (Debian Jessie root fs + Buffalo kernel) (upgrade to Jessie is OK, but direct bootstrap to Jessie still has issue)


----
Credit
----

- http://sourceforge.net/p/linkstationwiki/code/HEAD/tree/acp_commander/trunk/
- http://buffalo.nas-central.org/wiki/Debian_Squeeze_on_LS-WXL
- http://buffalo.nas-central.org/wiki/Initrd_for_Raid-Boot
- http://www.hellion.org.uk/blog/posts/debugging-initramfs-over-netconsole/
