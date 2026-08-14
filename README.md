# SkillTracker

Module de la suite **TibiSuite** par Tibiscui. SkillTracker suit la progression de vos métiers **par extension**, sous la forme `actuel / max` avec un pourcentage vers 100%, pour tous vos personnages.

Disponible en anglais et en français (détection automatique de la langue du client).

## Fonctionnalités

Suivi des deux métiers principaux, des métiers secondaires (Cuisine, Pêche) et de l'archéologie si elle est apprise. Pour chaque métier, une barre de progression par extension (chaque palier a son propre maximum). Les paliers à 100% sont visuellement distincts des paliers en cours.

En haut du panneau, un sélecteur d'extension présente un onglet coloré par extension (MID, TWW, DF...), avec les mêmes sigles et couleurs que RenTracker. Seules les extensions pour lesquelles le personnage possède au moins un métier sont affichées, du plus récent au plus ancien. Cliquez sur un onglet pour voir la progression de tous vos métiers pour cette extension. L'archéologie, qui n'est pas liée à une extension, reste affichée en permanence sous le sélecteur.

Au changement de métier, l'ancien métier est automatiquement remis à zéro pour ce personnage dès le scan suivant, il n'est pas simplement figé.

Un panneau récapitulatif du compte liste chaque métier connu, le nombre de personnages qui le possèdent et une progression moyenne. Au survol d'un métier, un tooltip enrichi affiche la liste des personnages qui le possèdent avec leur progression.

Liseré et accents à la couleur Émeraude Monk `#00FF98`, intégration visuelle homogène avec le reste de TibiSuite.

Depuis la version 1.1, le panneau affiche aussi une liste « À finir » qui regroupe tous les paliers non terminés de tous vos personnages, triés du plus avancé au moins avancé, pour savoir d'un coup d'œil quoi compléter en priorité. Des options permettent de masquer les extensions au max, de masquer les métiers entièrement terminés, et d'afficher ou non le récapitulatif du compte et la liste « À finir ». Un objet LibDataBroker est exposé si une barre de données (Titan Panel, ElvUI, Bazooka) est présente, et le survol du bouton minimap résume vos métiers et le nombre de paliers restants. Enfin, la recherche globale de TibiSuite fait office d'annuaire : tapez un métier pour voir quel personnage le possède et à quel pourcentage.

Depuis la version 1.2, SkillTracker affiche aussi la concentration et les points de connaissance non dépensés par métier, dans une section dédiée du panneau et dans le tooltip. Une alerte prévient quand la concentration d'un métier de fabrication est pleine (donc gaspillée si vous ne l'utilisez pas). La concentration passe par l'API officielle et ne concerne que les métiers de fabrication (les métiers de récolte comme l'Herboristerie ou le Minage n'en ont pas). Les points de connaissance sont lus via `C_ProfSpecs.GetCurrencyInfoForSkillLine` et cumulés sur toutes les extensions, car vous pouvez avoir des points non dépensés sur plusieurs paliers à la fois. Le détail par extension apparaît sous chaque barre dans la vue par extension.

Depuis la version 1.3, un clic sur la barre d'un métier ouvre directement la fenêtre officielle du métier en jeu.

Depuis la version 1.4, la section « À finir » propose un filtre par personnage sous forme de puces cliquables : sélectionnez un ou plusieurs personnages pour n'afficher que leurs paliers à terminer. Aucune puce active signifie que tous les personnages sont affichés. Quand un seul personnage est filtré, son nom n'est plus répété sur chaque ligne, pour une lecture plus claire.

## Installation

Placez le dossier `SkillTracker` dans `World of Warcraft/_retail_/Interface/AddOns/`. L'addon fonctionne de manière autonome (il embarque sa propre copie versionnée de la bibliothèque d'interface `TibiMidnightUI.lua`). Si TibiSuite est installé, SkillTracker apparaît comme onglet **Metiers** dans la barre unifiée.

Commandes: `/skt` affiche ou masque le panneau, `/skt config` ouvre les options, `/skt scan` force un nouveau scan.

## Comment charger le détail par extension

Pour des raisons techniques côté Blizzard, l'API `C_TradeSkillUI` ne fournit le détail par extension **qu'après l'ouverture d'une fenêtre de métier au moins une fois** dans la session. Tant que vous n'avez pas ouvert un métier, SkillTracker affiche la progression globale du métier (issue du grimoire) et vous invite à ouvrir la fenêtre. Une fois le métier ouvert, le détail par extension est capté et mis en cache dans les données sauvegardées, il reste donc disponible ensuite entre les sessions.

## Limite multi-comptes (à lire)

Un addon ne peut lire que les données sauvegardées de l'installation où il tourne. Concrètement:

Plusieurs personnages d'un **même compte sur la même installation** de WoW: fonctionne nativement, tous les persos écrivent dans le même fichier, l'agrégation est automatique.

Plusieurs **comptes sur la même installation** (même dossier WoW): fonctionne également, les données sont agrégées automatiquement.

Comptes sur des **installations séparées** (autre PC, autre dossier): il n'y a aucune synchronisation automatique possible, et SkillTracker ne prétend pas le faire. Utilisez la fonction **Exporter / Importer** dans les options: sur la première installation, cliquez sur Exporter, copiez la chaîne (Ctrl+C), puis sur l'autre installation cliquez sur Importer et collez la chaîne (Entrée). Les personnages importés apparaissent dans le récapitulatif avec la mention « importé ».

## Noms d'extensions

SkillTracker lit directement le nom d'extension fourni par le jeu pour chaque palier de métier (le même que celui affiché dans l'onglet Métiers officiel et dans le menu déroulant des paliers). Le rangement est donc exact et automatique, sans table d'identifiants à maintenir. Les noms de région renvoyés par le jeu (Midnight, Khaz Algar, Îles aux Dragons, Ombreterre, Zandalar, Légion, Draenor, Pandarie, Cataclysme, Norfendre, Outreterre, Classic) sont traduits en extensions, en français comme en anglais.

Pour charger le détail, il suffit d'ouvrir une fenêtre de métier une fois par session: le jeu ne fournit ces données qu'à ce moment. Ouvrir un métier principal peuple tous les métiers principaux d'un coup; les métiers secondaires (Cuisine, Pêche) se chargent en ouvrant leur propre fenêtre.

Une commande de diagnostic `/skt dump` reste disponible pour inspecter les données brutes du client si besoin.

## Données sauvegardées

`SkillTrackerDB` (au niveau compte), indexé par royaume puis personnage, puis par métier et par extension. Un numéro de version de schéma et une petite fonction de migration sont prévus pour ne jamais casser les données lors d'une future mise à jour.

## Dépendance

SkillTracker est conçu comme module de TibiSuite mais reste autonome. Il déclare `## OptionalDeps: TibiSuite` afin de se charger avant TibiSuite quand les deux sont présents, ce qui permet l'apparition de l'onglet dans la barre unifiée.

## Note sur le logo

Le fichier `media/Logo.png` fourni ne s'affiche pas en jeu: WoW ne lit que les textures `.tga` ou `.blp`. Convertissez le logo en `Logo.tga` (ou `.blp`) dans le dossier `media` pour qu'il apparaisse sur le bouton minimap et dans l'en-tête. En attendant, l'addon fonctionne parfaitement sans.
