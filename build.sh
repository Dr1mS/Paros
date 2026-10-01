#!/bin/sh
# Exporte Paros en binaire autonome dans build/.
# Demande les modèles d'export Godot : dans l'éditeur, Éditeur > Gérer les modèles d'export.
# Usage : ./build.sh [Linux|Windows]
set -e
cd "$(dirname "$0")"
preset="${1:-Linux}"
mkdir -p build
case "$preset" in
	Windows) output="build/paros.exe" ;;
	*) output="build/paros.x86_64" ;;
esac
"${GODOT_PATH:-godot}" --headless --path . --export-release "$preset" "$output"
echo "Exporté : $output"
