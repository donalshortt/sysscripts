#!/usr/bin/env bash

IS_WORK=$(xrandr | grep "DP-2 connected")
HOSTNAME=$(hostname)

usage()
{
    echo "Sets up monitor and desktop configuration for bspwm"
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

    configure_monitors
    configure_desktops

    bspc config remove_disabled_monitors true     
    bspc config remove_unplugged_monitors true
    bspc config merge_overlapping_monitors true 
}

configure_monitors()
{
    case $HOSTNAME in
        hi) 
            sh ~/.screenlayout/layout.sh
			;;

		hoi)
			sh /home/donal/.screenlayout/basic.sh
			;;
		donal-thinkpad)
			if [[ $IS_WORK != "" ]]
			then
				sh /home/donal/.screenlayout/work.sh
			else
				sh /home/donal/.screenlayout/wfh.sh
			fi
            ;;

        *) 
            echo "No special monitor configuration required"
            ;;
    esac
        

}

configure_desktops()
{
    case $HOSTNAME in
        hi)
            bspc monitor HDMI-0 -d 1 2 3
            bspc monitor DP-5 -d 4 5 6
            bspc monitor DP-2 -d 7 8 9
            ;;
		hoi)
			bspc monitor eDP-1 -d 1 2 3 4 5 6 7 8
			;;
		donal-thinkpad)
			if [[ $IS_WORK != "" ]]
			then
				bspc monitor DP-2 -d 1 2 3 4 5 6 7
				bspc monitor eDP-1 -d 8 9
			else
				bspc monitor eDP-1 -d 1 2 3
				bspc monitor DP-2-3 -d 4 5 6 
				bspc monitor DP-2-1 -d 7 8 9
			fi
			;;
        
		*) 
			echo "No special desktop configuration required"
            ;;
    esac
}


main "${@}"

exit 0
