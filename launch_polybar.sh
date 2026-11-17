#!/usr/bin/env bash

IS_WORK=$(xrandr | grep "DP-2 connected")
HOSTNAME=$(hostname)

usage()
{
	echo "Configures polybar based upon the work environment (home || office)"
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
        case $HOSTNAME in
			hi)
				polybar --reload -q left -c /home/donal/.files/polybar/config.ini &
				polybar --reload -q centre -c /home/donal/.files/polybar/config.ini &
				polybar --reload -q right -c /home/donal/.files/polybar/config.ini &
				;;
			hoi)
				polybar --reload -q centre -c /home/donal/.files/polybar/config_laptop_basic.ini &
				;;
			donal-thinkpad)
				if [[ $IS_WORK != "" ]]
				then
					polybar --reload -q left -c /home/donal/.files/polybar/config_laptop_work.ini &
					polybar --reload -q right -c /home/donal/.files/polybar/config_laptop_work.ini &
				else
					polybar -l info --reload -q left -c /home/donal/.files/polybar/config_laptop_wfh.ini &
					polybar --reload -q centre -c /home/donal/.files/polybar/config_laptop_wfh.ini &
					polybar --reload -q right -c /home/donal/.files/polybar/config_laptop_wfh.ini &
				fi
				;;
		esac
    fi
}

main "${@}"

exit 0
