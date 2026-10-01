# Extension GNOME Shell

Sous Wayland, une application ne voit ni la fenêtre active, ni le curseur hors de ses propres fenêtres, ni l'écran de verrouillage. Elle ne peut pas non plus mettre une autre fenêtre au premier plan. GNOME Shell, lui, sait tout cela. L'extension `paros@paros.local` tourne dans GNOME Shell et sert de pont.

Sans l'extension, tout ce qui est décrit ici est absent, et le reste de Paros fonctionne.

## Installer

```sh
./gnome-extension/install.sh
```

Puis se déconnecter et se reconnecter. Sous Wayland, GNOME ne charge une extension, ou sa nouvelle version, qu'à l'ouverture de session.

Vérifier :

```sh
gnome-extensions info paros@paros.local      # État : ACTIVE
cat "$XDG_RUNTIME_DIR/paros/desktop.json"    # doit contenir "locked" et "covered"
```

Si le fichier ne contient pas `"covered"`, GNOME tourne encore avec une ancienne version de l'extension : se reconnecter.

Désinstaller :

```sh
gnome-extensions disable paros@paros.local
rm -r ~/.local/share/gnome-shell/extensions/paros@paros.local
```

Versions de GNOME Shell déclarées : 45 à 48. Testé avec 46.

## Ce qu'elle apporte

### Terminal au premier plan

Double-clic sur un personnage, ou « Aller à son terminal » dans le menu. La fenêtre est cherchée parmi celles du processus de la session et de ses parents, puis par son titre s'il contient le nom de la session.

Limite : toutes les fenêtres de GNOME Terminal appartiennent au même processus. Si la session est dans un onglet en arrière-plan, le titre ne correspond pas et la fenêtre choisie peut être la mauvaise. La sonnerie envoyée en même temps marque le bon onglet.

### Perchoir

Un personnage saute parfois sur le bord supérieur de la fenêtre active, plus souvent quand il réfléchit. Il y marche et s'y assoit. Si la fenêtre bouge ou perd le focus, il tombe, et ouvre son parapluie si la chute est longue. Une fenêtre en plein écran, trop étroite ou trop près du haut de l'écran ne sert pas de perchoir.

### Sommeil contre le curseur

Quand le curseur ne bouge plus depuis une minute, le personnage libre le plus proche marche jusqu'à lui et s'endort à côté. Il se réveille quand le curseur bouge.

### Toc-toc

Paros sait si le terminal d'une session a le focus. Une session qui attend depuis 20 secondes, terminal sans focus : son personnage court vers le bord d'écran le plus proche du curseur et toque deux fois. Voir [Claude Code](claude-code.md).

### Plein écran

Quand une application occupe un écran en plein écran (jeu, vidéo), les personnages quittent cet écran et vont sur l'écran libre le plus proche. Si tous les écrans sont en plein écran, ils se cachent. Ils reviennent quand le plein écran s'arrête.

### Écran de verrouillage

GNOME cache toutes les fenêtres d'application derrière l'écran de verrouillage. L'extension reste active pendant le verrouillage et dessine une copie en direct de chaque fenêtre de personnage par-dessus. Les copies ne reçoivent ni clic ni clavier.

| Pendant le verrouillage | |
|---|---|
| Aucun texte | Ni nom, ni outil en cours, ni bulle. Les sons continuent |
| Écran allumé | GNOME éteint les moniteurs dès le verrouillage. Paros les rallume chaque seconde pendant 10 minutes (réglage « Écran allumé après verrouillage », 0 pour ne rien faire), puis les éteint lui-même. La mise en veille automatique est retenue pendant ce temps |
| Personnages éveillés | Ils ne s'endorment pas pour inactivité. La nuit, ils dorment |
| Écran éteint | Paros ne dessine presque plus : 2 images par seconde |

Les moniteurs peuvent clignoter une fois au verrouillage : GNOME les éteint, Paros les rallume dans la seconde.

En cas de problème sur l'écran de verrouillage :

1. `Ctrl+Alt+F3`, se connecter en console.
2. `gnome-extensions disable paros@paros.local`
3. `Ctrl+Alt+F2` (ou `F1`) pour revenir.

## Fonctionnement

L'extension écrit l'état du bureau dans `$XDG_RUNTIME_DIR/paros/desktop.json`, deux fois par seconde au plus, et seulement quand il change. Elle le réécrit de toute façon toutes les 10 secondes : un fichier vieux de plus de 30 secondes signale à Paros que l'extension ne tourne plus.

```json
{
  "pointer": [612, 669],
  "locked": false,
  "mirrored": 0,
  "covered": [[1920, 0, 1920, 1080]],
  "active": {"x": 100, "y": 100, "width": 814, "height": 618, "fullscreen": false, "pid": 2888974}
}
```

| Champ | Sens |
|---|---|
| `pointer` | Position du curseur |
| `locked` | L'écran de verrouillage est affiché |
| `mirrored` | Nombre de personnages copiés sur l'écran de verrouillage. Sert au diagnostic |
| `covered` | Moniteurs sous une fenêtre en plein écran |
| `active` | Fenêtre qui a le focus, ou `null` |

Les coordonnées sont celles de l'écran, en pixels.

Elle expose aussi une méthode D-Bus sur `org.gnome.Shell`, objet `/org/paros/Desktop` :

```
org.paros.Desktop.Activate(au pids, s title) -> b
```

Met au premier plan une fenêtre appartenant à un des processus, de préférence celle dont le titre contient le texte. Renvoie faux si aucune fenêtre ne correspond.

Une fenêtre de personnage est reconnue par sa classe (`Paros`), par le fait qu'elle se place elle-même, et par sa largeur de plus de 100 pixels.

## Sans Paros

L'extension ne fait rien d'autre qu'écrire ce fichier et attendre un appel D-Bus. Paros fermé, elle reste sans effet visible.
