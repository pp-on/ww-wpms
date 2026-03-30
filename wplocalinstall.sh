#!/bin/bash

MYDIR="$(dirname "$0")"

#search for wp-sites
source "${MYDIR}/wphelpfuntions.sh" 
#wp  functions for installing
source "${MYDIR}/wpfunctionsinstall.sh"

#default values
mode="normal"  #install wordpress
dir=$(basename $PWD) #current directory
#default values for DB
dbuser="wordpress"
dbpw="AM1uY+4C9l4#,1;V=xDAd."
hostname="localhost"
# replace "-" with "_" for database name 
dbname=${dir//[^a-zA-Z0-9]/_}

wpemail="oswaldo.nickel@pfennigparade.de"
title="test${dir^^}"           #uppercase
#url="localhost/arbeit/repos/$dir"
url="arbeit.local/repos/$dir"
php=$(php -v |  head -n 1 | cut -d " " -f 2)
wp="wp"
tdir="."
#ssh=0 # for git clone HTTPS(default)
#git="git@github.com-a"
#default
gituser="pfennigparade" #github user
git="https://github.com/"
repo="$git${gituser}/${dir}.git"
###########################
##     functions        ###
###########################
tldr() {

    echo -e "${Green}This script will install a new fresh WordPress in the current directory. It could use another path with -d.\nIt will used its name (directory) and create a db. \n${Yellow} It'll download, install and disable search engine indexing for local development of the latest WordPrss. Then it will clone the repository (The directory must be named exatly the repository in GitHub) and activate all the  plugins.\n${Purple}Default will be cloned with https\nRequirements ar e that Xampp (or any webserver) is set up and running. Wp cli must be installed also. ddev flag could also be passed. It will then use this dockerized as webserver.
    "$Color_Off
}

usage() { 
    echo -e "${Cyan}USAGE: $0 [-h hostname][-u dbuser][-p dbpassword][-n dbname] -t
    title[--url location][-U|--wp-user wpuser][-P|--wpp wppassword][-d targetDIR][-w
    path/to/wp][-g repository ][--ssh user@host for github]${Color_Off}"
    echo -e "-n arg:  specify the name of the database (if not, current dir
    would be used)\n[WARNING] If it exists, it will be dropped"
    echo "-h arg: specify the hostname for the database (default localhost)"
    echo "-u arg: specify the user for the DBMS (default web)"
    echo "-p arg: specify the password for the DBMS (default 1234)"
    echo "-t arg: [MANDATORY] set the the title for the Website"
    echo "--url arg: set the location/address inn the webserver (defauLt
    localhost/arbeit/CURRENT_DIR)"
    echo "-u or --wp-user and -P or --wp-password arg: admin credentials for this WP site (default "test",
    "secret")"
    echo "-E or --wp-email arg: specify the email address for this WP site (default
    oswaldo.nickel@pfennigparade.de)"
    echo "-d arg: use this director for the installation (default CURRENT_DIR)"
    echo "-w arg: specify location of wp-cli"
    echo "-g arg: repository to be cloned from GitHub"
    echo "-D or --ddev: init and starts container. url: https//$CURRENT_DIR.ddev.site wp: ddev wp, hostname: db" 
    echo "--ssh arg: host in github to used to clone (default: git@github.com)"
    exit
}

####################################################
####+################################################
## MAIN

#[ $# -eq 0 ] && usage
#while [ $# -gt 0 ];do
for arg in "$@"; do
    #case $1 in
    case $arg in
        -N|--new)
            mode="new"
            ;; 
        -n)
            shift
            dbname="$dbname$1"
            ;;
        -u)
            shift
            dbuser=$1
            ;;
        -p)
            shift
            dbpw=$1
            ;;
        -t)
             shift
             title=$1
             ;;
        --url)
            shift
             url=$1
            ;;
        -U|--wp-user)
            shift
            wpuser=$1
            ;;
        -P--wp-password)
            shift
            wppw=$1
            ;;
       -E|--wp-email)
            shift
            wpemail=$1
            ;;
        -d)
            shift
            tdir=$1
            ;;
        -h)
            shift
            hostname=$1
            ;;
        -wm|--wp-migrate-db-pro)
            wp_key_migrate
            ;;
        -w)
            shift
            wp=${1}
            ;;
        -g)
            shift
            repo=${1}
            ;;
        -hc|--https-clone)
            git="https://github.com/"
            ;;
        -sa|--ssh-alias)
            #host in .ssh/config
            shift
            compose_repo "$1"
            ;;
        -pk|--private-ssh)
            #ssh=1 #use my ssh key
            compose_repo "arbeit" 
            ;;
        --ssh)
            #ssh=2 #normal
            compose_repo "git@github.com" 
            ;;
        
        -D|--ddev)
            mode="ddev"
            wpuser="db"
            wppw="db"
            dbname="db"
            hostname="db"
            url="${dir}.ddev.site"
            wp="ddev wp"
            ;;
        --debug)
            wp_debug
            ;;
        --help)
            tldr
            usage
            exit
            ;;
    esac
    #next argument -> e.g. $2 becomes $1, $3 becomes $2...
    shift
done
colors
os_detection 0
os_process 
sleep 1
case "$mode" in
    normal)
        install_wp
        ;;
    new)
        new_wp
        ;;
    ddev)
        ddev_install_wp
        ;;
esac





