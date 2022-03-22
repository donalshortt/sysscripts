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
            xrandr --output DP-1 --mode 1920x1080 --rotate normal \
                --output HDMI-2 --primary --mode 1920x1080 --right-of DP-1 --rotate normal \
                --output DP-2 --mode 1920x1080 --right-of HDMI-2 --rotate left
            ;;

        squilliam)
            # Set output to 1920x1080
            ;;

        *) echo "No special monitor configuration required"
            ;;
    esac
        

}

configure_desktops()
{
    case $HOSTNAME in
        squidward)
            bspc monitor DP-1 -d 1 4 7
            bspc monitor HDMI-2 -d 2 5 8
            bspc monitor DP-2 -d 3 6 9
            ;;

        *) echo "No special desktop configuration required"
            ;;
    esac
}


main "${@}"

exit 0
