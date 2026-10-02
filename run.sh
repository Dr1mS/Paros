#!/bin/sh
# Lance Paros.
# Depuis les sources si Godot est trouvé : variable GODOT_PATH (binaire Godot 4.7+),
# sinon "godot" dans PATH. À défaut, lance le binaire exporté par ./build.sh.
here="$(dirname "$0")"
# Pas de serveur de méthode de saisie : voir src/core/input_method.gd.
export XMODIFIERS=@im=none
godot="${GODOT_PATH:-godot}"
if command -v "$godot" >/dev/null 2>&1; then
	exec "$godot" --path "$here" "$@"
fi
if [ -x "$here/build/paros.x86_64" ]; then
	echo "Godot introuvable : lancement du binaire build/paros.x86_64 (état du dernier ./build.sh)." >&2
	exec "$here/build/paros.x86_64" "$@"
fi
echo "Godot introuvable, et pas de binaire dans build/." >&2
echo "Indiquer Godot : export GODOT_PATH=/chemin/vers/godot" >&2
exit 1
