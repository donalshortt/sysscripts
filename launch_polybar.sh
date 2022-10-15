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

	
	connected=$(xrandr | grep "DP-1 connected" | grep -v "eDP-1")

    # Needs some work to make it portable
    if type "xrandr"; then
        case $HOSTNAME in
			squidward)
				for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
            		MONITOR=$m polybar --reload -q top -c /home/donal/.files/polybar/config.ini &
        		done
				;;
			krustykrab)
				for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
            		MONITOR=$m polybar --reload -q top -c /home/donal/.files/polybar/configlaptop.ini &
				done
				;;
		esac
    else
        polybar --reload -q main -c /home/donal/.files/polybar/config.ini &
    fi

    polybar --reload -q main -c /home/donal/.files/polybar/config.ini &
}

main "${@}"

exit 0
