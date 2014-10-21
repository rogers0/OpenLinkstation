#!/bin/bash

. `readlink -fn $(dirname $0)/../lib/shell_lib`

CreateInitrd 0x802 initrd.uimg_debian_dev-sda2
CreateInitrd 0x806 initrd.uimg_debian_dev-sda6
CreateInitrd 0x901 initrd.uimg_debian_dev-md1
CreateInitrd 0x902 initrd.uimg_debian_dev-md2
CreateInitrd 0x915 initrd.uimg_debian_dev-md21
