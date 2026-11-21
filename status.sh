#!/usr/bin/env bash

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    echo 'Checks whether the configured servers are powered on.'
    exit 0
fi

source "$(dirname -- "$(realpath -- "$0")")/servers.sh" || exit 1
load_servers || exit 1
for i in "${!names[@]}"; do
    if ping -c 1 -W 1 -- "${ips[i]}" >/dev/null 2>&1; then
        printf '\033[1;32m✔ %s (%s) is online\033[0m\n' "${names[i]}" "${ips[i]}"
    else
        printf '\033[1;31m✖ %s (%s) is offline\033[0m\n' "${names[i]}" "${ips[i]}"
    fi
done
