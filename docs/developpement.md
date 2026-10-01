# Développement

## Prérequis

- Godot 4.7 ou plus récent. `GODOT_PATH` doit pointer vers son binaire, sinon `godot` est cherché dans `PATH`.
- `git`, pour le sens git et pour un des tests.
- Pour les sons sous Linux : `pw-play`, `paplay` ou `aplay`.
- Pour l'export : les modèles d'export Godot de la même version que l'éditeur.

```sh
export GODOT_PATH="/chemin/vers/godot"
```

## Lancer depuis les sources

```sh
./run.sh
```

Après un clone, ou après l'ajout d'un script avec `class_name`, lancer une fois l'import :

```sh
"$GODOT_PATH" --headless --path . --import
```

## Tests

```sh
./test.sh                      # tous les tests
./test.sh test_pet test_brain  # certains fichiers
```

Les tests tournent sans affichage, en quelques secondes. Le script sort avec 1 si un test échoue.

Les réglages, le fichier de lancement au démarrage et le dossier d'exécution sont redirigés vers un dossier temporaire : rien de l'utilisateur n'est touché. Sans affichage, les actions sur le bureau (`Desktop`) et les sons ne font rien.

| Fichier | Ce qu'il couvre |
|---|---|
| `test_pet.gd` | Machine à états d'un personnage : souhaits, états courts, vol et rebonds, parapluie, courses, perchoir, mode discret |
| `test_pets.gd` | Rencontres, rivalité, tape dans la main, fréquence d'images |
| `test_brain.gd` | Règles : une session par personnage, souhaits, sommeil, verrouillage, git, contexte, toc-toc, tour, fiche |
| `test_senses.gd` | Lecture du registre et des transcripts Claude Code, journal des hooks, sorties de git, fichier du bureau, script de hook |
| `test_core.gd` | Réglages, minuteur de focus, synthèse des sons et fichier WAV, bulle, lancement au démarrage |

### Écrire un test

Un fichier `tests/test_*.gd` étend `res://tests/test_case.gd`. Chaque méthode dont le nom commence par `test_` est un test. Chaque test tourne dans une instance neuve.

```gdscript
extends "res://tests/test_case.gd"

func test_pet_thinks_when_asked() -> void:
	var pet := make_pet()
	pet.wish = Pet.Wish.THINK
	step(pet, 0.1)
	check_equal(pet.state, Pet.State.THINK, "thinks")
```

| Aide | Rôle |
|---|---|
| `check(condition, quoi)`, `check_equal(obtenu, voulu, quoi)`, `check_near(obtenu, voulu, marge, quoi)` | Vérifications |
| `make_pet()` | Un personnage immobile, sur le sol de `AREA` |
| `step(pet, secondes)` | Avance le temps du personnage |
| `stand(pet)` | Le remet au repos, sans rien de prévu |
| `record_events()`, `event_names()`, `last_event(nom)` | Événements postés sur le bus |
| `before_each()`, `after_each()` | Avant et après chaque test |

Le temps n'avance que par `step` : un test ne dépend pas de l'horloge. Le hasard est rendu fixe avant chaque test.

Ce que les tests ne couvrent pas : le dessin, la vraie souris, les vraies fenêtres et les vrais écrans, l'extension GNOME.

## Exporter en binaire

```sh
./build.sh          # build/paros.x86_64
./build.sh Windows  # build/paros.exe
```

Les modèles d'export s'installent depuis l'éditeur : Éditeur > Gérer les modèles d'export. Ils vont dans `~/.local/share/godot/export_templates/`.

Le binaire est autonome : Godot n'est plus nécessaire pour le lancer. `tests/`, `hooks/`, `gnome-extension/` et `docs/` n'y sont pas inclus. `build/` n'est pas suivi par git.

Après un changement du code, reconstruire le binaire, sinon `./run.sh` sans Godot lance l'ancien.

## Performances

Mesures sur un Intel HD 530, binaire exporté, un personnage, souris en mouvement.

| | Part d'un cœur |
|---|---|
| Total | 6 à 7 % |
| Fil d'événements X11 du moteur | 2 à 4 %, selon l'activité de la souris |
| Fil principal : scripts et rendu | 1,5 à 2 % |
| Mémoire | 150 Mo |

Ce qui a compté, dans l'ordre :

| Choix | Gain | Où |
|---|---|---|
| Pilote OpenGL ES au lieu de OpenGL | Rendu deux fois moins coûteux avec plusieurs fenêtres | `project.godot` |
| Pas de pilote audio sous Linux | 4 % : son fil tournait en permanence, son ou non | `project.godot`, `sound.gd` |
| 12 images par seconde quand tous les personnages sont calmes, 30 sinon | | `pets.gd` |
| Dessin seulement quand l'image change : un personnage calme s'anime par pas, 6 par seconde | | `pet_body.gd`, mode `low_processor_mode` |
| Disposition des écrans lue 4 fois par seconde | | `pet.gd` |
| 2 images par seconde, écran verrouillé et éteint | | `pets.gd` |

Ce qui reste est le moteur lui-même. Son fil d'événements X11 reçoit chaque mouvement de la souris, où qu'elle soit. Le réduire demanderait de modifier Godot.

Pour mesurer, lire le temps processeur par fil dans `/proc/<pid>/task/*/stat` sur une durée fixe. `perf` et `strace -p` sont souvent refusés sans droits.

Deux pièges rencontrés :

- Une fenêtre hors écran avec la synchronisation verticale attend une seconde par image sous OpenGL ES. La fenêtre principale et celles des personnages n'ont donc pas de synchronisation verticale.
- Le moteur empêche par défaut la mise en veille de l'écran (`keep_screen_on`). C'est désactivé dans `project.godot`.

## Plateformes

| | État |
|---|---|
| Linux, GNOME, Wayland | Testé |
| Linux, autre bureau | Cœur fonctionnel. Sens d'inactivité et extension absents |
| Windows | Binaire produit, jamais lancé. Sens d'inactivité, alertes système, sonnerie du terminal et extension absents. Les hooks demandent Git Bash |

Ce qui est propre à Linux est isolé : lecture de `/proc` et `/sys`, `gdbus`, dossier `$XDG_RUNTIME_DIR`, lecteurs audio. Ailleurs, ces parties restent muettes.

## Limites connues

- **Formats non documentés** : `~/.claude/sessions/*.json` et les transcripts. Une mise à jour de Claude Code peut casser le suivi des sessions.
- **Extension GNOME** : à revérifier à chaque version de GNOME. Toute modification demande une reconnexion.
- **Moniteurs sous verrouillage** : Paros les rallume chaque seconde, faute de pouvoir empêcher GNOME de les éteindre. Ils peuvent clignoter une fois.
- **Onglets de terminal** : la bonne fenêtre n'est pas toujours trouvée quand la session est dans un onglet en arrière-plan.
- **Fenêtre de contexte** : sa taille n'est pas lisible, elle se règle.
- **Au-dessus de tout** : les fenêtres des personnages passent au-dessus des autres. Sans l'extension, elles restent visibles sur une application en plein écran.
- **Molette sur un champ numérique des réglages** : change la valeur au lieu de faire défiler.

## Dépannage

| Symptôme | Cause probable | Remède |
|---|---|---|
| `godot: not found` | `GODOT_PATH` non défini dans ce terminal | L'exporter, ou construire le binaire avec `./build.sh` |
| Aucun personnage pour une session | Session non interactive, ou format du registre changé | `cat ~/.claude/sessions/*.json` : le champ `kind` doit valoir `interactive` |
| Pas de bulle, pas de légende | Hooks non installés | Voir [Claude Code](claude-code.md#installer-les-hooks), puis `tail $XDG_RUNTIME_DIR/paros/claude-events.log` |
| Double-clic sans effet, pas de perchoir | Extension absente ou ancienne version en mémoire | Voir [Extension GNOME](extension-gnome.md#installer) |
| Pas de son | Aucun lecteur audio trouvé | Installer `pipewire-bin` (`pw-play`) ou `pulseaudio-utils` (`paplay`) |
| Le personnage toque sans arrêt | Extension absente : le focus du terminal est inconnu | Installer l'extension, ou décocher « Toquer quand le terminal n'a pas le focus » |
| L'écran ne s'éteint plus sous verrouillage | Maintien de l'écran | Régler « Écran allumé après verrouillage » à 0 |
| Écran de verrouillage bloqué | Extension | `Ctrl+Alt+F3`, `gnome-extensions disable paros@paros.local` |

Pour voir les erreurs de script : lancer depuis les sources avec `./run.sh` dans un terminal.
