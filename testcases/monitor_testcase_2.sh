#!/bin/bash
#
# Testcase 2: fail mirror sides w/o I/O
#

. ./monitor_testcase_functions.sh

MD_NUM="md1"
MD_NAME="testcase2"
DEVNOS_LEFT="0.0.0200 0.0.0201 0.0.0202 0.0.0203"
DEVNOS_RIGHT="0.0.0210 0.0.0211 0.0.0212 0.0.0213"

logger "Monitor Testcase 2: Fail both mirror sides w/o I/O"

stop_md $MD_NUM

activate_dasds

clear_metadata

ulimit -c unlimited
start_md ${MD_NUM} ${MD_NAME}

echo "Create filesystem ..."
if ! mkfs.btrfs /dev/${MD_NUM} ; then
    error_exit "Cannot create fs"
fi
# I see random errors without it ...
sleep 1 

echo "Mount filesystem ..."
if ! mount /dev/${MD_NUM} /mnt ; then
    error_exit "Cannot mount MD array."
fi

echo "Write test file ..."
dd if=/dev/zero of=/mnt/testfile1 bs=4096 count=1024

echo "Fail first half ..."
mdadm --manage /dev/${MD_NUM} --fail ${DEVICES_LEFT[@]}
mdadm --detail /dev/${MD_NUM}
sleep 10
mdadm --detail /dev/${MD_NUM}
echo "Fail second half ..."
mdadm --manage /dev/${MD_NUM} --fail ${DEVICES_RIGHT[@]}
mdadm --detail /dev/${MD_NUM}
sleep 10
mdadm --detail /dev/${MD_NUM}

echo "Umount filesystem ..."
umount /mnt

stop_md ${MD_NUM}