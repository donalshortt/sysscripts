#!/bin/sh

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
        squidward) 
            xrandr --output HDMI-A-1 --mode 1920x1080 --rotate normal \
                --output HDMI-A-1 --primary --mode 1920x1080 --right-of HDMI-A-0 --rotate normal \
                --output DisplayPort-1 --mode 1920x1080 --right-of HDMI-A-1 --rotate right
            ;;

        hoi)
			connected=$(xrandr | grep "DP-1 connected" | grep -v "eDP-1")

			if [[ $connected != "" ]]
			then
				sh /home/donal/.screenlayout/uni.sh
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
        squidward)
            bspc monitor HDMI-A-0 -d 1 2 3
            bspc monitor HDMI-A-1 -d 4 5 6
            bspc monitor DisplayPort-1 -d 7 8 9
            ;;

        hoi)
			connected=$(xrandr | grep "DP-1 connected" | grep -v "eDP-1")

			if [[ $connected != "" ]]
			then
            	bspc monitor eDP-1 -d 5 6 7 8
				bspc monitor DP-1 -d 1 2 3 4
			else
				bspc monitor eDP-1 -d 1 2 3 4 5
			fi
			;;
        
		*) 
			echo "No special desktop configuration required"
            ;;
    esac
}


main "${@}"

exit 0
