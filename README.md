# Paros

Compagnon de bureau : un petit personnage qui vit au bas de l'écran. Godot 4.7, GDScript, aucun asset image (tout est dessiné par code).

## Lancer

```sh
./run.sh
```

`GODOT_PATH` doit pointer vers un binaire Godot 4.7 ou plus récent. Sinon `godot` est cherché dans `PATH`.

Après un clone, ou après l'ajout d'un script avec `class_name`, lancer une fois l'import :

```sh
"$GODOT_PATH" --headless --path . --import
```

## Interactions

| Geste | Effet |
|---|---|
| Clic gauche | Le personnage est content |
| Glisser | Le porter, puis le lâcher : il retombe au sol |
| Clic droit | Menu : « Réglages… », « Quitter » |

Il s'endort la nuit (23 h à 7 h) et après 5 minutes sans activité clavier ni souris.

## Claude Code

Un personnage par session Claude Code ouverte sur la machine. Il porte le nom de la session (`/rename`) sous ses pieds et prend sa couleur (`/color`). Sans aucune session ouverte, un seul personnage orange, sans nom.

| Session Claude Code | Paros |
|---|---|
| Travaille | Reste sur place, regarde en l'air, trois points au-dessus de la tête |
| Attend une permission ou une réponse | Agite les bras, « ! », bulle « Claude attend ta réponse » |
| A fini son tour | Saute, bulle « Tâche finie ! » |

`claude_code_sense.gd` lit trois sources :

| Source | Donne |
|---|---|
| `~/.claude/sessions/<pid>.json` | Sessions ouvertes, nom, statut (`busy`, `waiting`, `idle`). Format interne à Claude Code, non documenté : peut changer |
| Transcript de la session | Couleur choisie avec `/color` |
| `$XDG_RUNTIME_DIR/paros/claude-events.log` | Fin de tour et demande de permission, écrites par `hooks/claude-hook.sh` |

Installation des hooks : dans `~/.claude/settings.json`, déclarer le script pour les événements `UserPromptSubmit`, `PostToolUse`, `Notification`, `Stop` et `SessionEnd` :

```json
"hooks": {
  "Stop": [
    { "hooks": [{ "type": "command", "command": "/chemin/vers/Paros/hooks/claude-hook.sh", "async": true }] }
  ]
}
```

Sans les hooks, noms, couleurs et états restent suivis. Seules les bulles et le saut de fin de tour manquent.

## Réglages

Clic droit sur un personnage, puis « Réglages… ». Chaque changement s'applique et s'enregistre tout de suite.

| Réglage | Défaut | Clé dans le fichier |
|---|---|---|
| Taille | 1.0 × | `pet/size` |
| Vitesse de marche | 70 px/s | `pet/walk_speed` |
| Afficher le nom de session | oui | `pet/show_name` |
| Afficher les bulles | oui | `bubble/enabled` |
| Durée des bulles | 4 s | `bubble/seconds` |
| Début de la nuit | 23 h | `sleep/night_start_hour` |
| Fin de la nuit | 7 h | `sleep/night_end_hour` |
| Sommeil après inactivité | 5 min | `sleep/idle_minutes` |
| Lancer au démarrage | non | crée ou supprime `~/.config/autostart/paros.desktop` |

Les réglages sont stockés dans `~/.local/share/paros/settings.cfg`.

Ajouter un réglage : une entrée dans `DEFAULTS` (`src/core/settings.gd`) et une ligne dans `FIELDS` (`src/ui/settings_window.gd`).

## Architecture

```
sens  ──poste──▶  Events  ──écoute──▶  cerveau  ──commande──▶  pets  ──lus par──▶  corps
```

Chaque personnage a sa propre fenêtre (`src/pet/pet_window.tscn`). La fenêtre principale de Godot reste vide, hors écran.

| Dossier | Rôle |
|---|---|
| `src/core/events.gd` | Bus d'événements (autoload `Events`) |
| `src/core/settings.gd` | Réglages utilisateur (autoload `Settings`) |
| `src/core/autostart.gd` | Lancement à l'ouverture de session |
| `src/senses/` | Un fichier par sens. Un sens observe et poste des événements, rien d'autre |
| `src/brain/brain.gd` | Toutes les règles : quel événement provoque quel comportement |
| `src/pet/pets.gd` | Crée et supprime les personnages, un par clé de session |
| `src/pet/pet.gd` | Machine à états et déplacement de la fenêtre sur le bureau |
| `src/pet/pointer.gd` | Souris sur un personnage : clic, glisser, clic droit |
| `src/pet/pet_body.gd` | Dessin du personnage selon l'état |
| `src/ui/bubble.gd` | Bulle de texte : `bubble.say("...")` |
| `src/ui/context_menu.gd` | Menu du clic droit |
| `src/ui/settings_window.gd` | Fenêtre de réglages |
| `hooks/claude-hook.sh` | Script appelé par les hooks Claude Code |

### Ajouter un sens

1. Créer `src/senses/mon_sens.gd` qui appelle `Events.post(&"mon_evenement")`.
2. L'ajouter comme nœud sous `Senses` dans `main.tscn`.
3. Ajouter la règle correspondante dans `brain.gd`.

### Événements existants

| Événement | Sens |
|---|---|
| `pointer_tap`, `pointer_grab`, `pointer_drop`, `pointer_menu` | `pet/pointer.gd` |
| `night`, `day` | `clock_sense.gd` |
| `user_idle`, `user_active` | `idle_sense.gd` |
| `session_opened`, `session_changed`, `session_closed`, `session_phase`, `session_finished`, `session_needs_you` | `claude_code_sense.gd` |

## Plateformes

Linux d'abord. Sous Wayland, l'app tourne via XWayland (`display_server/driver.linuxbsd="x11"` dans `project.godot`) : Wayland natif interdit à une fenêtre de se placer elle-même.

La fenêtre est de type utilitaire, sans focus : absente du dock et d'Alt+Tab.

`idle_sense.gd` interroge GNOME (Mutter). Sur un autre bureau, ce sens reste muet et le reste fonctionne.
