extends Node
## Interface language. Every text shown is written in English in the code, as
## the argument of tr() or as the text of a control, and translated here.
## A text with no translation shows as written.

## Languages offered in the settings. "auto": the language of the system.
const CHOICES := {"auto": "Automatic", "en": "English", "fr": "Français"}
## English text -> French text.
const FRENCH := {
	"Task done!": "Tâche finie !",
	"Claude is waiting for you": "Claude attend ta réponse",
	"Claude has been waiting for %s": "Claude attend depuis %s",
	"%s: also changed by %s": "%s : aussi modifié par %s",
	"Green tests!": "Tests verts !",
	"Red tests": "Tests rouges",
	"Focus: %d min": "Focus : %d min",
	"Break! %d min": "Pause ! %d min",
	"Break is over. Back to it?": "Fin de pause. On reprend ?",
	"Low battery: %d %%": "Batterie faible : %d %%",
	"Path copied: paste it in the terminal": "Chemin copié : colle-le dans le terminal",
	"Working for %s": "Travaille depuis %s",
	"Waiting for you for %s": "Attend ta réponse depuis %s",
	"At rest for %s": "Au repos depuis %s",
	"Waiting for a background task for %s": "Attend une tâche en arrière-plan depuis %s",
	"Waiting for the answer of %s for %s": "Attend la réponse de %s depuis %s",
	"Subagents running: %d": "Sous-agents en cours : %d",
	"Servers running: %d": "Serveurs en marche : %d",
	"Letters to read: %d": "Lettres à lire : %d",
	"Asks the sage": "Demande au sage",
	"Asks the sage for %s": "Demande au sage depuis %s",
	"The sage comes when the advisor is asked": "Le sage vient quand l'advisor est consulté",
	"Context: %d k tokens (%d %%)": "Contexte : %d k tokens (%d %%)",
	"Merge or rebase to finish": "Fusion ou rebase à terminer",
	"Uncommitted: %d lines": "Non commité : %d lignes",
	"%d commits behind origin": "En retard de %d commits sur origin",
	"Focus: %d min left": "Focus : reste %d min",
	"Break: %d min left": "Pause : reste %d min",
	"“%s”": "« %s »",
	"Go to its terminal": "Aller à son terminal",
	"Ring its terminal": "Faire sonner son terminal",
	"Start a focus (%d min)": "Démarrer un focus (%d min)",
	"Stop the focus (%d min left)": "Arrêter le focus (reste %d min)",
	"Stop the break (%d min left)": "Arrêter la pause (reste %d min)",
	"Settings…": "Réglages…",
	"Quit": "Quitter",
	"Paros — Settings": "Paros — Réglages",
	"Pet": "Personnage",
	"Size": "Taille",
	"Walk speed": "Vitesse de marche",
	"Show the session name": "Afficher le nom de session",
	"Accessories": "Accessoires",
	"Pets greet each other": "Les personnages se saluent",
	"Tower of resting sessions": "Tour des sessions au repos",
	"Headlamp at night": "Lampe frontale la nuit",
	"Groove to the music": "Bouger en musique",
	"Sounds": "Sons",
	"Enable sounds": "Activer les sons",
	"Bubbles": "Bulles",
	"Show bubbles": "Afficher les bulles",
	"Bubble duration": "Durée des bulles",
	"Show the tool in use": "Afficher l'outil en cours",
	"Subagents": "Sous-agents",
	"A small pet for each subagent": "Un petit personnage par sous-agent",
	"Small pets per session, at most": "Petits personnages par session, au plus",
	"Size of the small pets": "Taille des petits personnages",
	"Show the tool of each subagent": "Afficher l'outil de chaque sous-agent",
	"Small pets jump and run to each other": "Les petits personnages sautent et courent l'un vers l'autre",
	"Small pets build pyramids": "Les petits personnages font des pyramides",
	"Remind after waiting for": "Insister après une attente de",
	"Knock when the terminal is not focused": "Toquer quand le terminal n'a pas le focus",
	"Model context, in thousands of tokens": "Contexte du modèle, en milliers de tokens",
	"Follow the git status of folders": "Suivre l'état git des dossiers",
	"Desktop (GNOME extension)": "Bureau (extension GNOME)",
	"Climb onto the focused window": "Grimper sur la fenêtre active",
	"Sleep by the still pointer": "Dormir contre le curseur immobile",
	"Leave the screen of a full screen app": "Quitter l'écran d'une app en plein écran",
	"Screen on after locking": "Écran allumé après verrouillage",
	"Sleep": "Sommeil",
	"Night starts at": "Début de la nuit",
	"Night ends at": "Fin de la nuit",
	"Sleep after inactivity": "Sommeil après inactivité",
	"Focus duration": "Durée d'un focus",
	"Break duration": "Durée d'une pause",
	"System": "Système",
	"Battery and temperature alerts": "Alertes batterie et température",
	"Start at login": "Lancer au démarrage",
	"Language": "Langue",
	"Automatic": "Automatique",
}


func _init() -> void:
	var french := Translation.new()
	french.locale = "fr"
	for text: String in FRENCH:
		french.add_message(text, FRENCH[text])
	TranslationServer.add_translation(french)


func _ready() -> void:
	apply()
	Settings.changed.connect(apply)


func apply() -> void:
	var choice: String = Settings.value("interface", "language")
	TranslationServer.set_locale(OS.get_locale() if choice == "auto" else choice)
