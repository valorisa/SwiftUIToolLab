![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/valorisa/SwiftUIToolLab/actions/workflows/ci.yml/badge.svg)

**Lire ce document en anglais : [English](README.md)**

# SwiftUIToolLab

## C'est quoi ?

SwiftUIToolLab est une application pour Mac qui vous permet de **transformer des données de
manière réversible**. « Réversible » veut dire une chose simple : vous pouvez toujours revenir
en arrière, **sans jamais perdre l'information d'origine**. Appliquer une transformation puis
son inverse redonne exactement la donnée de départ, octet par octet.

Concrètement, l'application propose quatre onglets :

- **Base64** — transformer un texte ou un fichier en texte pur, et revenir en arrière ;
- **Crypto** — chiffrer un texte avec un mot de passe, et le déchiffrer ;
- **Files** — importer et exporter des fichiers texte ou binaires ;
- **Image** — importer une image, la pivoter ou la retourner, et l'exporter (nouveau).

**Tout se passe sur votre ordinateur.** Rien n'est envoyé sur internet, il n'y a aucun compte
à créer, aucun serveur distant. Vos données ne quittent jamais votre machine.

## Pourquoi ce projet ?

Il existe beaucoup d'outils en ligne pour encoder du Base64 ou chiffrer un texte. Le problème :
ces outils envoient vos données sur des serveurs que vous ne contrôlez pas. Pour des données
sensibles, c'est un risque.

SwiftUIToolLab fait le choix inverse : **le traitement est 100 % local**. C'est la garantie la
plus simple qui soit pour la confidentialité — si rien ne sort de votre ordinateur, rien ne peut
être intercepté.

C'est aussi, assumé, un **projet d'apprentissage** : il explore comment construire une
application macOS qui soit à la fois modulaire (chaque fonctionnalité est un module indépendant),
testable (chaque module est couvert par des tests automatisés) et sûre (les secrets comme les
mots de passe sont effacés de la mémoire dès qu'ils ne servent plus).

## Que peut faire l'application ?

Voici, pour chaque onglet, un exemple concret d'utilisation.

### Base64

Le Base64 est une façon d'écrire n'importe quelle donnée (texte, image, PDF…) sous forme de
texte pur, composé uniquement de lettres, de chiffres et de deux symboles (`+` et `/`).

**Cas d'usage :** vous voulez coller un petit fichier binaire dans un email ou un champ de
formulaire qui n'accepte que du texte. Vous l'encodez en Base64 (il devient du texte), vous le
collez, et le destinataire le décode pour retrouver le fichier **exactement identique**.

### Crypto

L'onglet Crypto chiffre un texte avec un mot de passe (chiffrement symétrique authentifié, via
la bibliothèque CryptoKit d'Apple). Sans le mot de passe, le texte chiffré est illisible.

**Cas d'usage :** vous voulez conserver une note confidentielle. Vous la chiffrez avec un mot de
passe, vous gardez le résultat chiffré. Pour la relire, vous la déchiffrez avec le même mot de
passe.

**Détail de sécurité important :** le mot de passe est **effacé de la mémoire** après chaque
opération (qu'elle réussisse ou échoue). Les textes sensibles ne sont jamais conservés dans
l'historique de l'application, et sont purgés quand vous changez d'onglet.

### Files

L'onglet Files gère l'import et l'export de fichiers (texte ou binaires).

**Cas d'usage :** vous importez un fichier, vous lui appliquez une transformation, puis vous
exportez le résultat. Toute exportation produit un unique fichier `.cryptolab` (ou `.clab`) qui
regroupe la donnée, l'en-tête de chiffrement et les métadonnées — vous n'avez jamais à gérer
séparément une clé, un IV ou des métadonnées.

### Image (nouveau)

L'onglet Image applique des transformations **réversibles** à de vraies images.

**Cas d'usage :** vous importez une photo (PNG ou JPEG), vous lui appliquez une opération
(rotation de 90°, 180° ou 270°, miroir horizontal ou vertical, inversion des couleurs), puis
vous exportez le résultat en PNG. Comme la transformation est réversible, appliquer l'opération
inverse redonnerait l'image d'origine, **octet par octet**.

L'export est **toujours en PNG** : même si vous tapez un nom de fichier terminant par `.jpg`,
le code le renomme automatiquement en `.png`. C'est une garantie **par construction** (le code
ne produit jamais que du PNG), pas une simple option à cocher.

> Deux fonctionnalités ont été volontairement laissées de côté dans cette première version de
> l'onglet Image : l'**aperçu visuel** de l'image (avant/après) et le **chaînage** de plusieurs
> transformations à la suite. Elles pourront venir plus tard, chacune faisant l'objet d'un
> chantier séparé.

## Les transformations réversibles, le cœur du projet

Toute l'application tourne autour d'une idée : des transformations qu'on peut **annuler
exactement**. Une analogie : tourner un volant de 90° à droite, puis de 90° à gauche, vous
ramène exactement à la position de départ. C'est ce que fait chaque transformation de
l'application, mais sur des données.

Pour organiser ces transformations, le code distingue trois familles (trois « protocoles », en
jargon Swift), selon la nature de l'opération :

| Famille | En une phrase | Analogie | Exemples |
|---|---|---|---|
| `ReversibleTransformer` | Sans réglage, réversible 1:1 | Une porte | Base64 |
| `ConfigurableTransformer` | Avec réglages, sans secret | Un four réglable | Image, opérateurs linéaires |
| `SecuredTransformer` | Avec secret authentifié | Un coffre-fort | Chiffrement |

Cette séparation n'est pas cosmétique : elle permet au code (et aux tests) de traiter chaque
famille selon ses règles propres — par exemple, ne jamais conserver un secret pour la troisième
famille.

## Comment l'application est-elle construite ?

Cette section s'adresse aux curieux et aux développeurs.

L'application suit une architecture **feature-based** (par fonctionnalité) : chaque onglet est
un module autonome, rangé dans son propre dossier sous `Features/`. Les modules ne se parlent
entre eux qu'à travers des **protocoles** (des contrats d'interface) définis dans un dossier
partagé `Core/Protocols/`. Résultat : on peut modifier ou tester un module sans toucher aux
autres.

Chaque onglet suit le modèle **MVVM** :

- la **View** (le « visage ») affiche l'interface et ne fait **aucun calcul** ;
- le **ViewModel** (le « cerveau ») fait le travail et fournit à la View ce qu'elle doit
  afficher ;
- le **Model** (les « données ») : ce sont les structures de données (comme `Payload`,
  `Matrix` ou `RawImage`) que le ViewModel manipule.

Un **ServiceLocator** sert d'annuaire central : il sait quelle implémentation concrète utiliser
pour chaque type de service. Analogie : un standard téléphonique qui vous met en relation avec
le bon service, sans que vous ayez à connaître son numéro direct.

### Arborescence du projet

```text
SwiftUIToolLab/
├── App/                        (point d'entrée de l'application)
├── Features/                   (un sous-dossier par onglet)
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   ├── ImageTransform/         (onglet Image — nouveau)
│   ├── LinearEncoder/
│   ├── LinearOperator/
│   ├── SheetReader/
│   └── Settings/
├── Core/                       (partagé entre les features)
│   ├── Workspace/
│   ├── Protocols/
│   ├── Pipeline/
│   ├── Serialization/
│   └── Extensions/
├── IntegrationTests/
├── Resources/
├── docs/                       (notes de décision, dont option-y-reopening.md)
└── README.md
```

## L'onglet Image et le pont d'entrée/sortie

L'onglet Image s'appuie sur deux briques ajoutées récemment :

1. **Les opérations d'image réversibles** (`ImageTransformService`) : rotation, miroir,
   inversion des couleurs, toutes prouvées inversibles et testées **octet par octet**.
2. **Le pont d'entrée/sortie** (`ImageIOBridge`) : il lit un vrai fichier image (PNG ou JPEG)
   et écrit un vrai fichier PNG. Avant lui, les transformations d'image ne fonctionnaient que
   sur des images fabriquées en mémoire dans les tests — aucune vraie image ne pouvait entrer
   ni sortir.

Pendant longtemps, les fonctionnalités de « calcul » du projet n'avaient **pas d'interface
graphique** : on validait d'abord la logique (par des tests), et on remettait l'interface à plus
tard. C'était une règle de méthode surnommée **« Option Y »** (« un chantier de calcul ne
mélange pas une décision d'interface »). L'onglet Image marque la **réouverture** de cette
règle : la logique et le pont d'entrée/sortie étant validés, l'interface devenait possible.

> Pour le détail de cette décision (pourquoi la règle existait, pourquoi elle a été rouverte,
> les choix faits, les précautions prises), voir la note dédiée :
> [`docs/option-y-reopening.md`](docs/option-y-reopening.md) (en français).

## L'histoire du projet, étape par étape

Le projet a été construit par couches successives, chacune ajoutant un niveau de maturité.

**La v1 — les fondations.** Mise en place de la structure, des trois premiers onglets (Base64,
Crypto, Files) et des tests automatisés (dont des tests de « roundtrip » : encoder puis décoder
doit redonner exactement la donnée d'origine).

**La v2 — le renforcement.** La v2 a renforcé et étendu la v1 selon **plusieurs axes**,
regroupés ci-dessous en cinq thèmes (le dernier regroupe à lui seul quatre fonctionnalités) :

- la **traduction** complète de l'interface en français et en anglais ;
- la **sécurité** : effacement systématique des mots de passe et des textes sensibles de la
  mémoire ;
- la **testabilité** : les fenêtres d'ouverture/enregistrement de fichiers peuvent être
  remplacées par des simulacres dans les tests ;
- la **composition** : un service permet d'enchaîner plusieurs transformations à la suite ;
- une famille de **transformateurs configurables**, déclinée en quatre features : un
  démonstrateur d'algèbre linéaire (mesure du rang d'une matrice), un encodeur linéaire
  réversible, un lecteur de feuille par reconnaissance de caractères (OCR), et les opérations
  d'image.

Chaque étape a été validée par l'**intégration continue** (CI) : à chaque modification, le
projet est recompilé et tous les tests sont rejoués automatiquement.

## Pour les développeurs

### Prérequis

- macOS 14 ou plus récent ;
- Xcode 15 ou plus récent ;
- Swift 5.9 ou plus récent.

### Démarrage

```bash
git clone https://github.com/valorisa/SwiftUIToolLab.git
cd SwiftUIToolLab
open SwiftUIToolLab.xcodeproj
```

### Lancer les tests

```bash
xcodebuild test -scheme SwiftUIToolLab -destination 'platform=macOS'
```

Chaque fonctionnalité suit une séquence stricte : **protocole → test → implémentation**. On
écrit d'abord le contrat (protocole), puis les tests, puis le code qui fait passer les tests.

### Contribuer

Les contributions suivent la convention **Conventional Commits** et une stratégie de branches
`main` / `dev` / `backup`. Les pull requests sont fusionnées en **squash-merge** (tous les
commits d'une branche sont regroupés en un seul), et la branche source est supprimée après
fusion.

## Feuille de route

Les étapes suivantes sont **terminées** et validées par la CI :

- [x] Phases 0–6 (v1) — structure, Base64, Crypto, Files, intégration et tests de roundtrip
- [x] Phase 7 (v2-A) — traduction français/anglais (41 clés)
- [x] Phases 8–9 (v2-B, v2-B-bis) — sécurité (effacement des secrets)
- [x] Phase 10 (v2-C) — panneaux de fichiers injectables (testabilité)
- [x] Phase 11 (v2-D) — service de composition (enchaînement de transformations)
- [x] Phase 12 (v2-E) — démonstrateur d'opérateur linéaire (mesure rang/conditionnement)
- [x] Phase 13 (v2-F) — encodeur linéaire réversible (matrice unimodulaire)
- [x] Phase 14 (v2-G) — lecteur de feuille laser par OCR (Vision)
- [x] Phase 15 (v2-H) — opérations d'image réversibles (rotation/miroir/inversion, octet par octet)
- [x] Pont d'entrée/sortie image (PR #16) — lire/écrire de vrais fichiers image (JPEG en entrée, PNG en sortie)
- [x] Onglet Image (PR #17) — interface graphique pour les transformations d'image
- [x] Note de décision Option Y (PR #18) — documentation de la réouverture de la règle

**Pistes envisagées** (non planifiées) :

- [ ] Aperçu visuel de l'image (avant/après) dans l'onglet Image
- [ ] Chaînage de plusieurs transformations d'image

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

## Auteur

Maintenu par [@valorisa](https://github.com/valorisa).
