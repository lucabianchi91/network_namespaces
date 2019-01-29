#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Disable IP-forwarding.
echo 0 > /proc/sys/net/ipv4/ip_forward

# Flush forward rules, policy ACCEPT by default.
iptables -F FORWARD
# iptables -P FORWARD DENY

# no natting
iptables -t nat -F

# remove all ns
ip -all netns delete


