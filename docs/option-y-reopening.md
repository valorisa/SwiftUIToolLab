# Réouverture d'Option Y : l'UI ImageTransform

## 1. Qu'est-ce qu'Option Y

« Option Y » est le nom donné, depuis la phase 🅰️ (LinearOperator),
à une règle de méthode simple : **une nouvelle fonctionnalité de
calcul ne reçoit pas d'interface utilisateur (UI) tant que sa
logique n'est pas validée**. Elle a été reprise par cohérence sur
🅱️ (LinearEncoder) et SheetReader (OCR), avec la même formulation :
« un chantier de calcul ne mélange pas une décision UX ».

Ce n'était **pas** une interdiction permanente ni une décision
spécifique à ImageTransform. C'était une application mécanique
d'un principe déjà appliqué trois fois auparavant — le principe
« un chantier, un axe de changement à la fois » : isoler la
question « est-ce que la logique est correcte ? » de la question
« comment la présenter à l'utilisateur ? », pour qu'un échec de
test pointe clairement vers l'une ou l'autre, jamais les deux à la
fois.

## 2. Pourquoi la réouvrir maintenant

Au moment de la phase v2-H (création d'`ImageTransform`), la
feature ne pouvait opérer que sur des images construites
artificiellement en mémoire dans les tests — aucun vrai fichier
image ne pouvait entrer ni sortir. Une UI à ce moment-là n'aurait
eu aucune donnée réelle à manipuler.

Le pont d'entrée/sortie (`ImageIOBridge`, livré dans la PR #16) a
changé cette situation : il existe désormais un chemin complet et
testé — fichier image réel → transformation → fichier image réel.
Le blocage qui justifiait Option Y a disparu. La réouverture ne
viole donc pas une interdiction : elle constate qu'une règle de
séquencement a atteint son terme naturel.

## 3. Les 6 décisions tranchées

| # | Décision | Choix retenu |
|---|---|---|
| D1 | Option Y maintenu ou rouvert ? | **Rouvert** : le blocage réel a disparu |
| D2 | Périmètre de features | **ImageTransform + pont E/S**, pas SheetReader (besoin distinct) |
| D3 | Premier incrément UI | **Charger/sauver + appliquer une opération**, sans aperçu ni chaînage |
| D4 | Contraintes | Logique non modifiée, export PNG uniquement, `ServiceLocator` tranché avant le code |
| D5 | Critères de succès | CI verte, roundtrip inchangé, pattern respecté, PNG-only garanti |
| D6 | Enregistrement `ServiceLocator` | **Ajouté** pour la nouvelle feature (cohérent avec les 3 autres features UI) |

*(`ServiceLocator` : un annuaire central du projet qui associe
chaque type de service à son implémentation concrète, pour que les
`ViewModel` n'aient pas besoin de savoir comment construire les
services dont ils dépendent.)*

## 4. Le périmètre de l'onglet « Image »

L'onglet permet, dans cet ordre :

- **Importer une image** (PNG ou JPEG) depuis le disque.
- **Choisir une opération** parmi les six proposées par
  `ImageTransformService` : rotation 90°/180°/270°, miroir
  horizontal, miroir vertical, inversion des couleurs.
- **Appliquer** l'opération choisie.
- **Exporter** le résultat, toujours en PNG.

Deux fonctionnalités ont été délibérément exclues de ce premier
incrément :

- **L'aperçu visuel** de l'image (avant/après) : afficher une image
  dans l'interface à partir de données de pixels bruts n'est pas
  trivial et mérite son propre chantier, séparé de celui-ci.
- **Le chaînage de plusieurs transformations** : cette question a
  déjà été posée et reportée lors d'une phase précédente
  (« v2-D-bis », jamais réalisée) ; la traiter ici aurait rouvert
  un débat déjà tranché ailleurs.

## 5. Les angles morts traités

Avant de coder, un avis critique a identifié quatre points de
vigilance, plus un cinquième soulevé lors de la reconstitution
d'Option Y :

- **Menu des opérations** : la liste des six opérations devait être
  relue depuis le fichier réel plutôt que reconstruite de mémoire,
  pour éviter d'afficher une liste obsolète. → Confirmée correcte.
- **Gestion des erreurs à l'import** : le pont E/S peut échouer
  (fichier illisible, format non pris en charge...). → Chaque cas
  d'erreur possible est traduit en message lisible pour
  l'utilisateur, jamais un échec silencieux.
- **Export strictement en PNG** : un utilisateur pourrait taper une
  autre extension dans le champ de nom de fichier. → Voir section 7.
- **Retour utilisateur sans aperçu visuel** : sans image affichée,
  l'utilisateur a besoin d'un signal de confirmation clair. → Un
  message de statut textuel confirme chaque étape (import réussi,
  transformation appliquée, chemin d'export).
- **Enregistrement dans le `ServiceLocator`** : la nouvelle feature
  devait suivre le même schéma d'enregistrement que les trois
  features UI précédentes, pour ne pas introduire une exception de
  pattern non justifiée. → Ajouté.

## 6. Trois déviations documentées

Trois écarts mineurs par rapport à une lecture strictement
littérale du brief ont été pris, tous dans le même esprit : ne pas
toucher aux fichiers de logique déjà validés par les tests.

- **Pas d'enregistrement `ServiceLocator` pour `ImageIOBridge`** :
  ce composant est un ensemble de fonctions statiques (comme une
  boîte à outils, pas un service qu'on injecte) — il n'existe rien
  à enregistrer pour lui.
- **Sélection de l'opération via une chaîne de caractères** plutôt
  que directement via le type `ImageOperation` : cela évite de
  devoir modifier ce type dans son fichier d'origine juste pour les
  besoins de l'affichage.
- **Les noms lisibles des opérations** (« Rotation 90° », etc.)
  vivent dans le fichier de l'interface, pas dans le fichier des
  modèles de données — une question de présentation n'a pas sa
  place dans un fichier qui décrit uniquement la structure des
  données.

## 7. La garantie « PNG uniquement »

Le protocole qui abstrait la fenêtre de sauvegarde système
(`SavePanelProviding`) ne permet pas, dans sa version actuelle, de
restreindre les types de fichiers proposés à l'utilisateur au
moment de la saisie. Modifier ce protocole aurait élargi le
périmètre de ce chantier au-delà de ce qui était prévu.

La garantie retenue est donc **structurelle plutôt que
préventive** : quel que soit le nom de fichier saisi par
l'utilisateur, le code réécrit systématiquement son extension en
`.png` avant d'écrire quoi que ce soit sur le disque. Il est donc
impossible, par construction, d'obtenir un fichier de sortie avec
une autre extension — pas parce que la fenêtre l'empêche, mais
parce que le code qui suit ne produit jamais que du PNG, quel que
soit le nom demandé.

## 8. Le filet externe et la leçon de discipline

Une partie du code (les trois fichiers de configuration de
l'application) a été écrite sans relecture fraîche des fichiers
réels, en s'appuyant sur le souvenir de leur contenu. La
vérification systématique du contenu réel avant d'écraser ces
fichiers a révélé une perte d'information : des commentaires
explicatifs présents dans les fichiers d'origine avaient été omis
dans la reconstruction. Rien d'incorrect dans le comportement du
code — uniquement de la documentation interne manquante. Les
fichiers ont été recréés en préservant ces commentaires en plus des
nouveaux ajouts.

Cet épisode illustre une distinction utile : la mémoire d'une
session peut rester fiable sur la structure générale et le
comportement d'un code (ce que la réussite de la compilation et des
tests confirme indirectement), sans être fiable sur son contenu
exact au caractère près. Les deux vérifications sont
complémentaires, ni l'une ni l'autre ne suffit seule.

Un second épisode, distinct, mérite d'être noté pour la symétrie :
au cours de la même session, une inquiétude a été soulevée quant à
une possible troncature d'un fichier, sur la seule foi de l'aspect
visuel d'un affichage. Une vérification directe du contenu a
montré que le fichier était complet — la crainte était infondée.
Le même réflexe de vérification qui, dans un cas, confirme un vrai
problème, permet dans l'autre d'écarter une fausse alerte. C'est là
tout l'intérêt de vérifier plutôt que de supposer, dans les deux
sens.

## 9. Validation

- CI (intégration continue) verte : la compilation réussit et tous
  les tests passent.
- Les tests qui garantissent l'exactitude des transformations
  (roundtrip bit à bit, c'est-à-dire qu'appliquer une opération
  puis son inverse redonne exactement l'image d'origine, octet par
  octet) n'ont pas été modifiés et restent verts — preuve que la
  logique de transformation elle-même n'a subi aucune altération.
- Le code a été intégré au projet principal, puis les branches de
  travail synchronisées et nettoyées.

## 10. Bilan

L'onglet « Image » est disponible dans l'application. Il permet
d'importer une image réelle, de lui appliquer une transformation
réversible et de l'exporter en PNG. La logique de transformation
et le pont d'entrée/sortie qu'il utilise n'ont subi aucune
modification au cours de ce chantier — le principe qui avait
justifié Option Y (séparer l'axe « calcul » de l'axe « interface »)
a été respecté jusqu'au bout, y compris dans l'acte même de
réouvrir Option Y.
