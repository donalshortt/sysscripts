#!/bin/sh

usage()
{
    echo "Creates symbolic links for dotfiles so they can all be stored in a single directory"
    echo "Requires .files to be present in the home directory"
}

linkfiles()
{
    if [ -e "/home/donal/.config/bspwm" ]; then
	    ln -sf /home/donal/.files/bspwmrc /home/donal/.config/bspwm/bspwmrc
	    echo "Linked bspwmrc"
    fi

    if [ -e "/home/donal/.config/sxhkd" ]; then
	    ln -sf /home/donal/.files/sxhkdrc /home/donal/.config/sxhkd/sxhkdrc
	    echo "Linked sxhkdrc"
    fi

    if [ -e "/home/donal/.config/polybar" ]; then
	    ln -sf /home/donal/.files/polybar_config /home/donal/.config/polybar/config
	    echo "Linked polybar"
    fi

    if [ ! -e "/home/donal/.config/nvim" ]; then
	    mkdir /home/donal/.config/nvim
	    ln -s /home/donal/.files/init.vim /home/donal/.config/nvim/init.vim
	    echo "Linked nvim"
    fi

    ln -sf /home/donal/.files/coc-settings.json /home/donal/.config/nvim/coc-settings.json
    echo "Linked Coc settings"

    ln -sf /home/donal/.files/kitty.conf /home/donal/.config/kitty/kitty.conf
    echo "Linked kitty"

    ln -sf /home/donal/.files/zshrc /home/donal/.zshrc
    echo "Linked zshrc"

    ln -sf /home/donal/.files/zsh_aliases /home/donal/.zsh_aliases
    echo "Linked zsh aliases"
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

    linkfiles

    echo "Done!"
}

main "${@}"

exit 0
