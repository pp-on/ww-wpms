#! /bin/bash

wpuser="test"
wppw="secret"
wpemail="oswaldo.nickel@pfennigparade.de"
# check if database exists. In order to work -> user has to be in mysql grroup
check_db(){ 
    echo "#########################################"
    echo "### checking database ###"
    echo "#########################################"
    checkdb=$(mysqlshow  -h $hostname -u web -p1234 -h $hostname $dbname | grep -v Wildcard | grep -o $dbname)
    if [ -z "$checkdb" ]; then
        echo -e "${Red}found no Database with the name $dbname. Moving
        on${Color_Off}"
        create_db
    else
        echo "found Database $dbname"
        echo "By continuiing all its data will be erased"
        echo "Proceed [y/n]"
        read a
        if [ "$a" = "y" ]; then
            create_db
        elif [ "$a" = "n" ]; then
            echo "aborting..."
            exit
        fi
    fi

}
create_db (){
    echo ""
    out "Creating Database $dbname" 1
    sleep 1
    mysql -u $dbuser -p$dbpw -h $hostname -e "DROP DATABASE IF EXISTS $dbname;
    CREATE DATABASE $dbname"
}
wp_dw (){
    out "downloading core" 1
    sleep 1
    $wp core download --locale=de_DE
}
wp_config (){ #
    out "creating config" 1
    out "using hostname $hostname" 2
    f="wp-config.php"
    if [ ! -f "$f" ]; then
        echo -e "$Yellow there is no $f $Color_Off"
    else
        rm $f
    fi
    sleep 1
    $wp config create --dbname="$dbname" --dbuser="$dbuser" --dbpass="$dbpw" --dbhost="$hostname" 

#    if [ "$wsl" -eq 1 ]; then
 #       echo "define('WP_USE_EXT_MYSQL', false);" >> wp-config.php
  #  fi

}
#alternative for creating DB with mysql using user and name of wp config
wp_db (){
    out "Creating Database $dbname" 1
    sleep 1
    # drop the database and create a new one##
    $wp db reset --yes

    #if there's  an error, exit -> || means exit status 1
#    if [ $gb -eq 1 ]; then    #if there's  an error, e
#        winpty mysql -u "$#    if [ $gb -eq 1 ]; then dbuser" -p"$dbpw" -h "$hostname" -e "DROP DATABASE IF EXISTS `$dbname`;" || echo -e "$Red Error $Color_Off dropping Database"
#    else
#        mysql -u "$dbuser" -p"$dbpw" -h "$hostname" -e "drop DATABASE IF EXISTS `$dbname`;" || echo -e "$Red Error $Color_Off dropping Database"
#    fi
    # out "Dropping $dbname" 2
    # sleep 1
    # read -p "Do you want to drop the database? [y/n]" a
    # if [ "$a" = "y" ]; then
    #     $wp db drop --yes
    #     # mysql -u "$dbuser" -p"$dbpw" -h "$hostname" -e "DROP DATABASE IF EXISTS `$dbname`;" || echo -e "$Red Error $Color_Off dropping Database"
    # elif [ "$a" = "n" ]; then
    #     echo "aborting..."
    # fi
    # out "Creating new $dbname" 2
    # sleep 1
    # $wp db create
    #
}
wp_config_ddev(){
    out "Generating wp-config.php..." 1
    ddev wp config create \
    --dbname=db --dbuser=db --dbpass=db --dbhost=db \
    --skip-check --force

}
wp_install (){
    out "installing wp ${title}" 1
    sleep 1
    $wp core install --url="$url" --title="$title" --admin_user="$wpuser" --admin_password="$wppw" --admin_email="$wpemail"   || echo -e "${Red}Something went wrong${Color_Off}"
}
wp_git (){ 
  
    if [ -z "$repo" ]; then
        echo "No repository specified"
        echo "please enter one"
        read repo
    fi

    out "cloning $repo" 1
    sleep 1
    rm ./wp-content/ -rf
   # if [ $wsl -eq 1 ]; then
    #    gh repo clone $repo wp-content
    #else
    #    git clone $repo wp-content
    #fi
    git clone $repo wp-content
    out "activating plugins" 2
    $wp plugin activate --all
}
#ssh_repo(){ #ssh
    #local ssh
    #ssh="$1"

    #case "$ssh" in
        #0)
            #git="https://github.com/"
            #;;
        #1)
            #git="git@github.com-a:" 
            #;;
        #2)
            #git="git@github.com:" 
            #;;
            
    #esac
#}
compose_repo (){ #git for ssh -> : !! 
    repo=${1}:${gituser}/${dir}.git    #it can be changed with -g

}
out_msg (){ #what?, where? ssh
    url="$2"
            
    out "$1" 1
    sleep 1
    out "PHP: $php wp: $wp" 2
    sleep 1
    out "DB: $dbname" 2
    sleep 1
    out "WP_user:  $wpuser" 2
    out "WP_pass: $wppw" 2
    out "WP_email: $wpemail" 2
    sleep 1
    out "hostname: $hostname" 2
    sleep 1
    out "Local: $url" 2
    sleep 1
    out " Repo: $repo" 2
    sleep 2
}


os_process(){ #kernel version
 #   [[ "$cOS" == "WSL" ]]  && url="localhost/repos/${dir}" && hostname="127.0.0.1" 
 #   [[ "$cOS" == "Git_Bash" ]]  && url="localhost/repos/${dir}" &&  hostname="localhost"
    uname="$(uname -r)"
    #ssh_repo "$ssh"
    out_msg "${cOS}-${uname}" "${url}" 
}
install_wp(){ 
    wp_dw
    wp_config 
    wp_db
    
    wp_install
    htaccess
    wp_block_se
    wp_git 
    wp_license_plugins "ACF_PRO"
    wp_license_plugins "WPMDB"
    wp_rights
}
new_wp(){
    wp_dw
    wp_config
    wp_db
    wp_install
    htaccess
}
ddev_install_wp(){
    # Initialize DDEV config
    out "Initializing and starting DDEV" "#"
    ddev config --project-type=wordpress --docroot=. --project-name="$dir"

    # Start DDEV containers
    out "starting..." 1
    sleep 1
    ddev start
    txt "downloading WordPress" b
    sleep 1
    wp_dw
    if [[ !  -f "wp-config.php" ]]; then
        txt "Creating wp-config" b
        sleep 1
        ddev wp config create --dbname=db --dbuser=db --dbpass=db --dbhost=db
    fi
    txt "Installing..." y
    sleep 1
    ddev wp core install --url="$url" --title="$title" --admin_user="$wpuser" --admin_password="$wppw" --admin_email="$wpemail"
    if [[ -f "wp-config.php" ]]; then
        wp_block_se
        htaccess
        wp_git
        wp_license_plugins "ACF_PRO"
        wp_license_plugins "WPMDB"
        wp_rights
    fi
}
