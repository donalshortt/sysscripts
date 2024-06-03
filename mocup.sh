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

    # Launching tabs with appropriate commands and keeping the shell open
    kitten @ launch --type=tab --tab-title "Front" --keep-focus sh -c 'cd /home/donal/projects/mocf && git pull && nvim; exec $SHELL'
    kitten @ launch --type=tab --tab-title "Back" --keep-focus sh -c 'cd /home/donal/projects/mocb && git pull && nvim; exec $SHELL'
    kitten @ launch --type=tab --tab-title "Parser" --keep-focus sh -c 'cd /home/donal/projects/mocp && git pull && nvim; exec $SHELL'
	kitten @ launch --type=tab --tab-title "Savefile" --keep-focus sh -c 'cd "/home/donal/.local/share/Paradox Interactive/Europa Universalis IV/save games" && nvim mp_autosave.eu4; exec $SHELL'

    # Launching Kitty with a specific layout and running commands, keeping the shell open
    kitty -o allow_remote_control=yes -o enabled_layouts=tall sh -c \
        'kitten @ launch --type=tab --tab-title "Front" --keep-focus sh -c "cd /home/donal/projects/mocf && npm run dev; exec $SHELL" && \
         kitten @ launch --type=tab --tab-title "Back" --keep-focus sh -c "cd /home/donal/projects/mocb && nodemon app.js; exec $SHELL" && \
         kitten @ launch --type=tab --tab-title "Parser" --keep-focus sh -c "cd /home/donal/projects/mocp && cargo run; exec $SHELL"' &
}

main "${@}"

exit 0
