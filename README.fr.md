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

## Principes clés

- Traitement 100% local, aucune dépendance réseau, aucun backend, aucune fonctionnalité cloud.
- Séparation stricte entre UI, logique métier, services, modèles et tests.
- Architecture feature-based (vertical slicing) : chaque fonctionnalité est un module autonome.
- MVVM, conception orientée protocoles, gestion explicite des erreurs, aucune logique dans les
  vues.

## Fonctionnalités (périmètre v1)

- Encodage/décodage Base64 de texte.
- Import/export de fichiers texte et binaires.
- Chiffrement symétrique local avec mot de passe (CryptoKit, authentifié).
- Aperçu de la sortie et copie dans le presse-papiers.
- Tests unitaires couvrant les scénarios de roundtrip et d'erreurs.

## Architecture

```text
SwiftUIToolLab/
├── App/
├── Features/
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   └── Settings/
├── Core/
│   ├── Workspace/
│   ├── Protocols/
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
| `ConfigurableTransformer` | Avec paramètres, sans secret | Redimensionnement d'image |
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
- [x] Phase 2 — ServiceLocator, injection de dépendances, une feature minimale (compile et
      affiche une vue)
- [x] Phase 3 — Implémentation complète de Base64 avec tests passants
- [x] Phase 4 — Implémentation complète de Crypto avec tests passants
- [x] Phase 5 — Implémentation complète de FileImportExport avec tests passants
- [x] Phase 6 — Intégration croisée des fonctionnalités et tests de roundtrip

## Contribuer

Les contributions suivent la convention Conventional Commits et une stratégie de branches
`main` / `dev` / `backup`. Les pull requests sont fusionnées en squash-merge, avec suppression de
la branche source après fusion.

## Licence

Distribué sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

## Auteur

Maintenu par [@valorisa](https://github.com/valorisa).
