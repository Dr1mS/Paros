# Claude Code

Paros suit les sessions Claude Code interactives de la machine, pour l'utilisateur courant. Les sous-agents et les sessions en arrière-plan n'ont pas de personnage. Les sessions cloud (claude.ai/code) et celles d'une autre machine ne sont pas vues.

## Ce que montre un personnage

### Sans les hooks

| Session | Personnage |
|---|---|
| Ouverte | Un personnage apparaît, avec le nom et la couleur de la session |
| Travaille | Reste sur place, regarde en l'air, trois points se remplissent au-dessus de sa tête |
| Attend une permission ou une réponse | Agite les bras à tour de rôle, « ! » clignotant |
| Au repos | Se promène, s'assoit, dort |
| Contexte rempli à 75 % ou plus | La tête fume |
| Fermée | Le personnage disparaît |

### Avec les hooks

| Événement | Personnage |
|---|---|
| Outil lancé | Légende au-dessus de la tête : « Edit · pet.gd », « Bash · Lance les tests ». Sur plusieurs lignes si besoin |
| Demande de permission | Bulle avec le message de Claude |
| Fin de tour | Saut, cœurs, bulle « Tâche finie ! », deux notes montantes |
| Sous-agent lancé | Un petit personnage part du grand en courant, une feuille à la main, et reste à côté. Quatre au plus |
| Tests réussis | Saut, bulle « Tests verts ! » |
| Tests échoués | Tremble, bulle « Tests rouges », deux notes descendantes |
| Autre commande échouée | Tremble, goutte de sueur, deux notes descendantes |
| Aucun événement depuis 8 secondes pendant le travail | Tape du pied, regarde par terre |
| Aucun événement depuis 25 secondes | Médite : assis, flotte au-dessus du sol, signes mathématiques en orbite |
| Attente de plus de 2 minutes | Saute plus haut, bulle de rappel chaque minute |
| Attente depuis 20 secondes, terminal sans le focus | Court vers le bord d'écran le plus proche du curseur et toque deux fois. Recommence toutes les 30 secondes |

Une commande compte comme un test quand elle contient `pytest`, `jest`, `vitest`, `phpunit`, `rspec`, `ctest`, ou `test` après `npm`, `pnpm`, `yarn`, `bun`, `cargo`, `go`, `dotnet`, `mvn`, `gradle`, `make`, `composer`.

Le silence des hooks ne dit pas pourquoi la session se tait : réflexion longue du modèle et réseau lent se ressemblent.

Le rappel d'attente et le toc-toc n'ont lieu que si le terminal de la session n'a pas le focus. Sans l'[extension GNOME](extension-gnome.md), le focus est inconnu : Paros considère que le terminal ne l'a pas.

### État git du dossier de la session

Lu toutes les 10 secondes (`git status --porcelain=v2 --branch` et `git diff --shortstat HEAD`), sans prendre de verrou sur le dépôt.

| État | Personnage |
|---|---|
| Lignes non commitées : 1, 50, 300 ou plus | Pile de 1, 2 ou 3 dossiers sur le bras. Chaque dossier ralentit la marche de 20 % |
| Fusion, rebase ou cherry-pick à terminer | Casque de chantier, panneau d'avertissement |
| En retard sur la branche amont | Carte à la main, se gratte la tête, « ? » |
| Commit qui laisse l'arbre de travail propre | Trois coups de balai, puis lunettes de soleil pendant une minute |
| Même dossier et même branche qu'une autre session | Les deux personnages se toisent quand ils se croisent |

Le retard sur la branche amont date du dernier `git fetch`. Paros n'en lance pas.

## D'où viennent les informations

| Source | Donne | Remarque |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | Sessions ouvertes, nom, dossier, statut (`busy`, `waiting`, `idle`) | Format interne à Claude Code, non documenté : une mise à jour peut le changer |
| Transcript de la session, dans `~/.claude/projects/` | Couleur (`/color`), dernier prompt, tokens de contexte | Seules les lignes ajoutées depuis la dernière lecture sont lues |
| `$XDG_RUNTIME_DIR/paros/claude-events.log` | Outils, sous-agents, échecs, fin de tour, demandes de permission | Écrit par `hooks/claude-hook.sh` |
| Dossier de la session | État git | Par la commande `git` |

Si `CLAUDE_CONFIG_DIR` est défini, il remplace `~/.claude`.

Une session dont le processus n'existe plus est ignorée, même si son fichier est resté.

### Contexte

Les tokens de contexte sont la somme des tokens d'entrée de la dernière réponse du modèle (entrée, écriture en cache, lecture en cache), arrondie à 10 000. La taille de la fenêtre de contexte du modèle n'est écrite nulle part : elle se règle (« Contexte du modèle, en milliers de tokens », 1000 par défaut). La tête fume à 75 % de cette taille.

## Installer les hooks

Dans `~/.claude/settings.json`, déclarer le script pour chacun de ces événements : `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop`, `Stop`.

```json
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "/chemin/vers/Paros/hooks/claude-hook.sh", "async": true }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "/chemin/vers/Paros/hooks/claude-hook.sh", "async": true }] }
    ]
  }
}
```

Le même bloc est à répéter pour les six autres événements. Les hooks de `~/.claude/settings.json` valent pour toutes les sessions de l'utilisateur, quel que soit le projet. Une session déjà ouverte les prend en compte sans redémarrage.

Le script ne peut pas perturber une session : il est lancé en arrière-plan (`async`), n'affiche rien et sort toujours avec 0.

### Ce que le script écrit

Une ligne par événement, six champs séparés par des tabulations :

| Champ | Exemple |
|---|---|
| Événement | `PreToolUse` |
| Identifiant de session | `c1c3d9b6-…` |
| Type de notification | `permission_prompt` |
| Outil | `Edit` |
| Détail, 120 caractères au plus | Nom du fichier touché, sinon description de la commande, sinon message de la notification |
| Genre | `test` quand la commande lance des tests, vide sinon |

## Confidentialité

Le fichier `$XDG_RUNTIME_DIR/paros/claude-events.log` contient en clair les noms d'outils, les noms de fichiers touchés et les descriptions de commandes de toutes les sessions. Il est dans le dossier d'exécution de l'utilisateur, lisible par lui seul, et disparaît à la fermeture de session du système.

À l'écran, un personnage affiche le nom de la session, la branche git et l'outil en cours. La fiche au survol affiche en plus le dossier et le début du dernier prompt. Sur l'écran de verrouillage, aucun texte n'est affiché.

## Limites

- `Stop` se déclenche aussi sur `/clear` et sur un compactage : le personnage saute alors sans qu'une tâche soit finie.
- Le compte des sous-agents suit les événements `SubagentStart` et `SubagentStop`. Un événement manqué le fausse jusqu'à la fermeture de la session.
- Le script demande un shell POSIX. Sous Windows, Claude Code lance les hooks avec Git Bash.
