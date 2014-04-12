#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#ensure that there is a crontab for this user
#$(crontab -l)

cronfile=${0##*/}             #glassceiling.sh      #NOTE THIS SHOULD DETECT IT'S SELF
path=$(pwd)                   #this is the path to the file 
percent_allowed=80            #this should be max memory before action
memusage=0

if [[ "$path" == "/" ]]; then
    path=""
fi

touch cron.log

has_cron(){
    #is the file in the cron?
    #return 0 #returning this just to test should
    $(crontab -l | egrep -v '^$|^#' | grep -q $cronfile;) && return 1 || return 0
}
test_memory(){
    $memusage=$(top -n 1 -b | grep "Mem")
    MAXMEM=$(echo $memusage | cut -d" " -f2 | awk '{print substr($0,1,length($0)-1)}')
    USEDMEM=$(echo $memusage | cut -d" " -f4 | awk '{print substr($0,1,length($0)-1)}')

    USEDMEM1=$(expr $USEDMEM \* 100)
    PERCENTAGE=$(expr $USEDMEM1 / $MAXMEM)
    
    [[ $PERCENTAG>$percent_allowed ]] && return 1 || return 0
}

if has_cron;
then
    #was not here so add
    #run this script every 5 mins
    #crontab -e */5 * * * $path/$cronfile
    #cat <(crontab -l) <(echo "*/5 * * * $path/$cronfile") | crontab -
    crontab -l > mycron

    # Echo new cron into cron file
    echo "*/5 * * * * sh $path/$cronfile" >> mycron

    # Install new cron file
    crontab mycron
    rm mycron
    echo "$(date) --Installation sucess, memory limit is at $percent_allowed%" >> /cron.log
else
    echo "$(date) --Installation failed, cron present" >> /cron.log
fi

if test_memory;
then
    echo "$(date) --mem is critical @ $memusage, restarting -- $path/$cronfile "  >> /cron.log
    echo $(/etc/init.d/php-fpm restart) >> /cron.log
    echo $(/etc/init.d/nginx restart) >> /cron.log
    #echo "It seems that you're out of memory and luck" | mutt -a "/cron.log" -s "OUT of Memory" -- recipient@domain.com

else
    echo "$(date) --mem is ok  -- $path/$cronfile "  >> /cron.log
fi
exit 0
