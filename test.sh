#!/bin/sh
# Lance les tests unitaires, sans affichage.
# Usage : ./test.sh [test_pet test_brain ...]   (sans argument : tous)
# Les réglages, le lancement au démarrage et le dossier d'exécution sont
# redirigés vers un dossier temporaire : rien de l'utilisateur n'est touché.
cd "$(dirname "$0")"
godot="${GODOT_PATH:-godot}"
if ! command -v "$godot" >/dev/null 2>&1; then
	echo "Godot introuvable. Indiquer Godot : export GODOT_PATH=/chemin/vers/godot" >&2
	exit 1
fi
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/data" "$sandbox/config" "$sandbox/run"
XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_RUNTIME_DIR="$sandbox/run" \
	"$godot" --headless --path . res://tests/run.tscn -- "$@" > "$sandbox/output" 2>&1
status=$?
grep -v -e '^Godot Engine' -e '^$' "$sandbox/output"
exit $status
