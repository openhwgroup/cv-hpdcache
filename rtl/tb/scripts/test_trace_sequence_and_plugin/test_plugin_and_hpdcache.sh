#!/bin/bash

function print_in_green {
    echo -e "\E[32m $1 \E[0m"
}

function print_in_red {
    echo -e "\E[31m $1 \E[0m"
    exit 1
}

function get_address_from_execlog {
    eval "$2='$(echo $1 | cut -d'/' -f 3 | cut -d "=" -f 2 | cut -d "x" -f 2)'"
}

function get_type_op_from_execlog {
    eval "$2='$(echo $1 | cut -d'/' -f 4)'"
}

function get_size_from_execlog {
    eval "$2='$(echo $1 | cut -d'/' -f 9)'"
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


if [[ $# -ne 2 ]]
then 
    echo "usage : <trace of our plugin in ascii not compressed> <log of hpdcache>"
    exit 1
fi
my_log=$1
exec_log=$2

nb_ligne_us=$(cat $my_log | wc -l) 
nb_ligne_them=$(cat $exec_log | grep SB.NB_CORE_REQ | cut -d':' -f 2)
if [[ $nb_ligne_us -ne $nb_ligne_them ]]
then
    print_in_red " not the same number of lines"
    exit 1
else
    print_in_green  "same number of lines"
fi
counter=0
tempfile=$(mktemp)
cat $exec_log | grep CORE_REQ | grep -v SB.NB_CORE_REQ > $tempfile
while read -u 5 line_us
do read -u 6 line_them
    
    get_address_from_execlog "$line_them" adress_exec_log
    get_type_op_from_execlog "$line_them" type_op_exec_log
    get_size_from_execlog "$line_them" size_execlog
    get_address_from_my_plugin "$line_us" adress_my_plugin
    get_type_op_from_my_plugin "$line_us" type_op_my_plugin
    get_size_from_my_plugin "$line_us" size_my_plugin
    if [[ $((16#$adress_exec_log)) -ne $adress_my_plugin ]]
    then
        print_in_red "diff on address at line $counter :line plugin $line_us line cache $line_them"
    fi
    if [[ $type_op_exec_log -ne $type_op_my_plugin ]]
    then
        print_in_red "diff on type at line $counter :line plugin $line_us line cache $line_them"
    fi
    if [[ $size_my_plugin -ne $size_execlog ]]
    then
        print_in_red "diff on size at line $counter :line plugin $line_us line cache $line_them"
        echo $size_execlog $size_my_plugin
    fi
    counter=`expr $counter + 1`

done 5<${my_log} 6<$tempfile

rm $tempfile

print_in_green "Test finish"
exit 0
