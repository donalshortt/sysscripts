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
		\?)
			echo "Error: Invalid option -$OPTARG"
			echo
			usage
			exit 1
			;;
		:)
			echo "Error: Option -$OPTARG requires an argument."
			echo
			usage
			exit 1
			;;
		esac
	done
	shift "$((OPTIND - 1))"

	gwtrm
}

main "${@}"

gwtrm() {
    emulate -L zsh
    local range_pattern='^([0-9]+)-([0-9]+)$'
    local issue_pattern='_([0-9]+)-'
    local MATCH MBEGIN MEND
    local -a match mbegin mend

    if (( $# != 1 )) || ! [[ $1 =~ $range_pattern ]]; then
        git worktree remove "$@"
        return
    fi

    local -i first=$(( 10#${match[1]} )) last=$(( 10#${match[2]} ))
    if (( first > last )); then
        print -u2 -- 'gwtrm: range must be in ascending order (e.g. 258-262).'
        return 1
    fi

    local git_dir candidate listing entry worktree main_worktree
    local -a git_dirs worktrees
    if ! git_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        # A parent directory may contain several worktrees of the same repo.
        for candidate in "$PWD"/*(N/); do
            [[ -e "$candidate/.git" ]] || continue
            git_dir=$(git -C "$candidate" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
            git_dirs+=("$git_dir")
        done
        git_dirs=("${(@u)git_dirs}")
        if (( ${#git_dirs} != 1 )); then
            print -u2 -- 'gwtrm: run inside a repository or a parent directory containing exactly one repository.'
            return 1
        fi
        git_dir=$git_dirs[1]
    fi

    # Keep the Git context valid even as linked worktrees are removed.
    listing=$(git --git-dir="$git_dir" worktree list --porcelain -z) || return
    for entry in "${(@0)listing}"; do
        [[ $entry == 'worktree '* ]] || continue
        worktree=${entry#worktree }
        if [[ -z $main_worktree ]]; then
            main_worktree=$worktree
            continue
        fi
        [[ ${worktree:t} =~ $issue_pattern ]] || continue
        if (( 10#${match[1]} >= first && 10#${match[1]} <= last )); then
            worktrees+=("$worktree")
        fi
    done

    if (( ${#worktrees} == 0 )); then
        print -u2 -- "gwtrm: no linked worktrees match $1."
        return 1
    fi
    for worktree in "${worktrees[@]}"; do
        if [[ ${PWD:A}/ == "${worktree:A}/"* ]]; then
            print -u2 -- 'gwtrm: change out of the selected worktree before removing this range.'
            return 1
        fi
    done

    local -i result=0
    for worktree in "${worktrees[@]}"; do
        print -r -- "Removing $worktree"
        git --git-dir="$git_dir" worktree remove -- "$worktree" || result=1
    done
    return $result
}

exit 0
