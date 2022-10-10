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
            xrandr --output HDMI-1 --mode 1920x1080 --rotate normal \
                --output HDMI-2 --primary --mode 1920x1080 --right-of HDMI-1 --rotate normal \
                --output DP-2 --mode 1920x1080 --right-of HDMI-2 --rotate right
            ;;

        krustykrab)
            xrandr --output eDP-1 --mode 1920x1080 --rotate normal \
				--output DP-1 --mode 1920x1080 --rotate normal --above eDP-1
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
            bspc monitor HDMI-1 -d 1 2 3
            bspc monitor HDMI-2 -d 4 5 6
            bspc monitor DP-2 -d 7 8 9
            ;;

        krustykrab)
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
