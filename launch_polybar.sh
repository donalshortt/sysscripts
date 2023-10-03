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
        case $HOSTNAME in
			hi)
				polybar --reload -q left -c /home/donal/.files/polybar/config.ini &
				polybar --reload -q centre -c /home/donal/.files/polybar/config.ini &
				polybar --reload -q right -c /home/donal/.files/polybar/config.ini &
				;;
			hoi)
				polybar --reload -q top -c /home/donal/.files/polybar/config_laptop.ini &
				polybar --reload -q bottom -c /home/donal/.files/polybar/config_laptop.ini &
				;;
		esac
    fi
}

main "${@}"

exit 0
