#!/bin/bash

MYDIR="$(dirname "$0")"

#search for wp-sites
source "${MYDIR}/wphelpfuntions.sh" 

minor=0 #for wp plugin
sum="" #empty -> not single line commit
git=0 #use git?
yes_up="" #plugins
core_up="" #wp core
dir=./
wp="wp"         #where is wp-cli 
exclude=""      #plugins mot be updated
#argSites=0 
while [ $# -gt 0 ];do
    case $1 in
        -a|--all-sites)
            process_sites
            ;;
        -u)
            shift
            dbuser=$1
            ;;
        #-s)
            #shift
            #dirs="$1"
            #argSites=1
            #;;
        -s|--sites)
            shift
            process_dirs "$1"
            ;;
        -m|--minor)
            minor=1
            ;;
        -y|--yes-update)
            yes_up="true"
            ;;
        -c|--colors)
            colors
            ;;
        --sum) 
            sum="true"
            ;;
        -g)
            git=1
            ;;
        --gp|--git-push)
            git=2
            ;;
        -d)
            shift
            dir=$1
            ;;
        -h|--help)
            echo "wpupdate.sh [Options]"
            echo -e "--------------------\nOptions:"
            echo -e "-a: all\n-s: selected sites (if more than, separation with ,)"
            echo -e "-d: dir where the sites are\n-w: where is wpcli"
            echo -e "-g: stage,commit separate for every plugin\n--sum one commit for all\n-gp push to github the updated plugins\n-y: dont ask\n-c: colorize the output"
            exit
            ;;
        -w)
            shift
            wp=${1}
            ;;
        -x|--exclude-plugins)
            shift
            exclude="$1"
    esac
    #next argument -> e.g. $2 becomes $1, $3 becomes $2...
    shift
done


function update_core () { #update wordpress, only when there is a new version
    succes=$($wp core check-update 2>/dev/null| grep Success) #0 -> not found -> empty ,1 -> not 0 lenght
    #echo $?
    if [ -z "$succes" ]; then #$succes is length 0
        if [ -z "$yes_up" ]; then #no -y 
            echo -e "\nProceed with Core Update? [y]"
            read answer
        else #-y
            out "Updating..." 4
            answer="y"
        fi
        echo -e "\n--------------"
        if [ "$answer" = "y" ]; then
            $wp core update --locale=de_DE --skip-themes 
        else
            echo -e "${Blue}Nothin to be done${Color_Off}"
        fi
    fi
}

function gitwp(){
    #when --sum -> git commit -m is the begining of the var, which will be exec
    #later
    # git_com_sum="git commit"
    git_com_sum=""
    local plugins
    #commit
    local commit
    local i #plugins count
    i=0
    
    #cd to where repo is -> git commands
    cd wp-content  &>/dev/null || exit #just in case

    #avoid unnecessary merges
    out "updating repository..." 1
    sleep 1
    git pull 1>/dev/null

    for plugin in $($wp plugin list --update=available --field=name); do
        old_v=$("$wp" plugin get "$plugin" --field=version)
        out "Updating $plugin" 4
        sleep 1
        $wp plugin update "$plugin" 1>/dev/null
        #new version
        #new_v=$(cat wp-content/plugins/$plugin/$plugin.php | grep -Po "(?<=Version: )([0-9]|\.)*(?=\s|$)")
        new_v=$(wp plugin get "$plugin" --field=version)
        out "version: $old_v" 4

        if [ "$old_v" != "$new_v" ]; then
            plugins[$i]="$plugin: $old_v --> $new_v"
            out "staging changes..." 2
            sleep 1
            git add -A plugins/"$plugin" 1>/dev/null 
            out "Writing Commit:" 2
            out "chore: update plugin ${plugins[$i]}" 4
            # if one commit for all updates -> skip commit here and add em to a variable $git_com_sum
            commit="plugin ${plugins[$i]}"
            if [ -z "$sum" ] ; then # separated commit for every plugin
                git commit -m "chore: update $commit" 1>/dev/null
            else
                git_com_sum="$git_com_sum $i. \"$commit\""
            fi
            ((i++)) #increment c-style
        fi
    done
    #if one commit
    #
    sleep 1
    out "Summary:" 1
    out "$i plugins updated" 2
    if [ -z "$sum" ]; then
        for p in "${!plugins[@]}"; do #get  index of array -> !
            echo "${plugins[$p]}"
            echo "------------------------------"
        done
    else
        echo "chore: update plugin $git_com_sum"
        # git commit -m "chore: update $i plugins $(date "+%d-%m-%y")" -m "$git_com_sum"
        git commit -F- << EOF
chore: update $i plugins $(date "+%d-%m-%y")
--------------------------------

$(
for s in "${plugins[@]}"; do
    echo "$s"
done
)

EOF

    fi
    #if ! -y
        if [ -z "$yes_up" ]; then
            echo "Push to Github? [y]"
            read a
            if [ "$a" = "y" ]; then
                git push 1>/dev/null
            else
                echo "Not pushing"
            fi
        else
            #if -gp. only push
            [ "$git" -eq 2 ] && git push 1>/dev/null || out "Not pushing" 3
        fi

    sleep 2
    cd -  &>/dev/null
}

#is directories (-s) known?
#if [ "$argSites" -eq 0 ]; then
    #process_sites 
###else 
    #process_dirs "$dirs"
#fi

for site in "${sites[@]}"; do
    echo -e "${Cyan}================================\n\t$site\n================================"
    echo "entering $dir$site"
    cd "$dir$site"  &>/dev/null #change to root wp of site
    sleep 1
    echo -e "${Green}---------------\nChecking Site\n---------------"
    # is wp-site working?
    error=$($wp core check-update ) #the result of command -> 0 ok, 1 error. string goes to variable
    #echo $?
    if [ ! -z "$error" ]; then
     #   echo "$error"
        echo -e "${Green}Everything OK"
    else
        echo -e ${Red}"$error" 
        continue
   fi
    echo -e "${Yellow}---------------\nCheck Core  Update\n---------------${Color_Off}"
    #$wp core check-update
    update_core
    echo -e "${Yellow}---------------\nCheck Plugins\n---------------${Color_Off}"

   #upd_avail=$($wp core check-update 2>/dev/null| grep Success) #0 -> ok ,1 -> err in bash
   #plugins_up=$($wp plugin list --update=available > /dev/null 2>&1) #dont print anything
   #plugins_up=$($wp plugin list --update=available >/dev/null  2>&1 ) #dont print anything
   #plugins_up==$(wp plugin list --fields=name,update 2>/dev/null | grep available
   #plugins_up=$(wp plugin list --fields=name,update 2>/dev/null | grep available)
   # plugins_up=$($wp plugin list --fields=name,update 2>/dev/null | grep available)
   [[ $minor -eq 0 ]] && plugins_up=$($wp plugin list --fields=name,update 2>/dev/null | grep available) || plugins_up=$($wp plugin list --fields=name,update --minor 2>/dev/null | grep available)
   if [ -z "$plugins_up" ]; then #plugins_up has 0 length -> empty
       echo "Nothing to be updated!"
   else
       # if ! -y -> ask
       if [ -z "$yes_up" ]; then
           $wp plugin list --update=available
           echo -e "\nAll Plugins will be updated. Proceed? [y/n]"
           read answer
           echo -e "\n--------------"
           if [ "$answer" = "y" ]; then
             [ "$git" -ge 1 ] && gitwp ||  $wp plugin update --all
           else
               echo "Nothin done"
           fi
        else
            if [ "$git" -ge 1 ]; then
                gitwp
            else
                $wp plugin list --update=available
                out "Updating all plugins" 4
                $wp plugin update --all
            fi
        fi
    fi
    echo "back to $dir"
    cd -  &>/dev/null
done

