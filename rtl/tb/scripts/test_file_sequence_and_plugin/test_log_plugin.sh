#!/bin/bash

function print_in_green {
    echo -e "\E[32m $1 \E[0m"
}

function print_in_red {
    echo -e "\E[31m $1 \E[0m"
    exit 1
}

function get_address_from_execlog {
    eval "$2='$(echo $1 | cut -d "\"" -f 3 | cut -d "," -f 3)'"
}

function get_type_op_from_execlog {
    eval "$2='$(echo $1 | cut -d "\"" -f 3 | cut -d "," -f 2)'"
}

function get_type_op_from_my_plugin {
    eval "$2='$(echo $1 | cut -d " " -f 3)'"
}

function get_address_from_my_plugin {
    eval "$2='$(echo $1 | tr -s " " | cut -d " " -f 5 | cut -d "=" -f 2)'"
}

function get_size_from_my_plugin {
    eval "$2='$(echo $1 | tr -s " " | cut -d " " -f 6 | cut -d "=" -f 2)'"
}

function get_size_from_execlog {

    size=$(echo $1 | tr -s " " | cut -d "\"" -f 2 | cut -d " " -f 1)
    important_letter=${size:1:1}
    if [[ $important_letter = "d" ]]
    then
        size_int=3
    fi

    if [[ $important_letter = "w" ]]
    then
        size_int=2
    fi
    
    if [[ $important_letter = "h" ]]
    then
        size_int=1
    fi
    if [[ $important_letter = "b" ]]
    then
        size_int=0
    fi

    eval "$2=$size_int"
}

if [[ $# -ne 2 ]]
then 
    echo "usage : <log de notre plugin en ascii non compresse> <log du plugin execlog>"
    exit 1
fi
my_log=$1
exec_log=$2

nb_ligne_us=$(cat $my_log | wc -l) 
nb_ligne_them=$(cat $exec_log | wc -l)
if [[ $nb_ligne_us -ne $nb_ligne_them ]]
then
    print_in_red "pas le même nombre de ligne"
    exit 1
else
    print_in_green "bon nombre de lignes"
fi

while read -u 5 line_us
do read -u 6 line_them
    
    get_address_from_execlog "$line_them" adress_exec_log
    get_type_op_from_execlog "$line_them" type_op_exec_log
    get_address_from_my_plugin "$line_us" adress_my_plugin
    get_type_op_from_my_plugin "$line_us" type_op_my_plugin
    get_size_from_my_plugin "$line_us" size_my_plugin
    get_size_from_execlog "$line_them" size_execlog
    if [[ $adress_exec_log -ne $adress_my_plugin ]]
    then
        print_in_red "différence d'adresses"
    fi
    if [[ $type_op_exec_log -ne $type_op_my_plugin ]]
    then
        print_in_red "différence de type"
    fi
    if [[ $size_my_plugin -ne $size_execlog ]]
    then
        print_in_red "différence de taille"
        echo $size_execlog $size_my_plugin
    fi

done 5<${my_log} 6<${exec_log}


print_in_green "C'est fini"
exit 0
