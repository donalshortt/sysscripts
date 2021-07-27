usage()
{
    echo "Changes the background depending on the BSPWM desktop"
    echo "Will search for backgrounds under ~/pictures/wallpapers"
    echo "Wallpapers should be named [desktop name].jpg"
    echo "Call me with sxhkd"
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

    current_desktop=$(bspc query -D -d focused --names)
    feh --bg-scale ${HOME}/pictures/wallpapers/${current_desktop}.jpg
}

main "${@}"

exit 0
