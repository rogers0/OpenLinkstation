#!/bin/bash

SRC_ROOT=$(readlink -f $(dirname $0)/..)
STAGE=0
ROOT=$1

. $SRC_ROOT/lib/config
. $SRC_ROOT/lib/config_local
. $SRC_ROOT/lib/shell_lib

InitVal

[ -z $(GetDev $ROOT) ] && echo Please mount rootfs on $ROOT && exit 1
ChrootPrepare $ROOT $BOOT_DEV
chroot $ROOT df -h

echo chroot $ROOT
chroot $ROOT

ChrootEnd $ROOT
