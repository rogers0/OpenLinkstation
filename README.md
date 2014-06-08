OpenLinkstation
===============

----
Purpose
----

To get system updated on Linkstation series, it's better to replace the stock firmware with system seriously maintained, like Debian.


----
Howto
----

Step0, get SSH shell access:

	0_get-ssh/get-ssh.sh <Linkstation IP> [Linkstation web login password]

Step1, debootstrap to data partition (/dev/sda6 for one-disk version or /dev/md2 for RAID version)

	1_debootstrap/build_rootfs_with_buffalo-kernel.sh

Step2, reboot into Debian system on data partition, then build the final rootfs on root partition

	/build_rootfs_with_buffalo-kernel.sh debian


----
Credit
----

- http://sourceforge.net/p/linkstationwiki/code/HEAD/tree/acp_commander/trunk/
- http://buffalo.nas-central.org/wiki/Debian_Squeeze_on_LS-WXL
- http://buffalo.nas-central.org/wiki/Initrd_for_Raid-Boot
