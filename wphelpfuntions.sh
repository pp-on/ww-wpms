#!/bin/bash
#make functions available to be used
#in other scripts for maintaning more
#than one wordpress's sies in a web
#serv er or locally
#+----------------------------------+
#|      Functions                   |
#+----------------------------------+
#| colors()                         |
#+----------------------------------+
#| process_dirs()                   |
#| split $argument in sites names   |
#+----------------------------------+
#| searchwp()                       |
#| search for wp sites in $dir      |
#+----------------------------------+
#| list_wp_plugins()                |
#+----------------------------------+
#| print_sites()                    |
#+----------------------------------+
#| process_sites()                  |
#| add or not a wpsite to an array  |
#+----------------------------------+
#| os_detection()                   |
#| arg: 1 -> print OS
#+----------------------------------+
#| out () < text, typ of line       |
#| print text with line "-" or "="  |
#+----------------------------------+
#| txt () < text,color (b,c,g,r,y)  |
#| print text with color            | 
#+----------------------------------+
#| copy_plugins()< from             |
#| cp from/plug/in to array wp-sites|
#+----------------------------------+
#| wp_new_user()< Uname, pw, email  |
#+----------------------------------+
#| wp_rights                        |
#| change +w wp-content/uploads     |
#+----------------------------------+
#| git_log                          |
#+----------------------------------+
#| git_pull                         |
#+----------------------------------+
#| wp_debug                         |
#| add debug to wp-config           |
#| < current WP directory           |
#+----------------------------------+
#| wp_block_se ()                   |
#| Disable search engine indexing   |
#+----------------------------------+


colors(){
    # Reset
    Color_Off="\e[0m"       # Text Reset

    # Regular Colors
    Black="\e[30m"        # Black
    Red="\e[31m"          # Red
    Green="\e[32m"        # Green
    Yellow="\e[33m"       # Yellow
    Blue="\e[34m"         # Blue
    Purple="\e[35m"       # Purple
    Cyan="\e[36m"         # Cyan
    White="\e[37m"        # White

}
searchwp() {
    local site #only valid within this function
    for site in $(ls -d "$dir"*/); do
        if [ -d "$site/wp-content/" ]; then
            site=${site##"$dir"}
            [ "$verbose" = "1" ] && sleep 1 && echo "Found $site"
            sites+=("$site"); (( anzahl++ ))
        fi
    done

}
# https://tldp.org/LDP/abs/html/string-manipulation.html
# # , ## -> remove shortest (longest) FRONT -> ${abc#a} = bc
# % , %% -> remove shortest (longest) BACK -> ${abc%a} = NULL
process_dirs(){ #split directories -> a,b,c sites[0]=a, sites[1]=b, sites[2]=c
    local dirs="$1"
    local site #only valid within this function
    local site
    if [ ! -z "$dirs" ]; then #if something did go wrong
        while [ "$dirs" != "$site" ]; do
            site=${dirs%%,*} #first element -> dirs=a,b,c site=a  
            dirs=${dirs#"$site",} #new string w/o first element -> b,c
            while [ ! -d "$dir$site" ]; do #it has to be a correct name
                echo "$dir$site not found! Tipe in [n]ew name or [c]ontinue..."
                read a
                if [ "$a" = "n" ]; then
                    echo "----------------"
                    echo "enter new name: "
                    read site
                    echo "----------------"
                elif [ "$a" = "c" ]; then
                    site="" #first element is empty
                    break #stop loop
                else
                    continue #startover
                    #break
                fi
            done
            [ ! -z "$site" ] && sites+=("$site") #copy into array
            

        done
    fi
}
list_wp_plugins(){
    local i
    local a

    for i in "${sites[@]}"; do
        echo -e "${Green}----------------"
        cd "$dir$i"  &>/dev/null #change to root wp of site
        echo -e $i
        echo -e "----------------${Color_Off}"
        $wp plugin list --color
        echo -e "${Yellow} $($wp plugin list --format=count) Plugins"
        echo -e "${Purple}To continue press any key and enter...${Color_Off}"
        read a
        cd -  &>/dev/null #change back to orignal dir 
    done
}
print_sites(){
    local i
    echo -e "${Yellow}----------------"
    sleep 1
    echo -e "${#sites[@]} selected websites" 
    echo "----------------"
    for i in "${sites[@]}"; do
        echo -e ${Cyan}$i
    done
    echo -e "${Yellow}----------------"
}
# w/o arguments
[ "$print" = "1" ] && print_sites

# -t -> how many found 
[ "$total" = "1" ] && echo -e "\n=======\nTotal $anzahl WP-Sites"

process_sites(){ #optional: dir
    local dir #avoid misstakes
    [ -z "$1" ] && dir="./" || dir="$1" 
    local site #only valid within this function
    if [ -z "$sites" ]; then #if no folders aka Websites were pass as argument
        for site in $(ls -d $dir*/); do
            if [ -d "$site/wp-content/" ]; then
                seite=${site##"$dir"}
                echo "Found $seite"
                echo "Should it be processed? [y] "
                read answer
                echo -e "\n--------------"
                if [ "$answer" = "y" ]; then
                    #only names
                    site=${site#"$dir"}
                    site=${site%%/}
                    sites+=("$site")
                fi
            fi
        done
    fi
}
os_detection(){
    local OS
    local UNAME
    UNAME="$(uname -a)"
    #linux or wsl , gitbash empty
    #OS="$(cat /etc/os-release | grep '^'NAME'' | cut -d '=' -f2)"

case $( echo "${UNAME}" | tr '[:upper:]' '[:lower:]') in
  linux)
      cOS="$(cat /etc/os-release | grep '_NAME' | cut -d '=' -f2)"
      ;;
  *wsl*|*buntu*)
      cOS="$(cat /etc/os-release | sed -n '1p' | cut -d '"' -f2)"
      #cOS="WSL"
#      hostname="127.0.0.1"
    ;;
  msys*|cygwin*|mingw*)
    # or possible 'bash on windows'
    cOS="Git_Bash"
    ;;
  *)
    ;;
esac
    #kernel version
    UNAME="$(uname -r)"

    [[ "$1" -eq 1 ]] && out "$cOS" 1
}
out() {
    local text="$1"
    local color_key="${2,,}"  # Convert to lowercase for consistency
    local line_char="${3:--}" # Default to '-' if not provided
    local color="$Cyan"       # Default color
    local total_width=60      # Total width of the output line

    # Choose color based on keyword
    case "$color_key" in
        1 | warning) color="$Yellow" ;;
        3 | error)   color="$Red" ;;
        4 | good)    color="$Green" ;;
        *)           color="$Cyan" ;;
    esac

    # Format label with padding
    local label=" ${text} "
    local label_length=${#label}
    local side_length=$(( (total_width - label_length) / 2 ))

    # Build full line
    local line=""
    for ((i = 0; i < total_width; i++)); do
        line+="$line_char"
    done

    # Build centered label line
    local centered_line=""
    for ((i = 0; i < side_length; i++)); do
        centered_line+="$line_char"
    done
    centered_line+="$label"
    while [[ ${#centered_line} -lt $total_width ]]; do
        centered_line+="$line_char"
    done
    # Output
    echo -e "${color}${line}"
    echo -e "${centered_line}"
    echo -e "${line}${Color_Off}"
}

txt () {
    local line
    line="$1"
    case $2 in
        y)  
            line="${Yellow}${line}"
            ;;
        r)
            line="${Red}${line}"
            ;;
        c)
            line="${Cyan}${line}"
            ;;
        b)
            line="${Blue}${line}"
            ;;
        g)
            line="${Green}${line}"
            ;;
    esac

    echo -e "${line}${Color_Off}"
}
assign_env(){
    declare -n var="$1" #string $1 will be the name of var
    value=$2
    #echo ${!var} #print the name of var
    out $var 1
    out "${!var}" 2 #print the name of var
    var="$value"
    out $var 1
}
copy_plugins(){ #from
    local target
    local plugin_name
    local i #avoid stupid errors
    from="$1" #full path w/o / at the end !!!
    #plugin_name="${from%%/*}"
    plugin_name=$(basename "$from")


    for i in "${sites[@]}"; do
        out "${i}" 1
        target="${dir}${i}/wp-content/plugins/"
        if [ -d "${dir}${target}${plugin_name}" ]; then
            out "${plugin_name} already exists" 3
        else
            out "copying ${plugin_name}from ${from}" 2
            cp "$from" "${dir}$target" -r
            sleep 1
            echo "Done"
            out "Activating $plugin_name" 2
            cd "${dir}${i}"
            $wp plugin activate $plugin_name
            cd -  &>/dev/null #change back to orignal dir 
        fi
    done
}
remove_plugins() {
    local plugin_name
    local i

    plugin_name="$1"
    for i in "${sites[@]}"; do
        out "$i" 1
        cd ${i}/wp-content/plugins
        if [ -d "$plugin_name" ]; then
            out "Removing $plugin_name" 2
             "$wp" plugin delete "$plugin_name"
            sleep 1
            echo "Done"
#            "$wp" plugin list
        fi
        if [ "$2" -eq 1 ]; then #pause, when 2 args
            echo -e "${Purple}To continue press any key and enter...${Color_Off}"
            read a
        fi
        cd -  &>/dev/null #change back to orignal dir 
    done
}
wp_new_user(){ #user,passw,email
    out "creating user ${1}"
    sleep 1
    for i in "${sites[@]}"; do
        out "$i" 1
        cd "$i"
        "$wp" user create "$1" "$3" --user_pass="$2" --role=administrator
        cd -  &>/dev/null #change back to orignal dir 
    done
}

wp_update() { #what 
     plugin="$1"
    path="${1}"
    countdown=4
    for i in "${sites[@]}"; do
        out "$i" 1
        out "check $plugin if there is one, update it"
            cd $i #for wpcli -> into site
        #installed=$(wp plugin status $plugin | grep Error)
        #if [ -z "$installed" ]; then #found -> empty
        if [[ "$plugin" != "all" ]]; then
           out "found $plugin! Updating..." 2
            $wp plugin update $plugin
       else
            out "updating all plugins" 2
            $wp plugin list --update=available
            while [ "$countdown" -ge 0 ]; do
                out "$countdown" 4
                sleep 1
                (( countdown-- ))
            done
            sleep
            $wp plugin update --all
        fi
            cd -  &>/dev/null #change back to orignal dir 
    done
}
wp_key_migrate(){
#    for i in "${sites[@]}"; do
#        out "$i" 1
        out "activating wp-migrate-db-pro" 2
        sleep 1
        echo "define( 'WPMDB_LICENCE', 'a8ff1ac2-3291-4591-b774-9d506de828fd');" >> ./wp-config.php
#    done
   out "activating pull setting" 4
   $wp migrate setting update pull on
}
wp_key_acf_pro (){
    out "activating acf pro" 2 
    sleep 1
    echo "define( 'ACF_PRO_LICENSE', 'b3JkZXJfaWQ9NzQ3MzF8dHlwZT1kZXZlbG9wZXJ8ZGF0ZT0yMDE2LTAyLTEwIDE1OjE1OjI4' );" >> ./wp-config.php
#    $wp eval 'acf_pro_update_license("b3JkZXJfaWQ9NzQ3MzF8dHlwZT1kZXZlbG9wZXJ8ZGF0ZT0yMDE2LTAyLTEwIDE1OjE1OjI4");'
    $wp plugin list
}
wp_license_plugins () { #LicensePlugin 
    local plugin
    local license
    plugin="$1" #ACF_PRO or WPMDB
    if [[ "$plugin" == "ACF_PRO" ]]; then
        #license=$(cat <<-EOM
        read -r -d '' license <<- EOM
if (!defined('${plugin}_LICENSE')){
    define( 'ACF_PRO_LICENSE', 'b3JkZXJfaWQ9NzQ3MzF8dHlwZT1kZXZlbG9wZXJ8ZGF0ZT0yMDE2LTAyLTEwIDE1OjE1OjI4' );
}
EOM
#EOM has to be exact like the upper one (<<-OEM), that means w/o spaces after or
#before. '-' means keep indentation
    else
        read -r -d '' license <<- EOM
if (!defined('${plugin}_LICENSE')){
    define( 'WPMDB_LICENCE', 'a8ff1ac2-3291-4591-b774-9d506de828fd');
}
EOM
    fi
    out "activating ${plugin}_LICENSE" 2
    sleep 1
    #append license ony when not found
    #grep -q "$plugin" wp-config.php || sed -i "$ a $license" ./wp-config.php
    grep -q "$plugin" wp-config.php && echo "${plugin}_LICENSE already exists" || echo "$license" >> ./wp-config.php && sleep 1 && out "done" 4
}
install_plugins (){
    plugin_name="$1"

    for i in "${sites[@]}"; do
        out "${i}" 1
        cd "${dir}${i}"
        target="wp-content/plugins/"
        if [ -d "${target}${plugin_name}" ]; then
            out "${plugin_name} already exists" 3
        else
            $wp plugin install "$plugin_name"
            $wp plugin activate "$plugin_name"
        fi
        cd -
    done
}

# basic htaccess for SEO
htaccess() {
    d1=$(dirname $PWD)
    d1=${d1##*/}
    d2=${PWD##*/} #trim all dirs before - same as basename
    target_directory="/$d1/$d2"

    out "creating .htaccess with $target_directory" 2
cat  << EOF > .htaccess
<IfModule mod_rewrite.c>
RewriteEngine On
# force https 
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase $target_directory
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . $target_directory/index.php [L]
</IfModule>	
EOF
sleep 1
chmod 777 .htaccess -v
echo "Done"
}
#hide errors
wp_hide_errors(){
    out "hiding errors" 4
	#remove define(WP-DEBUG', false);
    sed -i '/DEBUG/d' wp-config.php
    cat <<EOF >> wp-config.php
ini_set('display_errors','Off');
ini_set('error_reporting', E_ALL );
define('WP_DEBUG', false);
define('WP_DEBUG_DISPLAY', false);
EOF
}
#activate debug
wp_debug(){ #on/off
    local switch="$1"
    #where is wp-config.php
    local file_path="$wp_config_path"
    if [ "$switch" = "off" ]; then
        wp config set --raw WP_DEBUG false
        # if grep -Fxq "define('WP_DEBUG', true);" "$file_path"; then
            # sed -i "s/define('WP_DEBUG', true);/define('WP_DEBUG', false);/g" wp-config.php
            wp config set --raw WP_DEBUG_LOG false
        # fi
        out "Debugging is off $wp_config_path" 4

    else
        wp config set --raw WP_DEBUG true
		wp config set --raw WP_DEBUG_LOG true
        wp config set --raw WP_DEBUG_DISPLAY false
        out "Debugging is on" 4
        # cat <<EOF >> wp-config.php
#         local debug_code
#         # debug_code="
#         read -r -d '' debug_code <<- EOM
#     out "adding WP DEBUG to wp-config" 2
#     # cat <<EOF >> wp-config.php
#     local debug_code
#     # debug_code="
#
#     read -r -d '' debug_code <<- EOM
# // Enable WP_DEBUG mode
# if ( !defined ('WP_DEBUG') ){
#     define( 'WP_DEBUG', true );
# }
#
# // Enable Debug logging to the /wp-content/debug.log file
# if ( !defined ('WP_DEBUG_LOG') ){
#     define( 'WP_DEBUG_LOG', true );
# }
#
# // Disable display of errors and warnings
# if ( !defined ('WP_DEBUG_DISPLAY') ){
#     define( 'WP_DEBUG_DISPLAY', false );
#     @ini_set( 'display_errors', 0 );
# }
#
# // Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
# if ( !defined ( 'SCRIPT_DEBUG' )) {
#     define( 'SCRIPT_DEBUG', true );
# }
# EOM
# # insert code into wp-config.php
#      # make file does exist
#      if [ -f "$file_path" ]; then
#         echo "inserting debug code into $file_path"
#         #remove define(WP-DEBUG', false);
#         sed -i "s/'WP_DEBUG', false/'WP_DEBUG', true/g" wp-config.php
#         echo "$debug_code" >> "$file_path"
#      else
#         echo "File not found"
#      fi
#
#     out "done" 4JJ
# }
# EOF
 


	fi #end if switchH
}
update_repo(){
    for i in "${sites[@]}"; do
        out "${i}" 1
        cd "${dir}${i}/wp-content"  &>/dev/null
        #avoid unnecessary merges
        out "updating repository..." 1
        sleep 1
        git pull 1>/dev/null
        cd -
    done
}
wp_rights(){
    for i in "${sites[@]}"; do
        #out "changing rights uploads ${i}" 1
        out "changing ownership ${i}"
        chown ossi:ossi "${dir}${i}/wp-content" -Rvf
        #rights for wpmdb
        chmod -Rv 777 "${dir}${i}/wp-content/uploads"
    done 
}
git_wp (){ # sucommand
    for i in "${sites[@]}"; do
    #for i in "${sites[@]}"; do
        out "${i}" 1
        cd "${dir}${i}/wp-content"  &>/dev/null
        case "$1" in
            pull)
                git pull
                ;;
            log)
                git log --graph --max-count=10
                ;;
        esac
        cd -
    done 
}
wp_block_se (){
    #for i in "${sites[@]}"; do
        #out "Disabling search engine indexing for $i "
        out "Disabling search engine indexing for $(basename $PWD) "
        $wp option update blog_public 0
    #done
}

wp_getCPT(){

    # Standardwerte setzen
    CPTS=""

    # Argumente parsen
    while getopts "c:" opt; do
      case $opt in
        c) CPTS="$OPTARG" ;;
        *) echo "Ungültige Option" >&2; exit 1 ;;
      esac
    done

    # Prüfen, ob CPTs angegeben wurden
    if [[ -z "$CPTS" ]]; then
      echo "Fehlende CPTs! Nutzung: $0 -c cpt1,cpt2,..."
      exit 1
    fi

    # SQL WHERE-Bedingung für die CPTs generieren
    CPTS_SQL=$(echo "$CPTS" | sed "s/,/','/g")
    CPTS_SQL="('$CPTS_SQL')"

    # Export CPTs
    wp db query "SELECT * FROM wp_posts WHERE post_type IN $CPTS_SQL" --allow-root > cpts.sql

    # Export Postmeta (benutzerdefinierte Felder)
    wp db query "SELECT * FROM wp_postmeta WHERE post_id IN (SELECT ID FROM wp_posts WHERE post_type IN $CPTS_SQL)" --allow-root >> cpts.sql

    # Export Taxonomien (Beziehungen zwischen CPTs und Taxonomien)
    wp db query "SELECT * FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $CPTS_SQL)" --allow-root >> cpts.sql

    # Export Taxonomie-Informationen
    wp db query "SELECT * FROM wp_term_taxonomy WHERE term_taxonomy_id IN (SELECT term_taxonomy_id FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $CPTS_SQL))" --allow-root >> cpts.sql

    # Export Begriffe (Terms)
    wp db query "SELECT * FROM wp_terms WHERE term_id IN (SELECT term_id FROM wp_term_taxonomy WHERE term_taxonomy_id IN (SELECT term_taxonomy_id FROM wp_term_relationships WHERE object_id IN (SELECT ID FROM wp_posts WHERE post_type IN $CPTS_SQL))))" --allow-root >> cpts.sql

    echo "Expo          rt abgeschlossen: cpts.sql"
}
