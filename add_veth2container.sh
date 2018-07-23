#!/bin/bash

#===================   COLORIZING  OUTPUT =================
declare -A colors
colors=(
	[none]='\033[0m'
	[bold]='\033[01m'
	[disable]='\033[02m'
	[underline]='\033[04m'
	[reverse]='\033[07m'
	[strikethrough]='\033[09m'
	[invisible]='\033[08m'
	[black]='\033[30m'
	[red]='\033[31m'
	[green]='\033[32m'
	[orange]='\033[33m'
	[blue]='\033[34m'
	[purple]='\033[35m'
	[cyan]='\033[36m'
	[lightgrey]='\033[37m'
	[darkgrey]='\033[90m'
	[lightred]='\033[91m'
	[lightgreen]='\033[92m'
	[yellow]='\033[93m'
	[lightblue]='\033[94m'
	[pink]='\033[95m'
	[lightcyan]='\033[96m'

)
num_colors=${#colors[@]}
# -----------------------------------------------------------

# ==================== USE THIS FUNCTION TO PRINT TO STDOUT =============
# $1: color 
# $2: text to print out
# $3: no_newline - if nothing is provided newline will be printed at the end
#				 - anything provided, NO newline is indicated
function c_print () {
	color=$1
	text=$2
	no_newline=$3
	#if color exists/defined in the array
	if [[ ${colors[$color]} ]] 
	then 
		text_to_print="${colors[$color]}${text}${colors[none]}" #colorized output
	else
		text_to_print="${text}" #normal output
	fi

	if [ -z "$no_newline" ]
	then
		echo -e $text_to_print # newline at the end
	else
		echo -en $text_to_print # NO newline at the end
	fi

}
# -----------------------------------------------------------



function print_help {
	echo 
	c_print "none" "Usage:" 0
	c_print "bold" "./add_veth2container.sh <container_name> <veth_name_at_host> <veth_name_in_container>"
	echo 
	exit -1
}

function clean_up {
	c_print "red" "[FAILED]\n"
	echo
	c_print "none" "Cleaning up..."
	c_print "yellow" "Removing symlink to container ${container_name}(if created)..." 0
	sudo rm -rf /var/run/netns/$container_name >/dev/null
	c_print "green" "[OK]\n"
	c_print "yellow" "Removing veth pair  ${veth_name_at_host} - ${veth_name_in_container} (if created)..." 0
	sudo ip link del $veth_name_at_host &> /dev/null
	c_print "green" "[OK]\n"
	echo 
	exit -1
}

# ============ PARSE ARGS ================
if [ $# -ne 3 ]
then
	c_print "red" "Insufficient number of attributes"
	print_help
fi

container_name=$1
veth_name_at_host=$2
veth_name_in_container=$3

# ----------------------------------------

# ======================= CHECKING CONTAINER RUNNING STATUS AND EXISTENCE =====================================
c_print "none" "Checking whether container ${colors[bold]}${container_name}${colors[none]} is running..." 0
#checking running container is a bit tricky - as -f name=<name> works like grep, so substring of a container_name
#will also be printed out, but if we compare it to the actual name again, then we can filter properly
#we need an extra $ sign at the end of name= filter to filter for that specific container and not catch any other
#containers that might have this name as a substring in the beginning
if [[ $(sudo docker ps -a --filter "status=running" -f "name=$container_name$" --format '{{.Names}}') != $container_name ]]
then
	c_print "red" "[FAILURE]"
	c_print "red" "${container_name} is not running"
	c_print "yellow" "Use ${colors[bold]}sudo docker ps -a${colors[none]} to find out more on your own\n"

	clean_up
fi
c_print "green" "[OK]"
c_print "green" "${container_name} is found and up and running\n"
# ------------------------------------------------------------------------------------------------------------


c_print "none" "Getting PID of the running container ${colors[bold]}${container_name}:   " 0
pid=$(docker inspect -f '{{.State.Pid}}' $container_name)
c_print "green" "[OK] (${pid})\n"

c_print "none" "Creating ${colors[bold]}/var/run/netns/${colors[none]} directory..." 0
mkdir -p /var/run/netns/
c_print "green" "[OK]\n"

c_print "none" "Create a symlink ${colors[bold]}${container_name}${colors[none]} in ${colors[bold]}/var/run/netns/${colors[none]} pointing to ${colors[bold]}/proc/${pid}/ns/net..." 0
sudo ln -sf /proc/$pid/ns/net /var/run/netns/$container_name
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"




# check in the beginning whether the interfaces exist
interface_contains_vethname=$(sudo ip link|grep $veth_name_at_host|cut -d ':' -f 2 |cut -d '@' -f 1|sed "s/ //g")
c_print "none" "Looking for existing device names as ${veth_name_at_host} at host..." 0
if [[ $interface_contains_vethname == "" ]]
then
	found="NONE"
	c_print "green" "[OK]"
else
	found=$interface_contains_vethname
	c_print "yellow" "[WARN]"
	c_print "none" "Similar interfaces found: ${colors[bold]}${colors[yellow]}${found}"
fi 


#check whether that interface's is exactly the one that we are intended to add next 
if [[ $found != "NONE" ]]
then
	for i in $interface_contains_vethname
	do
		if [[ $i == $veth_name_at_host ]]
		then
			c_print "yellow" "There is already an interface called ${colors[bold]}${colors[red]}${veth_name_at_host} at host\n"
			c_print "none" "Please use another name or remove manually by:"
			c_print "bold" "\$ sudo ip link del ${veth_name_at_host}\n\n"
			exit -1
		fi
	done
fi

#check whether that interface intended to be in the container exists
interface_contains_vethname=$(sudo docker exec ${container_name} ip link|grep $veth_name_in_container |cut -d ':' -f 2 |cut -d '@' -f 1|sed "s/ //g")
c_print "none" "Looking for existing device names as ${veth_name_in_container} in the container..." 0
if [[ $interface_contains_vethname == "" ]]
then
	found="NONE"
	c_print "green" "[OK]"
else
	found=$interface_contains_vethname
	c_print "yellow" "[WARN]"
	c_print "none" "Similar interfaces found in the container: ${colors[bold]}${colors[yellow]}${found}"
fi 


#check whether that interface's is exactly the one that we are intended to add next 
if [[ $found != "NONE" ]]
then
	for i in $interface_contains_vethname
	do
		if [[ $i == $veth_name_in_container ]]
		then
			c_print "yellow" "There is already an interface called ${colors[bold]}${colors[red]}${veth_name_in_container}${colors[none]}${colors[yellow]} in container\n"
			c_print "none" "Please use another name or remove manually (the other end of the veth pair at the host) by:"
			c_print "bold" "\$ sudo ip link del ${veth_name_at_host}\n\n"
			exit -1
		fi
	done
fi

c_print "none" "Interface names..." 0
c_print "green" "[OK]"
c_print "green" "Interface names are in a good shape! None of them exists!!\n\n"





c_print "none" "Create veth pair ${colors[bold]}${veth_name_at_host} -- ${veth_name_in_container}${colors[none]}..." 0
sudo ip link add $veth_name_at_host type veth peer name $veth_name_in_container
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"

c_print "none" "Bringing up ${colors[bold]}${veth_name_in_container}..."
sudo ifconfig $veth_name_in_container up
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"

c_print "none" "Bringing up ${colors[bold]}${veth_name_at_host}..."

sudo ifconfig $veth_name_at_host up
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"


c_print "none" "Add ${colors[bold]}${veth_name_in_container}${colors[none]} to container ${colors[bold]}${container_name}${colors[none]}..." 0
sudo ip link set $veth_name_in_container netns $container_name
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"

c_print "none" "Bring up manually the interface in the container as well..." 0
sudo ip netns exec $container_name ifconfig $veth_name_in_container up
if [ $? -ne 0 ]
then
	clean_up
fi
c_print "green" "[OK]\n"






