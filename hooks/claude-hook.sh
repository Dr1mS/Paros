#!/bin/sh
# Hook Claude Code : ajoute une ligne par événement, lue par Paros.
# Champs séparés par des tabulations :
#   hook_event_name, session_id, notification_type, tool_name, détail, genre, agent
# détail : fichier touché, sinon description de la commande, sinon message.
# agent : identifiant du sous-agent d'où vient l'événement, vide pour la session.
# genre : "test" quand la commande Bash lance des tests.
# N'affiche rien et sort toujours avec 0 : ne peut pas perturber une session.

# Les champs utiles sont au début. La suite (contenu de fichier, sortie de commande) peut peser lourd.
input=$(head -c 6000)

# Première valeur texte de la clé donnée.
field() {
	printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 | sed 's/^[^:]*:[[:space:]]*"\(.*\)"$/\1/'
}

detail=$(field file_path)
detail=${detail##*/}
# Windows paths: the JSON holds them with doubled backslashes.
detail=${detail##*\\}
[ -z "$detail" ] && detail=$(field description)
[ -z "$detail" ] && detail=$(field message)

kind=""
if field command | grep -qE '(^|[ /;&|])(pytest|jest|vitest|phpunit|rspec|ctest)([ ;&|]|$)|(npm|pnpm|yarn|bun|cargo|go|dotnet|mvn|gradle|make|composer)( run)? test'; then
	kind="test"
fi

dir="${XDG_RUNTIME_DIR:-/tmp}/paros"
mkdir -p "$dir" 2>/dev/null
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(field hook_event_name)" "$(field session_id)" "$(field notification_type)" "$(field tool_name)" "$(printf '%s' "$detail" | cut -c1-120)" "$kind" "$(field agent_id)" >> "$dir/claude-events.log" 2>/dev/null
exit 0
