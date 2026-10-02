# Actions de Claude Code habituellement cachées à l'utilisateur

Ce que Claude Code écrit dans le transcript d'une session (`~/.claude/projects/<dossier>/<id>.jsonl`) et que le terminal ne montre pas, ou à peine. Chaque entrée est une piste possible pour Paros.

Relevé du 2 octobre 2026 sur les 65 transcripts de cette machine (Claude Code 2.1.287). Le nombre entre parenthèses est le nombre de lignes trouvées. Le format n'est pas documenté : une mise à jour peut le changer.

Colonne « Paros » : **lu** = déjà utilisé, **piste** = ajout possible, **—** = sans intérêt pour un personnage.

Le sens d'une ligne est déduit de son contenu. Quand il n'est pas établi, c'est écrit.

## Entre sessions

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `assistant`, outil `SendMessage` | La session écrit à une autre session. Champs `to`, `summary`, `message` | **lu** : lettre lancée |
| `queue-operation` `enqueue`, contenu `<cross-session-message from-name="…">` (2 220 `enqueue` en tout, la plupart de ce genre) | Un message d'une autre session entre dans la file d'attente | **lu** : boîte aux lettres |
| `queue-operation` `dequeue` (1 120) | La session prend la première entrée de la file | **lu** |
| `queue-operation` `remove`, raison `absorbed_mid_turn` (1 099) | Le message est lu pendant le tour, entre deux étapes | **lu** |
| `queue-operation` `popAll` (1) | La file est vidée d'un coup | **lu** |
| `user` avec `origin.kind = "peer"` (748) | Le tour est lancé par une autre session, pas par l'utilisateur. `origin.name` donne son nom | **piste** : carte « Tour demandé par … », pas de « Tâche finie ! » quand un pair attend la réponse |
| `user` avec `origin.kind = "auto-continuation"` (3) | La session reprend seule, sans prompt | **piste** |
| `[Cross-session idle notice] "<nom>" …` (au moins 67) | Avis qu'une session surveillée est passée au repos | **piste** : le personnage qui attendait se tourne vers l'autre |
| `system` `informational` (156) | Texte du genre « Concepteur is idle — finished a turn at 11:22 · … » | **piste** : même signal, avec le résumé du tour |
| `attachment` `queued_command` (1 099) | Copie d'une entrée de la file, donnée au modèle. `commandMode` dit son genre | — (doublon de la file) |

## Fin de tour et repos

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `system` `turn_duration` (1 340) | Durée du tour en millisecondes, nombre de messages | **piste** : durée du dernier tour dans la carte |
| `system` `away_summary` (371) | Résumé de l'état de la session, écrit après quelques minutes de repos | **piste** : texte de la carte, à la place du début du dernier prompt |
| `system` `stop_hook_summary` (109) | Résultat des hooks `Stop` : nombre, erreurs, `preventedContinuation` | **piste** : un hook qui relance la session n'est pas une fin de tâche |
| `attachment` `goal_status` (5) | Objectif fixé à la session (`condition`), atteint ou non (`met`) | **piste** : drapeau d'arrivée quand `met` passe à vrai |
| `cost-state` (70) | Coût cumulé en dollars, durées, lignes ajoutées et retirées, tokens par modèle | **piste** : coût dans la carte |

## Tâches de fond, réveils, sous-agents

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `user` avec `toolUseResult.backgroundTaskId` | Une commande est lancée en arrière-plan | **lu** : sablier |
| `user` avec `toolUseResult.status = "async_launched"` | Un agent est lancé en arrière-plan | **lu** |
| `queue-operation` `enqueue`, contenu `<task-notification>` | Avis de fin d'une tâche de fond, ou événement d'un `Monitor` | **lu** pour la fin. **piste** : un `Monitor` actif est une veille, pas une attente |
| `user` avec `origin.kind = "task-notification"` (231) | Le tour est lancé par un tel avis | **piste** |
| `assistant`, outil `TaskStop` | La session arrête une tâche de fond | **lu** |
| `assistant`, outil `Monitor` | La session arme une surveillance qui la réveille à chaque événement | **piste** : jumelles, ou longue-vue |
| `assistant`, outil `ScheduleWakeup` ; `system` `scheduled_task_fire` (2) | La session programme son réveil, puis se réveille (`/loop`) | **piste** : réveil posé à côté du personnage |
| `assistant`, outils `Agent`, `Workflow` | Sous-agents et flux d'agents | **lu** par les hooks `SubagentStart` et `SubagentStop` |

## Contexte et modèle

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `assistant`, champ `usage` | Tokens d'entrée de la réponse | **lu** : tête qui fume |
| `system` `compact_boundary` (16) | Compaction : tokens avant et après, déclencheur, durée | **piste** : le personnage se vide la tête. Évite aussi le faux « Tâche finie ! » noté dans les limites |
| `attachment` `compact_file_reference` (25) | Fichier rappelé après une compaction | — |
| `attachment` `total_tokens_reminder` (7 520) | Tokens restants dans le budget de la session | **piste** : jauge, si le budget est petit |
| `attachment` `thinking_stripped` (14) | La réflexion a été retirée du contexte | — |
| `assistant`, bloc `thinking`, champ `thinkingDurationMs` | Durée de la réflexion | **piste** : distinguer réflexion longue et réseau lent |
| `assistant`, champs `effort`, `perTurnEffort` ; `attachment` `ultra_effort_enter`, `ultra_effort_exit` (5) | Niveau d'effort du tour | **piste** : bandeau de front en effort maximal |
| `attachment` `model` (75) | Modèle de la session | **piste** : ligne de la carte |
| `system` `model_refusal_fallback` (1) | Refus du modèle, puis bascule sur un autre modèle | **piste** : rare |
| `attachment` `advisor_tool` (10) | Un modèle conseiller est disponible | — |

## Modes et permissions

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `permission-mode` (3 959) | Mode de permission courant : `auto`, plan, etc. Réécrit à chaque tour | **piste** : accessoire par mode |
| `mode` (4 011) | Mode de saisie : `normal`, etc. | — |
| `attachment` `auto_mode`, `auto_mode_exit` (23) | Entrée et sortie du mode automatique | **piste** |
| `attachment` `plan_mode_exit` (4) | Sortie du mode plan, avec le chemin du plan | **piste** : le personnage déroule un plan |
| `system` `permission_retry` (1) | Une commande refusée est autorisée puis relancée | — |
| `attachment` `command_permissions` (12) | Outils autorisés par une commande | — |

## Fichiers

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `attachment` `edited_text_file` (432) | Un fichier connu de la session a changé sur disque sans elle : autre session, formateur, utilisateur | **piste** : chevauchement réel entre deux sessions, plus précis que « même dossier, même branche ». L'auteur n'est pas donné |
| Erreur d'outil `File has been modified since read` | La session veut écrire un fichier changé entre-temps | **piste** : même signal, côté victime |
| `file-history-snapshot` (370), `file-history-delta` (464) | Sauvegardes des fichiers modifiés, pour l'annulation | — |
| `attachment` `file`, `directory` (57) | Fichier ou dossier joint au prompt par l'utilisateur | — |
| `attachment` `read_truncation_notice` (2) | Une lecture a été tronquée | — |

## Rappels glissés au modèle

Textes que Claude Code ajoute au contexte sans les montrer.

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `attachment` `silent_turn_reminder` (414) | « L'utilisateur n'a pas de nouvelles depuis un moment » : le modèle travaille en silence depuis longtemps | **piste** : le personnage fait signe qu'il est toujours là |
| `attachment` `batching_reminder_sent` (2 810) | Rappel de grouper les appels d'outils | — |
| `attachment` `task_reminder` (98) | Rappel de la liste de tâches | — |
| `attachment` `hook_additional_context`, `hook_success`, `hook_system_message` (529) | Texte ajouté par un hook | — |
| `attachment` `bash_output_audience_note` (12) | Note sur le lecteur de la sortie d'une commande | — |
| `attachment` `date`, `date_change` (84) | Date du jour, et son changement à minuit | — |
| `user` `isMeta` | Messages écrits par Claude Code au nom de l'utilisateur : session renommée, sortie d'une commande locale, taille d'une image | — |

## État de la session

| Ligne | Ce qu'elle dit | Paros |
|---|---|---|
| `agent-color` (2 455) | Couleur (`/color`) | **lu** |
| `last-prompt` (4 233) | Dernier prompt de l'utilisateur | **lu** |
| `custom-title`, `agent-name` (2 869 chacun) | Nom donné par `/rename` | **lu** par le registre |
| `ai-title` (1 354) | Titre trouvé par le modèle | **piste** : nom du personnage d'une session sans nom |
| `system` `local_command` (124) | Commande locale (`/rename`, `/color`, `/list-agents`) et sa sortie | — |
| `attachment` `environment`, `session_context`, `instructions`, `prompt_snapshot` | Dossier, dépôt, CLAUDE.md, prompt système | — |
| `attachment` `skill_listing`, `invoked_skills`, `agent_listing_delta`, `deferred_tools_delta`, `deferred_tools_record`, `mcp_instructions_delta` | Outils, compétences et agents disponibles | — |
| `attachment` `credential_org`, `remote_session_change` | Compte, et réglages de commit et de PR | — |
| `bridge-session` (2 173) | Lien avec une session distante. Rôle exact non établi | — |
| `frame-link`, `artifact-comment-monitor`, `artifact-autoreact-ledger` (343) | Artifact publié par la session, et surveillance de ses commentaires | **piste** : le personnage accroche un tableau |
| `atis-latch` (4 028) | Rôle non établi | — |

## Hors transcript

| Source | Ce qu'elle dit | Paros |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | Session ouverte, nom, dossier, statut `busy`, `waiting`, `idle` | **lu** |
| Même fichier, `messagingSocketPath`, `peerFeatures` | Socket des messages entre sessions | — |
| Hooks | Outil lancé, fini, raté ; sous-agents ; fin de tour ; demande de permission | **lu** |
