#!/bin/sh

usage()
{
	echo "Toggle evremap config"
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
	
	set -e

	SERVICE="/usr/lib/systemd/system/evremap.service"

	if grep -q 'evremap_work\.toml' "$SERVICE"; then
		sudo sed -i 's/evremap_work\.toml/evremap.toml/' "$SERVICE"
		echo "Switched to evremap.toml"
	elif grep -q 'evremap\.toml' "$SERVICE"; then
		sudo sed -i 's/evremap\.toml/evremap_work.toml/' "$SERVICE"
		echo "Switched to evremap_work.toml"
	else
		echo "Could not determine current config"
		exit 1
	fi

	sudo systemctl daemon-reload
	sudo systemctl restart evremap.service
}

main "${@}"

exit 0
