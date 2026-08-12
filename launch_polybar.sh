#!/bin/sh

EXTERNAL_DISPLAY=$(xrandr | grep "DP-1-3 connected")
IS_HOME=$(xrandr | grep "DP-1-1 connected")

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
				if [[ $EXTERNAL_DISPLAY != "" ]]
				then
					if [[ $IS_HOME != "" ]]
					then
						polybar --reload -q left -c /home/donal/.files/polybar/config_laptop_wfh.ini &
						polybar --reload -q centre -c /home/donal/.files/polybar/config_laptop_wfh.ini &
						polybar --reload -q right -c /home/donal/.files/polybar/config_laptop_wfh.ini &
					else
						polybar --reload -q left -c /home/donal/.files/polybar/config_laptop_work.ini &
						polybar --reload -q centre -c /home/donal/.files/polybar/config_laptop_work.ini &
						polybar --reload -q right -c /home/donal/.files/polybar/config_laptop_work.ini &
					fi
				else
					polybar --reload -q centre -c /home/donal/.files/polybar/config_laptop_basic.ini &
				fi			
				;;
		esac
    fi
}

main "${@}"

exit 0
