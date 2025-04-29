#!/bin/sh

usage()
{
    echo "Creates symbolic links for dotfiles so they can all be stored in a single directory"
    echo "Requires .files to be present in the home directory"
}

linkfiles()
{
	ln -sf /home/$USER/.files/bspwmrc /home/$USER/.config/bspwm/bspwmrc
	echo "Linked bspwmrc"

	ln -sf /home/$USER/.files/sxhkdrc /home/$USER/.config/sxhkd/sxhkdrc
	echo "Linked sxhkdrc"

	ln -sf /home/$USER/.files/polybar /home/$USER/.config/polybar
	echo "Linked polybar"

	ln -sf /home/$USER/.files/nvim/ /home/$USER/.config/
	echo "Linked nvim"

    ln -sf /home/$USER/.files/kitty.conf /home/$USER/.config/kitty/kitty.conf
    echo "Linked kitty"

    ln -sf /home/$USER/.files/zshrc /home/$USER/.zshrc
    echo "Linked zshrc"

    ln -sf /home/$USER/.files/zsh_aliases /home/$USER/.zsh_aliases
    echo "Linked zsh aliases"
ln -sf /home/$USER/.files/rofi/ /home/$USER/.config/
    echo "Linked rofi config"

	ln -sf /home/$USER/.files/lazygit.yml /home/$USER/.config/lazygit/config.yml
	echo "Linked lazygit config"

	ln -sf /home/$USER/.files/xprofile /home/$USER/.xprofile
	echo "Linked xprofile"

	ln -sf /home/$USER/.files/ideavimrc /home/$USER/.ideavimrc
	echo "Linked ideavim"

	ln -sf /home/$USER/.files/gitignore /home/$USER/.gitignore
	echo "Linked gitignore"

	ln -sf /home/$USER/.files/launch_configurations/ /home/$USER/.local/share/warp-terminal/
	echo "Linked warp terminal launch configs"
}

main()
{
	USER="donal"

    while getopts ":hu:" options; do
        case "${options}" in
        h)
            usage
            exit 0
            ;;
		u)
			USER=${OPTARG}
			;;
        esac
    done
    shift "$((OPTIND - 1))"

	echo "USER IS $USER"

    linkfiles

    echo "Done!"
}

main "${@}"

exit 0
