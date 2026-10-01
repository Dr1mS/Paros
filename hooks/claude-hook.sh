#!/bin/sh
# Hook Claude Code : ajoute une ligne par événement, lue par Paros.
# Format de ligne : <hook_event_name> <session_id> <notification_type>
# N'affiche rien et sort toujours avec 0 : ne peut pas perturber une session.
input=$(cat)
field() {
	printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}
dir="${XDG_RUNTIME_DIR:-/tmp}/paros"
mkdir -p "$dir" 2>/dev/null
printf '%s %s %s\n' "$(field hook_event_name)" "$(field session_id)" "$(field notification_type)" >> "$dir/claude-events.log" 2>/dev/null
exit 0
