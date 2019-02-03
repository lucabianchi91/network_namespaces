#!/bin/bash

N_NS=0
GW_INTF=""
OPEN_BASH=0
OUT=0
FIRST_SCRIPT=""
HELP="Create Network Namespaces that can communicate between them. Options:\n
-h: display the help message\n
-n number: number of namespaces to be created\n
-i intf_name: network interface to be used as gateway (if any)\n
-b: open a new bash (terminal) for each namespace\n
-f script: run script in each namespace. If -b is passed, script is run in the new terminals
"

# : means that the option need an argument
while getopts n:i:f:obh option
do
case "${option}"
in
h) echo -e $HELP; exit;;
n) N_NS=${OPTARG};;
i) OUT=1; GW_INTF=${OPTARG};;
b) OPEN_BASH=1;;
f) FIRST_SCRIPT=${OPTARG};;
esac
done

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ $N_NS -lt 1 ]]
then
	echo "n must be > 0"
	exit
fi

if [[ $OUT == 1 ]]
then
	ALL_INTF=$(ls -1 /sys/class/net | sed '/lo/d')
	if [[ $GW_INTF == "" ]]
	then
		echo -e "Missing -i value. Choose one of:\n$ALL_INTF"
		exit
	fi
fi

# Enable IP-forwarding.
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush forward rules, policy ACCEPT by default.
iptables -F FORWARD
iptables -P FORWARD ACCEPT
# Otherwise you have to allow forwarding between every possible eth0 and v-eth1.
#iptables -A FORWARD -i $GW_INTF -o $INTF_ROOT -j ACCEPT
#iptables -A FORWARD -o $GW_INTF -i $INTF_ROOT -j ACCEPT

# Flush nat rules if internet access is requested
if [[ $OUT == 1 ]]
then
	iptables -t nat -F
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
	# Share internet access between host and NS if requested
	if [[ $OUT == 1 ]]
	then
		# Enable masquerading
		iptables -t nat -A POSTROUTING -s $VETH_NET -o $GW_INTF -j MASQUERADE
		# set up the dns for the ns to have full internet access
		mkdir -p /etc/netns/$NS_NAME/
		echo 'nameserver 8.8.8.8' > /etc/netns/$NS_NAME/resolv.conf
	fi
	((i = i + 1))
done


if [[ $OPEN_BASH == 1 ]]
then
	i=1
	while [[ $i -le $N_NS ]]
	do	
		export FIRST_SCRIPT		
		gnome-terminal -- ip netns exec ns$i bash -c 'ip netns identify; $FIRST_SCRIPT; /bin/bash' &
		((i = i + 1))
	done
else
	if [[ -n "$FIRST_SCRIPT" ]]
	then
		i=1
		while [[ $i -le $N_NS ]]
		do
			echo "Executing $FIRST_SCRIPT in ns$1"
			ip netns exec ns$i $FIRST_SCRIPT
			((i = i + 1))
		done
	fi
fi





# open terminals if requested and run the first command
# gnome-terminal -- ip netns exec ns2 bash -c 'ifconfig;bash'





