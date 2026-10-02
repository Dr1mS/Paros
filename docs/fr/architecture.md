# Architecture

[English](../en/architecture.md)

## Principe

```
sens ──poste──▶ Events ──écoute──▶ cerveau ──commande──▶ personnages ──lus par──▶ corps
```

- Un **sens** observe une chose du monde (les sessions Claude Code, l'horloge, git, le bureau) et poste des événements. Il ne connaît ni le cerveau ni les personnages.
- **Events** est le bus : un seul signal, `sensed(event, data)`.
- Le **cerveau** contient toutes les règles : quel événement provoque quel comportement. C'est le seul endroit où un événement devient un ordre.
- Un **personnage** est une machine à états. Il exécute les ordres et gère son mouvement.
- Le **corps** dessine le personnage à partir de son état. Il ne décide rien.

Ajouter une fonctionnalité revient presque toujours à : un sens qui poste un événement, une règle dans le cerveau, un état ou un attribut du personnage, son dessin dans le corps.

## Fichiers

| Fichier | Rôle |
|---|---|
| `main.tscn`, `src/main.gd` | Scène principale : `Pets`, `Brain`, `SettingsWindow`, et les sens sous `Senses` |
| `project.godot` | Réglages du moteur : fenêtre transparente, pilote X11, pilote OpenGL ES, pas d'audio sous Linux |
| **`src/core/`** | |
| `input_method.gd` | Relance l'application sans serveur de méthode de saisie X11. Autoload `InputMethod`, le premier |
| `events.gd` | Bus d'événements. Autoload `Events` |
| `settings.gd` | Réglages de l'utilisateur. Autoload `Settings` |
| `focus.gd` | Minuteur de focus. Autoload `Focus` |
| `sound.gd` | Sons synthétisés. Autoload `Sound` |
| `language.gd` | Langue de l'interface et textes français. Autoload `Language` |
| `desktop.gd` | Actions sur le bureau : terminal au premier plan, sonnerie, allumage des moniteurs, lecture de `/proc`. Classe `Desktop` |
| `autostart.gd` | Lancement à l'ouverture de session. Classe `Autostart` |
| **`src/senses/`** | |
| `claude_code_sense.gd` | Sessions Claude Code : registre, transcripts, journal des hooks |
| `git_sense.gd` | État git du dossier de chaque session |
| `desktop_sense.gd` | Fichier écrit par l'extension GNOME : fenêtre active, curseur, verrouillage, plein écran |
| `system_sense.gd` | Température, charge, batterie |
| `clock_sense.gd` | Nuit et jour |
| `idle_sense.gd` | Inactivité de l'utilisateur, demandée à GNOME |
| `music_sense.gd` | Lecteurs multimédias en lecture, demandés à MPRIS |
| **`src/brain/`** | |
| `brain.gd` | Toutes les règles |
| **`src/pet/`** | |
| `pets.gd` | Crée et supprime les personnages. Gère ce qui se fait à deux, les lettres, et la fréquence d'images |
| `pet_window.tscn` | Fenêtre d'un personnage : `Pet`, `Body`, `Bubble`, `Pointer`, `ContextMenu` |
| `letter_window.tscn`, `letter.gd` | Fenêtre d'une lettre qui vole d'un personnage à un autre |
| `pet.gd` | Machine à états, déplacement de la fenêtre, vol, perchoir |
| `pet_body.gd` | Dessin |
| `pointer.gd` | Souris sur le personnage |
| **`src/ui/`** | |
| `bubble.gd` | Bulle et fiche |
| `context_menu.gd` | Menu du clic droit |
| `settings_window.gd` | Fenêtre de réglages |
| **Hors `src/`** | |
| `hooks/claude-hook.sh` | Script appelé par les hooks Claude Code |
| `gnome-extension/` | Extension GNOME Shell et son installateur |
| `tests/` | Tests unitaires |
| `docs/` | Documentation, en français et en anglais, et captures d'écran |
| `run.sh`, `build.sh`, `test.sh` | Lancer, exporter, tester |

## Fenêtres

Chaque personnage a sa propre fenêtre du système : 300 × 272 pixels à la taille 1, transparente, sans bordure, toujours au-dessus, sans focus. Le personnage ne bouge pas dans sa fenêtre : c'est la fenêtre qui se déplace sur le bureau. Une forme de clic (`mouse_passthrough_polygon`) limite la zone cliquable au corps.

Une lettre entre deux personnages a sa propre petite fenêtre, du même genre, qui laisse passer tous les clics. Au repos elle est garée hors écran, et ressert pour la lettre suivante.

La fenêtre principale de Godot ne peut pas être cachée. Elle reste vide, garée hors écran.

L'application tourne en X11, donc par XWayland sous Wayland : Wayland natif interdit à une fenêtre de choisir sa position.

## Le personnage

### Souhait et état

Le cerveau donne un **souhait** (`Pet.Wish`) : `ROAM`, `SLEEP`, `THINK`, `ALERT`, `WAIT`. C'est un ordre permanent. Le personnage y obéit dès qu'il est au repos : un saut de joie en cours se termine d'abord.

L'**état** (`Pet.State`) est ce que le personnage fait à l'instant :

| État | Fin |
|---|---|
| `IDLE`, `SIT`, `WALK` | Durée tirée au hasard, ou changement de souhait |
| `SLEEP`, `THINK`, `ALERT`, `WAIT` | Quand le souhait change. `SLEEP` passe par `STRETCH` |
| `STRETCH`, `CHEER`, `GREET`, `GLARE`, `HIGH_FIVE`, `WORRY`, `ROAST`, `KNOCK`, `SWEEP`, `THROW`, `READ`, `NOD` | Durée fixe, dans `Pet.TIMED` |
| `CLIMB` | Arrivée sur le perchoir |
| `CARRIED` | Quand la souris lâche |
| `FALL` | Atterrissage |

### Attributs

Le cerveau règle aussi des attributs que le corps dessine par-dessus l'état : `label`, `color`, `accessory`, `caption`, `minis`, `urgent`, `fullness`, `baggage`, `hard_hat`, `lost`, `tapping`, `meditating`, `headlamp`, `cool`, `grooving`, `mail`, `serving`, `discreet`, `rooted`, `pace`, `repo`, `perch`, `avoid`.

### Sol

Le sol d'un personnage est le bas de la zone utilisable de son écran. La zone de marche s'étend aux écrans libres placés côte à côte. Un perchoir remplace le sol par le bord supérieur d'un rectangle. La disposition des écrans est relue quatre fois par seconde, pas à chaque image : la demander au serveur d'affichage est lent.

## Événements

Un événement a un nom et un dictionnaire de données.

### Sessions Claude Code — `claude_code_sense.gd`

Tous portent `session`, l'identifiant de la session.

| Événement | Données | Effet dans le cerveau |
|---|---|---|
| `session_opened` | `name`, `color`, `cwd`, `last_prompt`, `pid`, `context` | Crée le personnage, l'habille |
| `session_changed` | les mêmes | L'habille de nouveau |
| `session_closed` | | Supprime le personnage |
| `session_phase` | `phase` (`idle`, `working`, `waiting`), `since` | Fixe le souhait |
| `session_activity` | `tool`, `detail` | Légende |
| `session_quiet` | `level` (0, 1, 2) | Tape du pied, médite |
| `session_subagents` | `count` | Petits personnages |
| `session_background` | `background`, `servers` | Sablier tant que le tour est fini et qu'une tâche en arrière-plan tourne. Pas de « Tâche finie ! ». Antenne tant qu'un serveur tourne |
| `session_message_sent` | `to`, le nom d'une session | Le personnage lance une lettre au personnage de cette session. Son tour fini, il attend la réponse tant que cette session travaille |
| `session_mail` | `mail` | Boîte aux lettres tant que des messages d'autres sessions attendent d'être lus. Lecture de la lettre quand l'une sort |
| `session_turn` | `origin` (`human`, `peer`, `task-notification`…), `from` | Un tour lancé par une autre session finit par un hochement de tête, pas par un saut de joie |
| `session_needs_you` | `detail` | Bulle |
| `session_finished` | | Saut, bulle, son |
| `session_tests_passed` | | Saut, bulle, son |
| `session_tool_failed` | `tool`, `detail`, `kind` | Tremblement, son |

### Git — `git_sense.gd`

| Événement | Données | Effet |
|---|---|---|
| `repo_state` | `session`, `branch`, `dirty`, `behind`, `conflict` | Étiquette, dossiers portés, casque, carte |
| `repo_cleaned` | `session` | Balai, lunettes de soleil |

### Bureau — `desktop_sense.gd`

| Événement | Données | Effet |
|---|---|---|
| `desktop_state` | `active`, `fullscreen`, `pid`, `covered` | Perchoir, écrans à éviter, focus du terminal |
| `pointer_at` | `position` | Mémorisé pour le toc-toc |
| `pointer_idle` | `position` | Un personnage vient dormir à côté |
| `pointer_moved` | | Il se réveille |
| `screen_locked` | `locked` | Mode discret, écran maintenu allumé |

### Autres sens

| Événement | Données | Émetteur | Effet |
|---|---|---|---|
| `night`, `day` | | `clock_sense.gd` | Sommeil, lampe frontale |
| `user_idle`, `user_active` | | `idle_sense.gd` | Sommeil |
| `cpu_hot` | | `system_sense.gd` | Feu de camp |
| `battery_low` | `percent` | `system_sense.gd` | Bulle |
| `system_load` | `load` | `system_sense.gd` | Vitesse de marche |
| `music` | `playing` | `music_sense.gd` | Hochement et note |

### Personnages et interface

| Événement | Données | Émetteur | Effet |
|---|---|---|---|
| `pointer_tap`, `pointer_double`, `pointer_grab`, `pointer_drop` | `pet` | `pet/pointer.gd` | Joie, terminal, porté, lâché |
| `letter_landed` | `pet` | `pet/letter.gd` | La lettre va dans la boîte aux lettres, ou est lue si la session l'a déjà prise |
| `pointer_enter`, `pointer_leave` | `pet` | `pet/pointer.gd` | Fiche |
| `pointer_menu` | `pet` | `pet/pointer.gd` | Ouvre le menu de ce personnage |
| `files_dropped` | `pet`, `files` | `pet/pointer.gd` | Presse-papiers |
| `pet_landed`, `pet_knocked` | `pet` | `pet/pet.gd` | Sons |
| `locate_requested` | `pet` | `ui/context_menu.gd` | Sonnerie du terminal |
| `settings_requested` | | `ui/context_menu.gd` | Ouvre les réglages |
| `focus_started`, `focus_finished`, `break_finished` | | `core/focus.gd` | Bulles |

## Recettes

### Ajouter un sens

1. Créer `src/senses/mon_sens.gd`, qui appelle `Events.post(&"mon_evenement", {...})`. Poster seulement quand quelque chose change.
2. L'ajouter comme nœud sous `Senses` dans `main.tscn`.
3. Ajouter la règle dans `_on_sensed` de `brain.gd`.
4. Décrire l'événement dans l'en-tête du sens et dans ce document.

Un sens qui lance un programme le fait dans un fil d'exécution (`Thread`) : `OS.execute` bloque, et une image bloquée fige les personnages. Voir `git_sense.gd`.

### Ajouter un comportement court

1. Ajouter l'état à `Pet.State` et sa durée à `Pet.TIMED`.
2. L'ajouter à la branche des états à durée fixe dans `Pet._process`.
3. Ajouter une méthode publique qui appelle `_play(State.MON_ETAT)`.
4. Dessiner la pose dans `pet_body.gd` : décalages dans le `match state` de `_draw`, formes en plus avec `_blocks`.
5. Appeler la méthode depuis une règle du cerveau.

### Ajouter un accessoire

Ajouter une entrée à `ACCESSORIES` dans `pet_body.gd` (`room` : place prise au-dessus de la tête, `blocks` : formes et couleurs), et augmenter `Pet.ACCESSORY_COUNT`. Les formes sont en unités de grille : 1 unité vaut 9 pixels, l'origine est sous les pieds, Y est négatif vers le haut.

### Ajouter un son

Ajouter une entrée à `TUNES` dans `sound.gd` : une liste de notes, chacune avec sa durée puis ses fréquences. Puis `Sound.play(&"nom")` depuis le cerveau.

### Ajouter un réglage

1. Ajouter la clé et sa valeur par défaut à `DEFAULTS` dans `settings.gd`.
2. Ajouter une ligne à `FIELDS` dans `settings_window.gd`.
3. Lire la valeur avec `Settings.value("section", "cle")` au moment de s'en servir, pour qu'un changement s'applique tout de suite.

Un test vérifie que tout réglage de `DEFAULTS` est dans la fenêtre.

### Ajouter un texte affiché

L'écrire en anglais, en argument de `tr()` : `pet.say(tr("Task done!"))`. Un texte avec un nombre garde son emplacement : `tr("Focus: %d min") % minutes`. Le texte d'un libellé de la fenêtre de réglages est traduit par le contrôle lui-même.

Puis ajouter sa version française à `FRENCH` dans `language.gd`. Un test vérifie que les deux versions ont les mêmes emplacements, et que chaque libellé des réglages a un texte français.

## Conventions

- Code et commentaires en anglais. Les textes affichés sont écrits en anglais dans le code et traduits en français dans `language.gd`.
- Un commentaire dit pourquoi, pas ce que fait la ligne.
- Les règles vont dans le cerveau. Un sens ne commande jamais un personnage.
- Rien n'est dessiné à partir d'un fichier image.
