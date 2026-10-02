# Claude Code

[English](../en/claude-code.md)

Paros suit les sessions Claude Code interactives de la machine, pour l'utilisateur courant. Les sous-agents et les sessions en arrière-plan n'ont pas de personnage. Les sessions cloud (claude.ai/code) et celles d'une autre machine ne sont pas vues.

## Ce que montre un personnage

### Sans les hooks

| Session | Personnage |
|---|---|
| Ouverte | Un personnage apparaît, avec le nom et la couleur de la session |
| Travaille | Reste sur place, regarde en l'air, trois points se remplissent au-dessus de sa tête |
| Attend une permission ou une réponse | Agite les bras à tour de rôle, « ! » clignotant |
| Attend une tâche qu'elle a lancée en arrière-plan | Assis, regarde un sablier : le sable coule, le sablier se retourne |
| Écrit à une autre session | Lance une lettre, qui vole jusqu'au personnage de cette session |
| A reçu un message d'une autre session pendant son travail | Une boîte aux lettres à côté du personnage, drapeau levé. Avec le nombre de lettres quand plusieurs attendent |
| A écrit à une autre session, qui y travaille encore | Assis près du sablier, tourné vers le personnage de cette session |
| Lit ce message | La boîte aux lettres s'en va. Le personnage tient la lettre devant lui et la lit |
| A laissé un serveur tourner en arrière-plan | Porte une antenne sur la tête, avec une lumière verte qui clignote |
| N'a pas pu écrire un fichier qu'une autre session venait de modifier | Les deux personnages se tournent l'un vers l'autre et se toisent. Bulle avec le fichier et l'autre session, deux notes descendantes. Pendant 10 minutes ils se toisent encore quand ils se croisent |
| Au repos | Se promène, s'assoit, dort |
| Contexte rempli à 75 % ou plus | La tête fume |
| Fermée | Le personnage disparaît |

### Avec les hooks

| Événement | Personnage |
|---|---|
| Outil lancé | Légende au-dessus de la tête : « Edit · pet.gd », « Bash · Lance les tests ». Sur plusieurs lignes si besoin |
| Demande de permission | Bulle avec le message de Claude |
| Fin d'un tour que tu as demandé | Saut, cœurs, bulle « Tâche finie ! », deux notes montantes |
| Fin d'un tour demandé par une autre session | Deux hochements de tête. Ni bulle, ni son |
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

### Attente d'une tâche en arrière-plan

Une session peut finir son tour alors qu'une commande ou un agent qu'elle a lancé en arrière-plan tourne encore : un serveur qui démarre, une longue compilation. Elle attend alors cette tâche, pas toi. Le personnage ne dit pas « Tâche finie ! » : il s'assoit près d'un sablier jusqu'à la fin de la tâche et la reprise de la session. La fiche au survol indique « Attend une tâche en arrière-plan ». Une telle session ne rejoint pas la tour.

Un serveur n'est pas une tâche à attendre : il tourne jusqu'à ce qu'on l'arrête. Une commande lancée en arrière-plan compte comme serveur quand elle contient `vite`, `nodemon`, `webpack-dev-server`, `http-server`, `live-server`, `browser-sync`, `uvicorn`, `gunicorn`, `dev`, `start`, `serve`, `watch` ou `preview` après `npm`, `pnpm`, `yarn` ou `bun`, `next dev`, `astro dev`, `nuxt dev`, `ng serve`, `jekyll serve`, `hugo serve`, `-m http.server`, `runserver`, `flask run`, `php -S`, `docker compose up`, `--watch` ou `tail -f`. Le tour qui le lance finit par « Tâche finie ! ». Le personnage porte une antenne tant que le serveur tourne, et la fiche au survol indique « Serveurs en marche ».

Paros le lit dans le transcript : la commande lancée en arrière-plan, son résultat, puis l'avis de sa fin, ou l'ordre de l'arrêter. Et dans le registre : le statut `shell` dit que le tour est fini et qu'une commande tourne encore.

### Lettres entre sessions

Une session peut écrire à une autre avec l'outil `SendMessage`. Le personnage de l'expéditeur lance une lettre, qui vole en cloche jusqu'au personnage du destinataire. Le cachet de la lettre a la couleur de l'expéditeur.

Une session au repos lit le message tout de suite : son personnage tient la lettre devant lui et la lit. Une session au travail le lit plus tard, entre deux étapes ou à la fin de son tour. D'ici là, la lettre attend dans une boîte aux lettres à côté du personnage, drapeau levé. La fiche au survol indique « Lettres à lire ». Sur l'écran de verrouillage, le nombre de lettres n'est pas affiché.

Une session qui a écrit à une autre et fini son tour attend la réponse, pas toi : son personnage s'assoit près du sablier, tourné vers l'autre personnage, tant que l'autre session travaille. La fiche au survol indique « Attend la réponse de », avec le nom. Pas de « Tâche finie ! » à ce moment : il vient quand la réponse est arrivée et le travail fini. Un tour lancé par une autre session, que tu n'as pas demandé, finit par un hochement de tête.

Paros le lit dans les transcripts : ce qui a lancé chaque tour (toi, une autre session, la fin d'une tâche en arrière-plan), l'appel `SendMessage` de l'expéditeur, avec le nom du destinataire, et la file d'attente du destinataire, où le message entre puis sort.

### Résumé d'une session au repos

Quand une session est au repos depuis quelques minutes, Claude Code écrit un résumé de là où elle en est : le but, ce qui est fait, la suite. La fiche au survol l'affiche à la place du début du dernier prompt, coupé à 220 caractères. Le résumé disparaît au tour suivant.

### Deux sessions sur le même fichier

Claude Code refuse d'écrire un fichier qui a changé depuis que la session l'a lu. Quand une autre session a écrit ce même fichier avec `Edit` ou `Write` dans les 15 minutes d'avant, les deux sessions se marchent dessus : leurs personnages se toisent, et la bulle nomme le fichier et l'autre session.

Deux sessions dans le même dossier et sur la même branche ne sont pas rivales pour autant : elles peuvent travailler ensemble.

### État git du dossier de la session

Lu toutes les 10 secondes (`git status --porcelain=v2 --branch` et `git diff --shortstat HEAD`), sans prendre de verrou sur le dépôt.

| État | Personnage |
|---|---|
| Lignes non commitées : 1, 50, 300 ou plus | Pile de 1, 2 ou 3 dossiers sur le bras. Chaque dossier ralentit la marche de 20 % |
| Fusion, rebase ou cherry-pick à terminer | Casque de chantier, panneau d'avertissement |
| En retard sur la branche amont | Carte à la main, se gratte la tête, « ? » |
| Commit qui laisse l'arbre de travail propre | Trois coups de balai, puis lunettes de soleil pendant une minute |

Le retard sur la branche amont date du dernier `git fetch`. Paros n'en lance pas.

## D'où viennent les informations

| Source | Donne | Remarque |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | Sessions ouvertes, nom, dossier, statut (`busy`, `waiting`, `idle`, `shell`) | Format interne à Claude Code, non documenté : une mise à jour peut le changer |
| Transcript de la session, dans `~/.claude/projects/` | Couleur (`/color`), dernier prompt, résumé, tokens de contexte, tâches en arrière-plan, messages entre sessions, fichiers écrits | Seules les lignes ajoutées depuis la dernière lecture sont lues |
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

À l'écran, un personnage affiche le nom de la session, la branche git et l'outil en cours. La fiche au survol affiche en plus le dossier, et le début du dernier prompt ou le résumé de la session. Sur l'écran de verrouillage, aucun texte n'est affiché.

## Limites

- Une lettre ne vole que vers une session qui a un personnage, trouvée par son nom : un message à une session d'une autre machine, ou à un sous-agent, ne montre rien. Avec deux sessions du même nom, la lettre va à la première trouvée.
- Le message d'une session sans personnage n'a pas de vol : la lettre est tout de suite dans la boîte aux lettres.
- Un serveur lancé par une commande que la liste ne connaît pas compte comme une tâche : le personnage attend près du sablier.
- Une collision n'est vue que si l'autre session a écrit le fichier avec `Edit` ou `Write`. Un fichier modifié par une commande (`sed`, un script, un formateur) n'a pas d'auteur connu : rien n'est montré.
- Une tâche en arrière-plan sans avis de fin au bout de 30 minutes est oubliée, sauf si le registre dit qu'une commande tourne encore : le personnage retourne au repos.
- `Stop` se déclenche aussi sur `/clear` et sur un compactage : le personnage saute alors sans qu'une tâche soit finie.
- Le compte des sous-agents suit les événements `SubagentStart` et `SubagentStop`. Un événement manqué le fausse jusqu'à la fermeture de la session.
- Le script demande un shell POSIX. Sous Windows, Claude Code lance les hooks avec Git Bash.
