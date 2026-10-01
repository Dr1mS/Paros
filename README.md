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
| Double-clic | Met le terminal de sa session au premier plan (extension GNOME) et fait sonner son onglet |
| Glisser | Le porter. Lâché avec élan, il vole et rebondit sur les bords et le sol. Lâché de haut, il ouvre un parapluie |
| Déposer un fichier dessus | Copie le chemin dans le presse-papiers, prêt à coller dans le terminal |
| Survol | Fiche de la session ; ses yeux suivent la souris |
| Clic droit | Menu : aller au terminal, le faire sonner, focus, « Réglages… », « Quitter » |

Seul, il marche, s'assoit et regarde autour de lui. Il flâne quand la machine ne fait rien et trottine quand tous les cœurs sont occupés (charge moyenne de Linux). La nuit, éveillé, il allume une lampe frontale. Il s'endort la nuit (23 h à 7 h) et après 5 minutes sans activité clavier ni souris, puis s'étire au réveil. Deux personnages qui se croisent se saluent.

### Tour des sessions au repos

Quand au moins deux sessions sont au repos depuis 90 secondes, leurs personnages se rejoignent et s'empilent, assis l'un sur l'autre. La tour s'écroule dès qu'une de ces sessions reçoit un prompt, ou qu'un personnage est attrapé.

### Sons

Aucun fichier audio : ondes carrées et bruit blanc calculés par `src/core/sound.gd`.

| Son | Quand |
|---|---|
| Deux notes montantes | Tour fini, tests verts |
| Deux notes descendantes, la dernière dissonante | Commande ou tests échoués |
| Souffle court | Retombée au sol après un lancer |
| Deux coups sourds | Toc-toc sur le bord de l'écran |

Le pilote audio coûte environ 2 % d'un cœur, sons coupés ou non. Pour l'éviter : lancer avec `--audio-driver Dummy`.

### Focus

Clic droit, « Démarrer un focus » : 25 minutes de travail, puis 5 minutes de pause. Les personnages annoncent le début de la pause et sa fin. Le temps restant se lit dans le menu et dans la fiche.

### Alertes système

Sous Linux, au plus une fois toutes les 10 minutes :

- processeur à 92 °C ou plus, ou tous les cœurs occupés depuis une minute : les personnages s'assoient près d'un feu de camp et font griller une guimauve ;
- batterie à 15 % ou moins, en décharge : bulle.

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
| Transcript de la session | Couleur choisie avec `/color`, dernier prompt, tokens de contexte |
| `$XDG_RUNTIME_DIR/paros/claude-events.log` | Outils, sous-agents, échecs, fin de tour, demande de permission, écrits par `hooks/claude-hook.sh` |

Installation des hooks : dans `~/.claude/settings.json`, déclarer le script pour les événements `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop` et `Stop` :

```json
"hooks": {
  "Stop": [
    { "hooks": [{ "type": "command", "command": "/chemin/vers/Paros/hooks/claude-hook.sh", "async": true }] }
  ]
}
```

Sans les hooks, noms, couleurs et états restent suivis. Tout le reste du tableau ci-dessous manque.

| Événement | Paros |
|---|---|
| Outil lancé | Étiquette au-dessus de la tête : « Edit · pet.gd » |
| Sous-agent lancé | Un petit personnage à côté du grand, quatre au plus |
| Tests réussis (`npm test`, `pytest`, `cargo test`…) | Saut, bulle « Tests verts ! » |
| Tests échoués | Tremble, bulle « Tests rouges » |
| Autre commande échouée | Tremble, goutte de sueur |
| Attente plus longue que 2 minutes | Saute plus haut, bulle de rappel chaque minute |
| Aucun événement depuis 8 s pendant le travail | Tape du pied, regarde par terre |
| Aucun événement depuis 25 s | Médite : assis, flotte au-dessus du sol, signes mathématiques en orbite. Réflexion longue ou réseau lent : impossible à distinguer |
| Attente depuis 20 s, terminal sans le focus | Court vers le bord d'écran le plus proche du curseur et toque deux fois : la fenêtre du personnage tremble de 2 pixels. Recommence toutes les 30 s. Sans l'extension GNOME, le focus est inconnu : il toque après 20 s d'attente |
| Contexte rempli à 75 % ou plus | La tête fume |
| Fin de tour ou tests verts, quand un voisin vient de réussir aussi | Les deux se tapent dans la main |

Un sous-agent qui démarre part du grand personnage en courant, une feuille à la main.

### État git du dossier

Lu toutes les 10 secondes avec `git status` et `git diff --shortstat` (réglage « Suivre l'état git des dossiers »).

| État | Personnage |
|---|---|
| Lignes non commitées : 1, 50, 300 ou plus | Pile de 1, 2 ou 3 dossiers sur le bras. Chaque dossier ralentit la marche de 20 % |
| Fusion, rebase ou cherry-pick à terminer | Casque de chantier, panneau d'avertissement |
| En retard sur la branche amont | Carte à la main, se gratte la tête, « ? ». Le retard date du dernier `git fetch` : Paros n'en lance pas |
| Deux sessions dans le même dossier et la même branche | En se croisant, les deux se toisent au lieu de se saluer |
| Commit qui laisse l'arbre de travail propre | Trois coups de balai, puis lunettes de soleil pendant une minute |

Fiche au survol : dossier, état et sa durée, outil en cours, nombre de sous-agents, tokens de contexte, état git, dernier prompt.

Étiquette : nom de session, puis branche git du dossier. Contexte : la taille de fenêtre du modèle n'est pas lisible, elle se règle (1000 k tokens par défaut). Accessoire (chapeau, couronne, casquette, nœud, lunettes, fleur ou rien) : tiré du nom de session, donc stable.

« Faire sonner son terminal » envoie une sonnerie au terminal de la session : son onglet est marqué.

## Extension GNOME Shell

Sous Wayland, une application ne voit ni la fenêtre active ni le curseur hors de ses propres fenêtres, et ne peut pas mettre une autre fenêtre au premier plan. L'extension `gnome-extension/paros@paros.local` donne ces trois choses à Paros.

```sh
./gnome-extension/install.sh
```

Puis se déconnecter et se reconnecter : GNOME sous Wayland ne charge une nouvelle extension qu'à l'ouverture de session.

| Avec l'extension | Détail |
|---|---|
| Double-clic : terminal au premier plan | Fenêtre trouvée par le processus de la session, puis par son titre. Si la session est dans un onglet en arrière-plan, la fenêtre choisie peut être la mauvaise : la sonnerie marque le bon onglet |
| Perchoir | Un personnage saute parfois sur le bord supérieur de la fenêtre active, plus souvent quand il réfléchit. Il y marche et s'y assoit. Fenêtre déplacée ou focus perdu : il tombe |
| Sommeil contre le curseur | Curseur immobile depuis une minute : le personnage libre le plus proche vient dormir à côté. Il se réveille quand le curseur bouge |

L'extension écrit l'état du bureau dans `$XDG_RUNTIME_DIR/paros/desktop.json` deux fois par seconde au plus, et expose `org.paros.Desktop.Activate` sur D-Bus. Sans elle, ces trois comportements sont absents et le reste fonctionne.

## Réglages

Clic droit sur un personnage, puis « Réglages… ». Chaque changement s'applique et s'enregistre tout de suite.

| Réglage | Défaut | Clé dans le fichier |
|---|---|---|
| Taille | 1.0 × | `pet/size` |
| Vitesse de marche | 70 px/s | `pet/walk_speed` |
| Afficher le nom de session | oui | `pet/show_name` |
| Accessoires | oui | `pet/accessories` |
| Les personnages se saluent | oui | `pet/greetings` |
| Tour des sessions au repos | oui | `pet/tower` |
| Lampe frontale la nuit | oui | `pet/headlamp` |
| Activer les sons | oui | `sound/enabled` |
| Volume | 50 % | `sound/volume` |
| Afficher les bulles | oui | `bubble/enabled` |
| Durée des bulles | 4 s | `bubble/seconds` |
| Afficher l'outil en cours | oui | `claude/show_activity` |
| Insister après une attente de | 2 min | `claude/nag_minutes` |
| Toquer quand le terminal n'a pas le focus | oui | `claude/knock` |
| Fenêtre de contexte du modèle | 1000 k tokens | `claude/context_window_k` |
| Suivre l'état git des dossiers | oui | `git/enabled` |
| Grimper sur la fenêtre active | oui | `desktop/perch` |
| Dormir contre le curseur immobile | oui | `desktop/cuddle` |
| Début de la nuit | 23 h | `sleep/night_start_hour` |
| Fin de la nuit | 7 h | `sleep/night_end_hour` |
| Sommeil après inactivité | 5 min | `sleep/idle_minutes` |
| Durée d'un focus | 25 min | `focus/minutes` |
| Durée d'une pause | 5 min | `focus/break_minutes` |
| Alertes batterie et température | oui | `system/alerts` |
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
| `src/core/focus.gd` | Minuteur de focus (autoload `Focus`) |
| `src/core/desktop.gd` | Actions sur le bureau : terminal au premier plan, sonnerie |
| `src/core/sound.gd` | Sons calculés (autoload `Sound`) |
| `src/senses/` | Un fichier par sens. Un sens observe et poste des événements, rien d'autre |
| `src/brain/brain.gd` | Toutes les règles : quel événement provoque quel comportement |
| `src/pet/pets.gd` | Crée et supprime les personnages, un par clé de session. Gère ce qui se fait à deux : salut, rivalité, tape dans la main |
| `src/pet/pet.gd` | Machine à états et déplacement de la fenêtre sur le bureau |
| `src/pet/pointer.gd` | Souris sur un personnage : clic, glisser, clic droit |
| `src/pet/pet_body.gd` | Dessin du personnage selon l'état |
| `src/ui/bubble.gd` | Bulle de texte : `bubble.say("...")` |
| `src/ui/context_menu.gd` | Menu du clic droit |
| `src/ui/settings_window.gd` | Fenêtre de réglages |
| `hooks/claude-hook.sh` | Script appelé par les hooks Claude Code |
| `gnome-extension/` | Extension GNOME Shell et son script d'installation |

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
| `pointer_double`, `pointer_enter`, `pointer_leave`, `files_dropped` | `pet/pointer.gd` |
| `pet_landed`, `pet_knocked` | `pet/pet.gd` |
| `session_opened`, `session_changed`, `session_closed`, `session_phase`, `session_activity`, `session_quiet`, `session_subagents`, `session_finished`, `session_needs_you`, `session_tool_failed`, `session_tests_passed` | `claude_code_sense.gd` |
| `repo_state`, `repo_cleaned` | `git_sense.gd` |
| `desktop_state`, `pointer_at`, `pointer_idle`, `pointer_moved` | `desktop_sense.gd` |
| `cpu_hot`, `battery_low`, `system_load` | `system_sense.gd` |
| `focus_started`, `focus_finished`, `break_finished` | `core/focus.gd` |
| `settings_requested`, `locate_requested` | `ui/context_menu.gd` |

## Export en binaire

```sh
./build.sh          # build/paros.x86_64
./build.sh Windows  # build/paros.exe
```

Demande les modèles d'export Godot de la même version que l'éditeur : dans l'éditeur, Éditeur > Gérer les modèles d'export. Sans eux, l'export échoue.

Le binaire est autonome : Godot n'est plus nécessaire pour le lancer. « Lancer au démarrage », coché depuis le binaire, pointe vers le binaire.

## Consommation

Environ 12 % d'un cœur et 150 Mo de mémoire pour trois personnages (Intel HD 530). Le rendu coûte l'essentiel :

- 30 images par seconde quand un personnage bouge, 12 quand tous sont calmes (`src/pet/pets.gd`).
- Pilote OpenGL ES sous Linux : deux fois moins coûteux que OpenGL avec plusieurs fenêtres.

## Plateformes

Linux d'abord. Sous Wayland, l'app tourne via XWayland (`display_server/driver.linuxbsd="x11"` dans `project.godot`) : Wayland natif interdit à une fenêtre de se placer elle-même.

La fenêtre est de type utilitaire, sans focus : absente du dock et d'Alt+Tab.

`idle_sense.gd` interroge GNOME (Mutter). Sur un autre bureau, ce sens reste muet et le reste fonctionne.

Windows : non testé. Le code évite ce qui est propre à Linux (dossier personnel, dossier temporaire, lancement au démarrage par un fichier `.cmd` du dossier Démarrage). Sens d'inactivité et alertes système restent muets. Les hooks demandent Git Bash.
