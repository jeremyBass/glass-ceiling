#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

cronfile=${0##*/}             #glassceiling.sh      #NOTE THIS SHOULD DETECT IT'S SELF
path=$(pwd)                   #this is the path to the file 



percent_allowed=80          #this should be max memory before action
memusage=0
USEDMEM=0
PERCENTAGE=0

#ensure that there is a crontab for this user
#$(crontab -l)
if [ -z "$1" ]; then
	percent_allowed=80
else
	percent_allowed="$1"
fi


if [[ "$path" == "/" ]]; then
	path=""
fi

# Sets up the crontab for this
touch cron.log
has_cron(){
	#is the file in the cron?
	#return 0 #returning this just to test should
	$(crontab -l | egrep -v '^$|^#' | grep -q "$cronfile $percent_allowed";) && return 1 || return 0
}
if has_cron;
then
	echo "$(date) --memory limit set at $percent_allowed%" >> /cron.log
	crontab -l > mycron
	# Echo new cron into cron file
	echo "*/2 * * * * sh $path/$cronfile $percent_allowed" >> mycron
	# Install new cron file
	crontab mycron
	rm mycron
	echo "$(date) --Installation sucess, memory limit is at $percent_allowed%" >> /cron.log
fi

is_up(){
	$(ps auxw | grep nginx | grep -v grep > /dev/null && ps auxw | grep php-fpm | grep -v grep > /dev/null) && return 1 || return 0
}
if is_up;
then
	
else
	echo "$(date) --restarting nginx and php-fpm " >> /cron.log
	echo $(/etc/init.d/php-fpm restart) 1>&2 >> /cron.log
	echo $(/etc/init.d/nginx restart) 1>&2 >> /cron.log
fi

# sets up the function of this script
test_memory(){
	memusage=$(top -n 1 -b | grep "Mem")
	MAXMEM=$(echo $memusage | cut -d" " -f2 | awk '{print substr($0,1,length($0)-1)}')
	USEDMEM=$(echo $memusage | cut -d" " -f4 | awk '{print substr($0,1,length($0)-1)}')

	USEDMEM1=$(expr $USEDMEM \* 100)
	PERCENTAGE=$(expr $USEDMEM1 / $MAXMEM)
	
	[[ $PERCENTAGE>$percent_allowed ]] && return 0 || return 1
}


if test_memory;
then
	echo "$(date) --mem is critical, $PERCENTAGE% ($USEDMEM), restarting -- $path/$cronfile " >> /cron.log
	echo $(/etc/init.d/php-fpm restart) 1>&2 >> /cron.log
	echo $(/etc/init.d/nginx restart) 1>&2 >> /cron.log
	#echo "It seems that you're out of memory and luck" | mutt -a "/cron.log" -s "OUT of Memory" -- recipient@domain.com
fi





exit 0
