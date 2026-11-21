#!/usr/bin/env bash

source "$(dirname -- "$(realpath -- "$0")")/servers.sh" || exit 1

usage() {
    echo 'Usage: wake <server|all>'
    if [[ -r $server_config ]] && load_servers; then
        printf 'Servers:'
        printf ' %s' "${names[@]}"
        printf '\n'
    fi
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
if [[ $# != 1 ]]; then
    usage >&2
    exit 1
fi

load_servers || exit 1
target=${1,,}
if [[ $target == all ]]; then
    result=0
    for mac in "${macs[@]}"; do
        wakeonlan "$mac" || result=1
    done
    exit "$result"
fi

for i in "${!names[@]}"; do
    if [[ ${names[i],,} == "$target" ]]; then
        exec wakeonlan "${macs[i]}"
    fi
done
printf 'Unknown server: %s\n' "$1" >&2
usage >&2
exit 1
