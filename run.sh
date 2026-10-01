#!/bin/sh
# Lance Paros. GODOT_PATH doit pointer vers un binaire Godot 4.7+, sinon "godot" est cherché dans PATH.
exec "${GODOT_PATH:-godot}" --path "$(dirname "$0")" "$@"
