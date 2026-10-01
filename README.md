# Paros

Compagnon de bureau pour Claude Code. Un petit personnage en pixels vit au bas de l'écran, un par session Claude Code ouverte. Il montre d'un coup d'œil ce que fait chaque session : elle travaille, elle attend une réponse, elle a fini.

Godot 4.7, GDScript. Aucun fichier image ni son : tout est dessiné et synthétisé par le code.

## Lancer

```sh
./run.sh
```

`run.sh` lance Paros depuis les sources si Godot est trouvé (variable `GODOT_PATH`, sinon `godot` dans `PATH`), et à défaut le binaire `build/paros.x86_64`.

Pour quitter : clic droit sur un personnage, puis « Quitter ».

## En bref

| | |
|---|---|
| Un personnage par session | Nom de la session sous ses pieds, couleur de la session, accessoire propre |
| Il réfléchit | La session travaille. L'outil en cours s'affiche au-dessus de sa tête |
| Il agite les bras | La session attend une permission ou une réponse |
| Il saute | La session a fini son tour |
| Clic droit | Menu : terminal de la session, minuteur de focus, réglages, quitter |
| Double-clic | Met le terminal de la session au premier plan |
| Survol | Fiche de la session |

## Documentation

| Document | Contenu |
|---|---|
| [Utilisation](docs/utilisation.md) | Tous les comportements, les gestes, le menu, les réglages |
| [Claude Code](docs/claude-code.md) | Ce que Paros lit des sessions, installation des hooks, confidentialité |
| [Extension GNOME](docs/extension-gnome.md) | Terminal au premier plan, perchoir, écran de verrouillage, plein écran |
| [Architecture](docs/architecture.md) | Organisation du code, événements, comment ajouter un sens ou un comportement |
| [Développement](docs/developpement.md) | Tests, export en binaire, performances, limites connues, dépannage |

## Installation complète

1. Lancer Paros : `./run.sh`.
2. Brancher les hooks Claude Code, pour les bulles et les réactions aux outils : voir [Claude Code](docs/claude-code.md#installer-les-hooks).
3. Sous GNOME, installer l'extension : `./gnome-extension/install.sh`, puis se déconnecter et se reconnecter. Voir [Extension GNOME](docs/extension-gnome.md).
4. Pour un lancement à chaque ouverture de session : « Réglages… », cocher « Lancer au démarrage ».

Les étapes 2 à 4 sont facultatives. Sans elles, les personnages suivent quand même les sessions, leur nom, leur couleur et leur état.

## Plateformes

Linux avec GNOME : testé. Autres bureaux Linux : le cœur fonctionne, les parties propres à GNOME restent muettes. Windows : un binaire est produit, jamais testé.
