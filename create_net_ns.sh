#!/bin/bash

N_NS=0
OUT=0
GW_INTF=""
HELP="Create Network Namespaces that can communicate between them. Options:\n
-h help\n
-n number of ns\n
-o 1 if the ns must have access to internet. Nothing or other values means no\n
-i intf to use as gateway for internet access. If o is 1, then an intf must be specified.
"

# : means that the option need an argument
while getopts hn:o:i: option
do
case "${option}"
in
h) echo -e $HELP; exit;;
n) N_NS=${OPTARG};;
o) OUT=${OPTARG};;
i) GW_INTF=${OPTARG};;
esac
done

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $N_NS -lt 1 ]]
then
	echo "n must be > 0"
	echo -e $HELP
	exit
fi

if [[ $OUT == 1 ]]
then
	ALL_INTF=$(ls -1 /sys/class/net | sed 's/lo//')
	if [[ $GW_INTF == "" ]]
	then
		echo "Missing -i value. Choose one of $ALL_INTF"
		echo -e $HELP
		exit
	fi
fi


i=1
while [[ $i -le $N_NS ]]
do
	NS_NAME=ns$i
	VETH_NET=100.100.$i.0/255.255.255.0
	INTF_ROOT=veth_root_$i
	ADDR_ROOT=100.100.$i.1
	INTF_NS=veth_ns_$i
	ADDR_NS=100.100.$i.2
	NS="ip netns exec $NS_NAME"
	# add a namespace called ns1
	ip netns add $NS_NAME
	# put up the lo in the ns
	# $NS ip link set dev lo up
	# create a veth pair
	ip link add $INTF_ROOT type veth peer name $INTF_NS
	# veth_root_1 is the end in the root ns
	# veth_ns_1 is the end in the new ns, so move it there
	ip link set $INTF_NS netns $NS_NAME
	# set up ip addresses
	ip addr add $ADDR_ROOT/24 dev $INTF_ROOT
	ip link set $INTF_ROOT up
	$NS ip addr add $ADDR_NS/24 dev $INTF_NS
	$NS ip link set $INTF_NS up
	$NS ip link set lo up
	# in the ns, set the default gw
	$NS ip route add default via $ADDR_ROOT
	((i = i + 1))
done

# list namespaces
ip netns

# Enable IP-forwarding.
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush forward rules, policy DROP by default.
iptables -P FORWARD ACCEPT
# todo only once
#iptables -F FORWARD
# Flush nat rules.
# todo ony once
# iptables -t nat -F

# Allow forwarding between eth0 and v-eth1.
#iptables -A FORWARD -i $GW_INTF -o $INTF_ROOT -j ACCEPT
#iptables -A FORWARD -o $GW_INTF -i $INTF_ROOT -j ACCEPT

# Share internet access between host and NS.
if [ $OUT == 1 ]
then
	# Enable masquerading
	iptables -t nat -A POSTROUTING -s $VETH_NET -o $GW_INTF -j MASQUERADE
	# set up the dns for the ns to have full internet access
	mkdir -p /etc/netns/$NS_NAME/
	echo 'nameserver 8.8.8.8' > /etc/netns/$NS_NAME/resolv.conf
fi
