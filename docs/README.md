# Obsidian Gate — Centre de documentation

Ce dossier rassemble les décisions produit, le cahier des charges, les recherches techniques et le plan d'exécution. Mettre à jour ce point d'entrée à chaque décision structurante.

## Documents de référence

| Document | Rôle | Statut |
| --- | --- | --- |
| [CDCF — Cahier des charges fonctionnel](CDCF-OBSIDIAN-GATE.md) | Parcours badge → défi → Touch ID → déverrouillage interne, exigences, sécurité, critères d'acceptation | Première version rédigée ; validation matérielle à faire |
| [MVP — Direction produit](OBSIDIAN-GATE-MVP.md) | Vision, périmètre MSA, coach hybride, confidentialité, phases | Décisions produit consignées |

## Décisions confirmées

- Langue cible du MVP : arabe moderne standard (MSA/Fusha).
- Arabe coranique : hors périmètre.
- Coach : hybride, local-first ; cloud facultatif et opt-in.
- Vault Obsidian : espace documentaire et destination des rapports Markdown.
- Données opérationnelles : stockage local ; pas de base SQLite active dans iCloud Drive.
- Sources : ouvertes en priorité ; sources commerciales uniquement avec droits compatibles.
- NFC/RFID : déclencheur de session, pas preuve d'identité forte.
- Touch ID : authentification d'une action dans l'application Gate ; aucun déverrouillage de la session macOS.
- LearnKit : base amont à préserver ; conserver licences et notices tierces.

## Architecture cible (vue d'ensemble)

1. **LearnKit / Obsidian plugin** — cartes, FSRS, exercices, coach, profil d'apprentissage, intégration Daily Notes.
2. **Arabic MSA domain** — normalisation, lexique, lemme/racine quand connu, morphologie, variantes de réponses et provenance.
3. **Coach** — interface provider-neutral, local par défaut, cloud opt-in, sortie structurée et validée.
4. **Gate macOS companion** — SwiftUI, machine à états, adaptateur lecteur, LocalAuthentication, verrouillage applicatif.
5. **Storage** — SQLite local pour l'état opérationnel ; Markdown pour les notes et rapports que l'utilisateur souhaite conserver.

## Plan directeur

- **P0 — Baseline & audit :** vérifier `npm ci`, `npm test`, `npm run build`, `npm run check` ; inventorier FSRS, stockage, clés, contexte Companion et Daily Notes.
- **P1 — Contrats :** figer schémas d'événements, machine à états, modèle de menace et architecture des adaptateurs.
- **P2 — POC macOS :** vérifier LocalAuthentication/Touch ID sur la machine cible sans action sur le login macOS.
- **P3 — POC matériel :** détecter Chameleon V3, version firmware, scan HF de badges de laboratoire, déconnexion et timeouts.
- **P4 — MSA offline :** lexique, normalisation, exercices et validation déterministe.
- **P5 — Adaptation :** relier profil de compétences et FSRS sans remplacer le scheduler.
- **P6 — Coach hybride :** local-first, cloud facultatif, validation des sorties et contrôle de contexte.
- **P7 — Daily Notes :** aperçu, confirmation, bloc idempotent non destructif.
- **P8 — Hardening & release :** tests, migrations, documentation, accessibilité, audit sécurité et publication.

## Registre de recherches et références

### Apple — biométrie

- [LAContext](https://developer.apple.com/documentation/localauthentication/lacontext) — vérification de disponibilité (`canEvaluatePolicy`), évaluation (`evaluatePolicy`), politiques et invalidation de contexte.
- [Logging a User into Your App with Face ID or Touch ID](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id) — exemple de flux d'authentification applicative et choix de politique biométrique / repli par code.
- [evaluatePolicy](https://developer.apple.com/documentation/localauthentication/lacontext/evaluatepolicy(_:localizedreason:reply:)) — raison localisée claire ; succès passé ne garantit pas une autorisation future.

### Chameleon Ultra — RFID/NFC

- [Guide officiel communautaire](https://github.com/RfidResearchGroup/ChameleonUltra/wiki) — CLI, SDK, firmware, protocoles et dépannage.
- [Protocole](https://github.com/RfidResearchGroup/ChameleonUltra/wiki/protocol) — versionnement firmware/protocole ; commande `hf 14a scan` pour HF ISO14443-A et commandes LF dédiées.
- [Dépôt Chameleon Ultra](https://github.com/RfidResearchGroup/ChameleonUltra) — matériel, firmware et licence GPL-3.0.
- Recommandation : utiliser le CLI/SDK/protocole documenté, identifier les capacités réelles et tester sur le V3. Ne pas promettre UHF ni toutes les technologies LF/HF avec le même lecteur.

### Base logicielle et apprentissage

- [LearnKit](https://github.com/ctrlaltwill/LearnKit) — base Obsidian existante ; préserver MIT et les notices tierces.
- [ts-fsrs](https://github.com/open-spaced-repetition/ts-fsrs) — scheduler FSRS à réutiliser ; le LLM ne modifie pas directement l'état FSRS.

## Registre des décisions à compléter

| Sujet | Recommandation initiale | À confirmer |
| --- | --- | --- |
| Durée soft-unlock | 2 min d'inactivité, verrouillage à fermeture | Oui, lors du POC |
| Politique Touch ID | biométrie seule pour le Gate ; fallback explicite et configurable si souhaité | Oui, selon usage réel |
| Badge | HF ISO14443-A en premier, LF si capacité vérifiée | Oui, avec les badges réels autorisés |
| UHF | lecteur dédié ultérieur | Oui, après inventaire des badges à supporter |
| Liaison plugin/macOS | canal local authentifié et versionné | Oui, après POC |

## Journal de réalisation

- Branche de travail : `project/obsidian-gate-foundation`.
- Premier document produit : `OBSIDIAN-GATE-MVP.md`.
- CDCF badge / Touch ID : `CDCF-OBSIDIAN-GATE.md`.
- POC macOS ajouté dans `apps/macos/ObsidianGateMac` : Touch ID via LocalAuthentication, découverte USB IOKit, machine à états Gate et premiers tests XCTest.
- La découverte USB observe les périphériques IOUSBHost ; elle ne parle pas encore au protocole Chameleon et ne lance pas de scan RFID. VID/PID du Chameleon à relever sur le Mac réel avant filtrage.
- Les tests XCTest et la compilation Swift doivent encore être exécutés sur macOS ; aucune réussite de build n'est revendiquée.
- Prochaine action technique : valider `swift test` / `swift build` sur le Mac cible, relever VID/PID/firmware du Chameleon V3, puis implémenter l'adaptateur protocole documenté.
