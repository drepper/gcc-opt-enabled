#!/bin/bash
# set -x
nr=${#*}

if [ -t 1 ]; then
    redfg="\e[31;1m"
    redbg="\e[41;30;1m"
    greenfg="\e[32m"
    greenbg="\e[42;30;1m"
    bluebg="\e[44;30;1m"
    off="\e[0m"
    disa="\e[9;2m"
else
    redbg=""
    greenbg=""
    bluebg=""
    off=""
fi
ena=""

LANG=C
LC_ALL=C

nostr="✘"
nostrlen=${#nostr}
yesstr="✔"
yesstrlen=${#yesstr}

w=8

declare -a flags=(0 g 1 s 2 3 fast)

check_flag() {
    local fl="$1"
    declare -i i
    for i in $(seq 0 $((${#flags[*]} - 1))); do
        if [ "$fl" == ${flags[$i]} ]; then
            return
        fi
    done
    printf "Error: Unknown flag %s\n" "$fl"
    exit 1
}

print_state() {
    local s="$1"
    local l="$2"
    local w="$3"
    local d="$4"
    if [ "$s" == '[enabled]' ]; then
        printf "%b %*s %b" "$greenbg" "$w" "O$l" "$off "
    elif [ "$s" == '[disabled]' ]; then
        printf "%b %*s %b" "$redbg" "$w" "O$l" "$off "
    elif [ "$d" -eq 2 ]; then
        printf "%b%*s%b" "$greenbg" $(($w + 2)) "$s" "$off "
    else
        printf "%b%*s%b" "$redbg" $(($w + 2)) "$s" "$off "
    fi
}

helpdummy='help-dummy.o'
compiler() {
    local level="$1"
    local hasdummy=0
    if [ -f $helpdummy ]; then
        hasdummy=1
    fi
    ${CC:-gcc} -c -Q -O$level --help=optimizers |
    sed '/^[[:blank:]]*[^-[:blank:]]/d;/^[[:blank:]]*-[^f]/d;/^[[:blank:]]*$/d;s/=/ /' |
    sort |
    awk 'BEGIN { noopt["-fopt-info"]=1; noopt["-fshort-wchar"]=1; noopt["-fsave-optimization-record"]=1; noopt["-fpack-struct"]=1; noopt["-fstack-check"]=1; noopt["-flive-patching"]=1 } { if (NF>1 && noopt[$1] == "") { if (prev != "" && prev != $1) print(prevline); else { if (val == "[disabled]" || $2 == "[enabled]") next; } prev=$1; val=$2; prevline=$0 } } END { print(prevline) }'
    if [ $hasdummy -eq 0 -a -f $helpdummy ]; then
        rm $helpdummy
    fi
}

show_diff2() {
    local l="$1"
    local r="$2"
    check_flag "$l"
    check_flag "$r"

    paste -d ' ' <(compiler $l) <(compiler $r) |
    while read -r line; do
        set -- $line
        if [ "${#*}" -eq 4 ]; then
            opt="$1"
            local lstate="$2"
            local rstate="$4"
            if [ "$lstate" != "$rstate" ]; then
                print_state "$lstate" "$l" "$w" 1
                print_state "$rstate" "$r" "$w" 2
                printf "%s\n" "$opt"
            else
                if [ "$rstate" == '[disabled]' ]; then
                    printf "%*s%b%s%b\n" $((2 * ($w + 3))) "" "$disa" "$opt" "$off"
                else
                    printf "%*s%s\n" $((2 * ($w + 3))) "" "$opt"
                fi
            fi
        fi
    done
}

show_header() {
    local longest=$1
    local w=$2

    printf "%*s" $longest ""
    for o in ${flags[*]}; do
        printf "│%b %*s %b" "$bluebg" "$w" "$o" "$off"
    done
    printf "│\n"
}

format_value() {
    local w="$1"
    local v="$2"
    if [ "$v" == '[disabled]' ]; then
        printf " %b%*s%b " "$redfg" $(($w + nostrlen - 1)) "$nostr" "$off"
    elif [ "$v" == '[enabled]' ]; then
        printf " %b%*s%b " "$greenfg" $(($w + yesstrlen - 1)) "$yesstr" "$off"
    else
        printf "%b%*s%b" "$greenfg" $(($w + 2)) "$v" "$off"
    fi
}

show_all() {
    declare -a tempN
    for i in $(seq 0 $((${#flags[*]} - 1))); do
        eval "tempN[$i]=$(mktemp)"
    done
    trap "rm ${tempN[*]}" INT TERM

    declare -i i
    for i in $(seq 0 $((${#flags[*]} - 1))); do
        compiler ${flags[$i]} > ${tempN[$i]}
    done

    longest=$(awk '{ if (length($1) > max) max = length($1) } END { print(max) }' ${tempN[0]})

    paste -d ' ' ${tempN[*]} |
    {
        nl=0
        while read -r line; do
            set -- $line
            if [ "${#*}" -eq $((${#flags[*]} * 2)) ]; then
                if [ $(($nl % 20)) -eq 0 ]; then
                    show_header $longest $w
                fi
                printf "%*s" $longest $1

                for i in $(seq 2 2 $((${#flags[*]} * 2))); do
                    printf "│%s" "$(eval format_value $w \${$i})"
                done
                printf "│\n"
                nl=$(($nl + 1))
            elif [ "${#*}" -eq $((${#flags[*]} * 3)) ]; then
                if [ $(($nl % 20)) -eq 0 ]; then
                    show_header $longest $w
                fi
                printf "%*s" $longest $1

                for i in $(seq 3 3 $((${#flags[*]} * 3))); do
                    printf "│%s" "$(eval format_value $w \${$i})"
                done
                printf "│\n"
                nl=$(($nl + 1))
            fi
        done
    }
    rm ${tempN[*]}
}


if [ $nr -eq 0 ]; then
    show_all
elif [ $nr -eq 2 ]; then
    show_diff2 $1 $2
else
    sflags=''
    for o in ${flags[*]}; do
        if [ -z "$sflags" ]; then
            sflags='['
        else
            sflags="$sflags|"
        fi
        sflags="$sflags$o"
    done
    sflags="$sflags]"
    printf "Usage: %s\nor:    %s %s %s\n" "$0" "$0" "$sflags" "$sflags"
fi
