#!/bin/sh

usage()
{
    echo "wgc -m <COMMIT-MESSGE>"
}

main()
{
    while getopts ":hm:" options; do
        case "${options}" in
        h)
            usage
            exit 0
            ;;
		m)
			MESSAGE="$OPTARG"
			;;
		esac
    done
    shift "$((OPTIND - 1))"

	if [ -z "$MESSAGE" ]; then
		echo "No message provided. Please provide a commit message."
		exit 1
	fi

	format
}

format()
{
	FILES=$(git diff --cached --name-only)
	/home/donal/work/formatter/bin/format.sh -s /home/donal/work/formatter/Default.xml $FILES
	git commit -m "$MESSAGE" 
}

main "${@}"

exit 0
