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

	kitten @ launch --type=tab --tab-title "Front" --keep-focus zsh
	kitten @ launch --type=tab --tab-title "Back" --keep-focus zsh
	kitten @ launch --type=tab --tab-title "Parser" --keep-focus zsh
	echo "launched??"

}

main "${@}"

exit 0
