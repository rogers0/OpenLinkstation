OpenLinkstation
===============

----
Purpose
----

To get system updated on Linkstation series, it's better to replace the stock firmware with system seriously maintained, like Debian.


----
Howto
----

Step0, get SSH shell access. Run on your Linux PC:

	0_get-ssh/get-ssh.sh <Linkstation IP> [Linkstation web login password]

Step1, debootstrap to data partition (/dev/sda6 for one-disk version or /dev/md2 for RAID version). Run on Linkstation box:

	1_debootstrap/build_rootfs_with_buffalo-kernel.sh
	reboot

Step2, reboot into Debian system on data partition, then build the final rootfs on root partition. Run on Linkstation box:

	/build_rootfs_with_buffalo-kernel.sh debian
	reboot

After a few minutes on booting, you should be able to log into your Linkstation with Debian installed. Clean up the stuff we don't need any more:

	cd /mnt
	rm -rf bin boot dev dev etc home lib media mnt opt proc root sbin selinux srv sys tmp usr var run


----
Status
----

Confirmed to be working on the model/firmware below:

 - LS-VL 1.69 (Debian Wheezy-backport / Jessie kernel + own DTB)
 - LS-WXL 1.69 (Debian Wheezy-backport / Jessie kernel + own DTB)
 - LS-WSXL 1.69 (Debian Wheezy-backport / Jessie kernel + own DTB)
 - LS-WVL 1.69 (Debian Wheezy-backport / Jessie kernel + own DTB)


----
Credit
----

- http://sourceforge.net/p/linkstationwiki/code/HEAD/tree/acp_commander/trunk/
- http://buffalo.nas-central.org/wiki/Debian_Squeeze_on_LS-WXL
- http://buffalo.nas-central.org/wiki/Initrd_for_Raid-Boot
- http://www.hellion.org.uk/blog/posts/debugging-initramfs-over-netconsole/
