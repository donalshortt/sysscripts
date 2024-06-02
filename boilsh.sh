#!/bin/sh

boilerplate='#!/bin/sh

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
}

main "${@}"

exit 0'

usage()
{
    echo "Creates a boilerplate shellscript file at location specified"
    echo "Usage: ${0} [OPTIONS] LOCATION"
}

main()
{
    while getopts \":h\" options; do
        case \"${options}\" in
        h)
            usage
            exit 0
            ;;
        esac
    done
    shift "$((OPTIND - 1))"

    touch "${1}"
    echo "${boilerplate}" > "${1}"
    chmod +x "${1}"
}

main "${@}"

exit 0
