#!/bin/sh

usage()
{
    echo "wgc -m <COMMIT-MESSGE>"
	echo "options:"
	echo "  -h  Show this help message"
	echo "  -f  Format staged files before committing"
}

main()
{
	REPO_ROOT=$(git rev-parse --show-toplevel)
	STAGED=$(git diff --cached --name-only)
	FILES=()
	for file in $STAGED; do
		if [ -f "$REPO_ROOT/$file" ]; then
			FILES+="$REPO_ROOT/$file "
		fi
	done

    while getopts ":hm:f" options; do
        case "${options}" in
        h)
            usage
            exit 0
            ;;
		m)
			MESSAGE="$OPTARG"
			;;
		f)
			/home/donal/work/formatter/bin/format.sh -s /home/donal/work/formatter/Default.xml $FILES
			;;
		esac
    done
    shift "$((OPTIND - 1))"

	if [ -z "$MESSAGE" ]; then
		echo "No message provided. Please provide a commit message."
		exit 1
	fi

	for file in $FILES; do
		git add "$file"
	done

	BRANCH=$(git rev-parse --abbrev-ref HEAD)
	TICKET=$(echo "$BRANCH" | sed -E 's#^.*/([A-Za-z]+-[0-9]+).*$#\1#')
	COMMIT_MSG="[$TICKET] $MESSAGE"
	echo $MESSAGE
	echo $COMMIT_MSG

	git commit -m "$COMMIT_MSG" 
}

main "${@}"

exit 0
