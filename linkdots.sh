#!/bin/sh

usage()
{
    echo "Creates symbolic links for dotfiles so they can all be stored in a single directory"
    echo "Requires .files to be present in the home directory"
}

linkfiles()
{
	ln -sf /home/donal/.files/bspwmrc /home/donal/.config/bspwm/bspwmrc
	echo "Linked bspwmrc"

	ln -sf /home/donal/.files/sxhkdrc /home/donal/.config/sxhkd/sxhkdrc
	echo "Linked sxhkdrc"

	ln -sf /home/donal/.files/polybar /home/donal/.config/polybar
	echo "Linked polybar"

	ln -sf /home/donal/.files/nvim/ /home/donal/.config/
	echo "Linked nvim"

    ln -sf /home/donal/.files/kitty.conf /home/donal/.config/kitty/kitty.conf
    echo "Linked kitty"

    ln -sf /home/donal/.files/zshrc /home/donal/.zshrc
    echo "Linked zshrc"

    ln -sf /home/donal/.files/zsh_aliases /home/donal/.zsh_aliases
    echo "Linked zsh aliases"

    ln -sf /home/donal/.files/rofi/ /home/donal/.config/
    echo "Linked rofi config"

	ln -sf /home/donal/.files/lazygit.yml /home/donal/.config/lazygit/config.yml
	echo "Linked lazygit config"

	ln -sf /home/donal/.files/ideavim /home/donal/.ideavim
	echo "Linked ideavim"
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
