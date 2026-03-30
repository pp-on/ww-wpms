#!/bin/env bash

#search for wp-sites
source ~/git/ho-updates/wphelpfuntions.sh
#wp  functions for installing
source ~/git/ho-updates/wpfunctionsinstall.sh

hostname=""     #host in DB
dbuser="web"
dbpw="1234"
dir=$(basename "$PWD")
# replace "-" with "_" for database name 
dbname=${dir//[^a-zA-Z0-9]/_}
title="test${dir^^}"           #uppercase
url="localhost/arbeit/updates/repos/$dir"
wpuser="test"
wppw="secret"
wpemail="oswaldo.nickel@pfennigparade.de"
wp="wp"
ssh=0 # for git clone HTTPS(default)
#git="git@github.com-a"
gituser="pfennigparade" #github user
#repo="https://github.com/${gituser}/${dir}.git"
###########################
##     functions        ###
###########################
usage() { 
    echo -e "${Cyan}USAGE: $0 ${Green} ssh=1 or https=0, location of target dir(http://localhost/...) $Color_Off}"
}

####################################################
####+################################################
## MAIN

[[ "$#" -eq 0 ]] && usage && exit
while [[ "$#" -gt 0 ]];do
#for arg in "$@"; do
    case $1 in
    #case $arg in
        -u) #url
            url="$2"
            ;;
        -h) #hostname
            hostname="$2"
            ;;
        -w)
            wp="$2"
            ;;
        -g)
            repo="$2"
            ;;
        -s)
            ssh="$2"
            ;;
        -\?|--help)
            usage
            exit
            ;;
    esac
    #next argument -> e.g. $2 becomes $1, $3 becomes $2...
    shift
done
colors
sleep 1
    os_process 
    sleep 1
main
