#!/bin/sh

usage()
{
    echo "This is how to use the script"
}

main()
{
    while getopts ":h" options; do
        case "${options}" in
        h)
            usage
            exit 0
            ;;
        esac
    done
    shift "$((OPTIND - 1))"

    killall -q polybar

    # Needs some work to make it portable

    if type "xrandr"; then
        for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
            MONITOR=$m polybar --reload -q top -c /home/donal/.files/polybar/config.ini &
        done
    else
        polybar --reload -q top -c /home/donal/.config/polybar/hack/config.ini &
    fi

    polybar --reload -q bottom -c /home/donal/.files/polybar/config.ini &
}

main "${@}"

exit 0
