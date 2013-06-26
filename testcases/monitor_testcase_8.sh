#!/bin/bash
#
# Testcase 8: Accidental disk overwrite
#

. ./monitor_testcase_functions.sh

MD_NUM="md1"
MD_NAME="testcase8"
SLEEPTIME=30

logger "Monitor Testcase 8: Accidental DASD overwrite"

stop_md $MD_NUM

activate_dasds

clear_metadata

modprobe vmcp

ulimit -c unlimited
start_md $MD_NUM

echo "Create filesystem ..."
if ! mkfs.ext3 /dev/${MD_NUM} ; then
    error_exit "Cannot create fs"
fi

echo "Mount filesystem ..."
if ! mount /dev/${MD_NUM} /mnt ; then
    error_exit "Cannot mount MD array."
fi

echo "Run dt"
run_dt /mnt

echo "Invoke flashcopy"
vmcp flashcopy a003 16 32 to a000 0 16

echo "Waiting for MD to pick up changes ..."
# Wait for md_monitor to pick up changes
sleeptime=0
num=${#DASDS_LEFT[@]}
while [ $sleeptime -lt $SLEEPTIME  ] ; do
    for d in ${DASDS_LEFT[@]} ; do
	device=$(sed -n "s/${MD_NUM}.* \(${d}1\[[0-9]\](F)\).*/\1/p" /proc/mdstat)
	if [ "$device" ] ; then
	    (( num -- ))
	fi
    done
    [ $num -eq 0 ] && break
    num=${#DASDS_LEFT[@]}
    sleep 1
    (( sleeptime ++ ))
done
if [ $num -gt 0 ] ; then
    error_exit "MD monitor did not pick up changes after $sleeptime seconds"
fi

echo "MD monitor picked up changes after $sleeptime seconds"

echo "Stop dt"
stop_dt

# Wait for sync to complete
sleep 5

echo "MD status"
mdadm --detail /dev/${MD_NUM}

old_status=$(md_monitor -c "MonitorStatus:/dev/${MD_NUM}")
echo "Monitor status: $old_status"

echo "Reset Disk ${DEVICES_LEFT[0]}"
for d in ${DEVICES_LEFT[0]} ; do
    /sbin/md_monitor -c "Remove:/dev/${MD_NUM}@$d"

    if ! mdadm --manage /dev/${MD_NUM} --remove $d ; then
	error_exit "Cannot remove $d in MD array $MD_NUM"
    fi
    md_status=$(md_monitor -c "MonitorStatus:/dev/${MD_NUM}")
    echo "Monitor status: $md_status"
    mdadm --wait /dev/${MD_NUM}

    if ! dasdfmt -p -y -b 4096 -f ${d%1} ; then
	error_exit "Cannot format device ${d%1}"
    fi
    sleep 2
    if ! fdasd -a ${d%1} ; then
	error_exit "Cannot partition device ${d%1}"
    fi
    sleep 2
    if ! mdadm --manage /dev/${MD_NUM} --add --failfast $d ; then
	error_exit "Cannot add $d to MD array $MD_NUM"
    fi
done

MD_TIMEOUT=15
wait_time=0
while [ $wait_time -lt $MD_TIMEOUT ] ; do
    new_status=$(md_monitor -c "MonitorStatus:/dev/${MD_NUM}")
    [ $new_status != $old_status ] && break
    sleep 1
    (( wait_time++ ))
done
if [ $wait_time -ge $MD_TIMEOUT ] ; then
    error_exit "Monitor status hasn't changed for $MD_TIMEOUT seconds"
fi
echo "Monitor status: $new_status"

echo "Wait for sync"
mdadm --wait /dev/${MD_NUM}

echo "MD status after mdadm --wait:"
cat /proc/mdstat
mdadm --detail /dev/${MD_NUM}

echo "Umount filesystem ..."
umount /mnt

stop_md $MD_NUM
