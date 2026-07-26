![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/valorisa/SwiftUIToolLab/actions/workflows/ci.yml/badge.svg)
![Status](https://img.shields.io/badge/status-en%20d%C3%A9veloppement-yellow)

**Lire ce document dans une autre langue : [English](README.md)**

# SwiftUIToolLab

Une application macOS native, locale, modulaire et testable, construite avec SwiftUI, dédiée aux
**transformations de données réversibles** : encodage, décodage, chiffrement, déchiffrement, et
import/export de fichiers. La transformation visuelle d'images et de pages imprimées est prévue
pour une étape ultérieure.

> **Statut :** la v1 est terminée (Phases 0–6). La v2 est en cours : localisation, sécurité,
> testabilité, composition et un démonstrateur d'opérateur linéaire sont faits ; un encodeur
> linéaire réversible (v2-F) et la transformation d'images/OCR sont à venir.

## Principes clés

- Traitement 100% local, aucune dépendance réseau, aucun backend, aucune fonctionnalité cloud.
- Séparation stricte entre UI, logique métier, services, modèles et tests.
- Architecture feature-based (vertical slicing) : chaque fonctionnalité est un module autonome.
- MVVM, conception orientée protocoles, gestion explicite des erreurs, aucune logique dans les vues.

## Fonctionnalités (périmètre v1)

- Encodage/décodage Base64 de texte.
- Import/export de fichiers texte et binaires.
- Chiffrement symétrique local avec mot de passe (CryptoKit, authentifié).
- Aperçu de la sortie et copie dans le presse-papiers.
- Tests unitaires couvrant les scénarios de roundtrip et d'erreurs.

## Fonctionnalités (périmètre v2)

La v2 renforce et étend la v1 selon cinq axes. Les six phases ci-dessous sont terminées et validées
par la CI.

- **Phase 7 (v2-A) — Localisation :** localisation complète EN/FR de l'UI (41 clés), avec un test
  robuste garantissant la parité des clés, l'absence de valeur vide, et l'absence de valeur FR
  identique à l'EN hors liste d'exception explicite. `FileImportExportError` est localisée via
  `LocalizedError`.
- **Phase 8–9 (v2-B, v2-B-bis) — Sécurité :** modèle de menace complet pour de vrais secrets : le
  mot de passe est purgé après chaque opération (succès ou échec) ; les payloads sensibles mettent
  à jour `currentPayload` mais ne sont jamais ajoutés à l'historique (undo les saute) ; les textes
  sensibles sont purgés au changement d'onglet via une purge globale, non cosmétique (VMs +
  rechargement, pas un simple effacement de surface). Base64 n'est pas purgé (pas un secret par
  construction).
- **Phase 10 (v2-C) — Testabilité :** panels injectables (`OpenPanelProviding` /
  `SavePanelProviding`, avec les conformances `OpenPanelWrapper` / `SavePanelWrapper`) rendent
  `FileImportExportViewModel` testable de bout en bout avec des mocks. Ferme la dette D5 de la v1.
- **Phase 11 (v2-D) — Composition :** `PipelineService` (dans `Core/`) compose une séquence de
  closures de transformation via un unique `reduce`. Aucun nouveau protocole : il réutilise
  `ReversibleTransformer` / `SecuredTransformer`. 8 tests, dont une équivalence comportementale avec
  le chaînage manuel de la Phase 6b.
- **Phase 12 (v2-E) — Démonstrateur LinearOperator :** premier usage réel de
  `ConfigurableTransformer` (13 phases après sa création). Une feature `LinearOperator` mesure le
  rang d'une matrice (élimination de Gauss, pivot partiel) et son conditionnement (approximation par
  norme de Frobenius) sur une fixture déterministe (rang ≤ 2 prouvé). Elle *mesure*, elle ne
  construit pas un encodeur fonctionnel — c'est la phase suivante. Pas d'UI (la sortie = les tests +
  un récit d'origine dans le code qui garde le mot « Jacobienne » hors de tous les symboles).

## Architecture

```text
SwiftUIToolLab/
├── App/
├── Features/
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   ├── LinearOperator/
│   └── Settings/
├── Core/
│   ├── Workspace/
│   ├── Protocols/
│   ├── Pipeline/
│   ├── Serialization/
│   └── Extensions/
├── IntegrationTests/
├── Resources/
└── README.md
```

Chaque fonctionnalité ne communique avec les autres qu'à travers des protocoles définis dans
`Core/Protocols/`. Le `Workspace` est un conteneur de données pur : il n'implémente jamais de
logique métier (pas de `encrypt()`, pas de `base64Encode()`).

### La trinité des transformateurs

Trois protocoles distincts plutôt qu'un protocole générique avec dictionnaire de configuration :

| Protocole | Cas d'usage | Exemple |
|---|---|---|
| `ReversibleTransformer` | Sans paramètre, réversible 1:1 | Base64, ROT13 |
| `ConfigurableTransformer` | Avec paramètres, sans secret | Redimensionnement d'image, opérateurs linéaires (v2-E) |
| `SecuredTransformer` | Avec secret authentifié | Chiffrement, signature |

### Format de fichier

Toute exportation produit un unique fichier `.cryptolab` (ou `.clab`) versionné, regroupant la
charge utile, l'en-tête de chiffrement et les métadonnées. L'utilisateur ne gère jamais séparément
les clés, IV ou métadonnées.

## Prérequis

- macOS 14+
- Xcode 15+
- Swift 5.9+

## Démarrage

```bash
git clone https://github.com/valorisa/SwiftUIToolLab.git
cd SwiftUIToolLab
open SwiftUIToolLab.xcodeproj
```

## Tests

Chaque fonctionnalité suit une séquence stricte protocole → test → implémentation, avec trois
niveaux de couverture : logique métier mockée, robustesse face aux fichiers corrompus, et alertes
natives macOS.

```bash
xcodebuild test -scheme SwiftUIToolLab -destination 'platform=macOS'
```

## Feuille de route

- [x] Phase 0 — Arborescence et fichiers vides avec `// MARK: - TODO`
- [x] Phase 1 — Core/Workspace, modèles et protocoles (compile)
- [x] Phase 2 — ServiceLocator, injection de dépendances, une feature minimale (compile et affiche une vue)
- [x] Phase 3 — Implémentation complète de Base64 avec tests passants
- [x] Phase 4 — Implémentation complète de Crypto avec tests passants
- [x] Phase 5 — Implémentation complète de FileImportExport avec tests passants
- [x] Phase 6 — Intégration croisée des fonctionnalités et tests de roundtrip
- [x] Phase 7 (v2-A) — Localisation (41 clés EN/FR, test robuste, erreurs localisées)
- [x] Phase 8 (v2-B) — Sécurité : purge du mot de passe + payloads sensibles exclus de l'historique
- [x] Phase 9 (v2-B-bis) — Sécurité : purge des textes sensibles au changement d'onglet, purge globale
- [x] Phase 10 (v2-C) — Panels injectables (ferme la dette D5 de la v1)
- [x] Phase 11 (v2-D) — Pipeline-service (composition pure dans Core/)
- [x] Phase 12 (v2-E) — Démonstrateur LinearOperator (mesure rang/conditionnement)
- [x] Phase 13 (v2-F) — Opérateur linéaire réversible (matrice unimodulaire, gestion de plage)
- [x] Phase 14 (v2-G) — SheetReader : lire la vraie feuille via Vision OCR (boucle la boucle Jacobienne) — fait

## Contribuer

Les contributions suivent la convention Conventional Commits et une stratégie de branches
`main` / `dev` / `backup`. Les pull requests sont fusionnées en squash-merge, avec suppression de
la branche source après fusion.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

## Auteur

Maintenu par [@valorisa](https://github.com/valorisa).
