#!/bin/sh
# Installe l'extension GNOME Shell de Paros pour l'utilisateur courant et l'active.
# Sous Wayland, GNOME ne charge une nouvelle extension qu'à l'ouverture de
# session : se déconnecter puis se reconnecter après l'installation.
set -e
uuid="paros@paros.local"
target="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
mkdir -p "$target"
cp "$(dirname "$0")/$uuid/metadata.json" "$(dirname "$0")/$uuid/extension.js" "$target/"
if gnome-extensions enable "$uuid" 2>/dev/null; then
	echo "Extension activée."
else
	# Pas encore vue par GNOME Shell : l'inscrire dans la liste des extensions actives.
	current=$(gsettings get org.gnome.shell enabled-extensions)
	case "$current" in
		*"$uuid"*) ;;
		"@as []") gsettings set org.gnome.shell enabled-extensions "['$uuid']" ;;
		*) gsettings set org.gnome.shell enabled-extensions "${current%]}, '$uuid']" ;;
	esac
	echo "Extension installée. Déconnexion puis reconnexion nécessaires pour la charger."
fi
