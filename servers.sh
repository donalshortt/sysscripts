# Shared by status.sh and wake.sh. Keep the inventory next to these scripts.
server_config=${BASH_SOURCE[0]%/*}/servers.local

load_servers() {
    local name ip mac extra
    if [[ ! -r $server_config ]]; then
        printf 'Create %s with one "name ip mac" row per server.\n' "$server_config" >&2
        return 1
    fi

    names=()
    ips=()
    macs=()
    while read -r name ip mac extra || [[ -n $name ]]; do
        [[ -z $name || $name == \#* ]] && continue
        if [[ -z $mac || -n $extra ]]; then
            printf 'Expected three fields for %s in %s.\n' "$name" "$server_config" >&2
            return 1
        fi
        names+=("$name")
        ips+=("$ip")
        macs+=("$mac")
    done < "$server_config"
}
