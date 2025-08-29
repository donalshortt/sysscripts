#!/bin/sh

EXTERNAL_DISPLAY=$(xrandr | grep "DP-1-3 connected")
IS_HOME=$(xrandr | grep "DP-1-1 connected")

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
			# layouts and rotation of monitors
            sh ~/.screenlayout/layout.sh
			;;

        hoi)
			if [[ $EXTERNAL_DISPLAY != "" ]]
			then
				if [[ $IS_HOME != "" ]]
				then
					sh /home/donal/.screenlayout/home.sh
				else
					sh /home/donal/.screenlayout/work.sh
				fi
			else
				sh /home/donal/.screenlayout/basic_laptop.sh
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
            bspc monitor HDMI-A-0 -d 1 2 3
            bspc monitor DisplayPort-0 -d 4 5 6
            bspc monitor DisplayPort-1 -d 7 8 9
            ;;
        hoi)
			if [[ $EXTERNAL_DISPLAY != "" ]]
			then			
				if [[ $IS_HOME != "" ]]
				then
					bspc monitor eDP-1 -d 1 2 3
					bspc monitor DP-1-3 -d 4 5 6
					bspc monitor DP-1-1 -d 7 8 9
				else
					bspc monitor eDP-1 -d 1 2 3
					bspc monitor DP-1-3 -d 4 5 6
					bspc monitor DP-1-2 -d 7 8 9
				fi
			else
				bspc monitor eDP-1 -d 1 2 3 4 5 6 7 8
			fi
			;;
        
		*) 
			echo "No special desktop configuration required"
            ;;
    esac
}


main "${@}"

exit 0
