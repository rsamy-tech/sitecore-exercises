#!/bin/bash

echo "--------------------------------"
echo " Server Metrics "
echo "--------------------------------"
echo " DISK USAGE "
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }'
echo " CPU USAGE "
CPU=$(top -bn1 | grep load | awk '{printf "%.2f%%\t\t\n", $(NF-2)}')
echo $CPU
netu() {
    # [net]work [u]sage: check network usage stats

    net_device=$(ip route | awk '/via/ {print $5}')
    TRANSMITTED=$(ifconfig "$net_device" | awk '/TX packets/ {print $6$7}')
    RECEIVED=$(ifconfig "$net_device" | awk '/RX packets/ {print $6$7}')

    printf "%s\n" "$(tput bold) TRANSMITTED $(tput sgr0): $TRANSMITTED"
    printf "%s\n" "$(tput bold) RECEIVED    $(tput sgr0): $RECEIVED"
}
echo " NETWORK USAGE FROM WHEN SYSTEM UP AND RUNNING"
netu