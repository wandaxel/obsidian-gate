# CDCF — Cahier des charges fonctionnel d'Obsidian Gate

**Statut :** spécification initiale — à valider par tests sur le Mac et le Chameleon Ultra V3 réel  
**Branche :** `project/obsidian-gate-foundation`  
**Périmètre :** extension LearnKit + service de Gate macOS, avec badge facultatif et Touch ID applicatif.

## 1. Objet et vision

Obsidian Gate transforme une intention d'apprentissage en rituel de pratique court, mesurable et adaptatif. Le système s'appuie sur Obsidian pour les contenus lisibles par l'humain, sur le moteur LearnKit/FSRS pour la répétition espacée, sur un coach hybride local-first et, dans une application macOS compagnon, sur un badge NFC/RFID facultatif et une confirmation biométrique Touch ID.

Le badge est un déclencheur de session, pas une preuve d'identité forte. Touch ID autorise une action dans l'application Gate ; il ne déverrouille pas la session macOS, ne remplace pas `loginwindow` et ne contourne pas l'écran de verrouillage système.

## 2. Objectifs fonctionnels

- O1 — Démarrer une session d'apprentissage en détectant un badge configuré ou depuis l'interface, sans rendre le badge obligatoire.
- O2 — Proposer un défi adapté : révisions FSRS dues, compétence fragile, exercice MSA court.
- O3 — Évaluer la réponse avec des règles déterministes et des variantes validées ; le LLM ne décide pas seul de la correction.
- O4 — Après réussite, demander Touch ID pour autoriser l'ouverture/la levée du verrouillage interne à l'application Gate, si l'utilisateur a activé cette fonction.
- O5 — Enregistrer le résultat localement et proposer un résumé dans la Daily Note, avec aperçu et confirmation.
- O6 — Fonctionner hors ligne pour les fonctions cœur ; le cloud est facultatif et désactivé par défaut.

## 3. Périmètre et exclusions

### Inclus dans le MVP

- Arabe moderne standard (MSA/Fusha), sans programme d'arabe coranique.
- Détection de badges HF/LF que le matériel connecté sait effectivement lire, via adaptateurs de capacités.
- Chameleon Ultra V3 comme premier lecteur expérimental, derrière une interface abstraite.
- Touch ID via LocalAuthentication sur macOS, dans l'application compagnon uniquement.
- Verrouillage logique de l'interface Gate (soft-lock), session de quiz, FSRS, profil de compétences et journal d'événements.
- Export Markdown dans le vault et stockage opérationnel local.

### Exclus

- Déverrouillage de la session macOS, du trousseau de session ou de l'écran de veille système.
- Promesse de prise en charge universelle LF/HF/UHF par un lecteur unique.
- Authentification forte fondée uniquement sur l'UID d'un badge.
- Écriture, clonage ou émulation de badges d'accès tiers. Le MVP lit uniquement des identifiants de badges de test/autorisés pour son propre déclenchement.
- Arabe coranique et redistribution de corpus/dictionnaires/audio sans droits explicites.

## 4. Parcours utilisateur cible

1. L'application Gate est ouverte et en état `locked` (verrouillage interne uniquement).
2. L'utilisateur présente un badge enregistré au lecteur ou choisit « Démarrer une session » manuellement.
3. Le service matériel émet `badge.detected` avec type de technologie, identifiant pseudonymisé si possible, lecteur, horodatage et niveau de confiance.
4. La politique locale vérifie que le badge est autorisé pour déclencher une session. L'UID seul ne donne aucun droit sensible.
5. Le moteur de session sélectionne les révisions dues et un exercice ciblant une faiblesse observée.
6. L'utilisateur répond. L'évaluateur vérifie la réponse et enregistre les résultats ; le scheduler FSRS reste l'autorité sur les échéances.
7. Si les critères du défi sont atteints, Gate demande une authentification locale Touch ID avec une explication explicite.
8. Si l'authentification réussit, Gate passe à `unlocked` pour son propre périmètre, pendant une durée configurable ; sinon reste verrouillé.
9. La session est enregistrée localement. Le résumé Daily Note est présenté en aperçu ; l'utilisateur confirme l'insertion.
10. À expiration, fermeture ou verrouillage manuel, Gate revient à `locked`.

Le parcours doit rester utilisable sans badge, sans Touch ID disponible, sans réseau et sans modèle local installé. Les replis et politiques sont configurables et visibles ; ils ne doivent jamais être silencieux.

## 5. États et règles d'accès

États recommandés : `idle`, `locked`, `badge_detected`, `challenge_pending`, `challenge_active`, `challenge_passed`, `biometric_pending`, `unlocked`, `cooldown`, `error`.

Transitions clés :

- `locked` + badge autorisé -> `challenge_pending`.
- `challenge_pending` -> `challenge_active` après création locale du défi.
- `challenge_active` + réussite -> `challenge_passed`.
- `challenge_passed` + biométrie activée -> `biometric_pending`.
- `biometric_pending` + succès LAContext -> `unlocked`.
- Échec, annulation, indisponibilité ou délai dépassé -> `locked` ou `cooldown`, selon politique.
- `unlocked` + expiration/fermeture/verrouillage manuel -> `locked`.

Règles impératives :

- Une erreur matérielle ne doit jamais être interprétée comme une détection valide.
- Une réponse LLM non validée ne peut pas autoriser le passage à `challenge_passed`.
- Aucun événement badge ne peut à lui seul provoquer `unlocked`.
- L'application ne doit pas tenter de manipuler le verrouillage système macOS.
- Journaliser les décisions de sécurité sans conserver de secret ni de donnée biométrique.

## 6. Exigences badge et RFID/NFC

### 6.1 Interface d'adaptateur

Définir une interface indépendante du fournisseur, par exemple :

- `discoverReaders()` — lecteurs disponibles et capacités déclarées.
- `connect(readerId)` / `disconnect()`.
- `getCapabilities()` — familles de fréquences/protocoles réellement prises en charge.
- `scan(options)` — lecture non destructive et temporisée.
- `cancelScan()`.
- événements `reader.connected`, `reader.disconnected`, `badge.detected`, `reader.error`.

Les données renvoyées doivent distinguer clairement : technologie, protocole, UID/identifiant, métadonnées radio, source lecteur, version firmware et horodatage. Les identifiants doivent être hachés/salés localement pour les journaux et analytics ; l'application ne doit pas enregistrer les dumps bruts de cartes.

### 6.2 Chameleon Ultra V3

Le Chameleon Ultra dispose d'une documentation communautaire officielle, d'un CLI et d'un protocole versionné. La documentation décrit un mode lecteur et des commandes de scan HF ISO14443-A (`hf 14a scan`) ainsi que des commandes LF comme EM410X et HID Prox. L'intégration doit utiliser le CLI/SDK/protocole officiel et détecter la version firmware ; ne pas coder en dur une hypothèse de compatibilité.

POC matériel recommandé :

1. Détecter la connexion USB et relever version firmware/protocole.
2. Passer en mode lecteur uniquement si nécessaire et restaurer proprement l'état précédent à la déconnexion.
3. Scanner un badge de test HF ISO14443-A ; valider les réponses et les timeouts.
4. Tester séparément une carte LF prise en charge, sans promettre le support de tous les formats.
5. Simuler déconnexion, badge inconnu, réponses invalides et lecteur occupé.

Le Chameleon Ultra ne couvre pas toutes les technologies de badges. UHF (typiquement 860–960 MHz) demandera un lecteur dédié. Pour élargir les technologies LF/HF, évaluer un Proxmark3 comme second adaptateur, sous réserve de tests matériels et de licence ; UHF reste un matériel séparé.

### 6.3 Politique de sécurité badge

- Le badge est un facteur de commodité / déclencheur, pas un facteur d'authentification autonome.
- Ne pas faire confiance à l'UID seul : il peut être copié ou émulé selon technologie.
- Prévoir liste d'autorisation locale, révocation, temporisation anti-rejeu et limitation de fréquence.
- Ne jamais écrire/cloner une carte d'accès réelle ; tests uniquement avec badges personnels/de laboratoire explicitement autorisés.
- Les fonctions d'accès sensibles restent protégées par la politique macOS et Touch ID, pas par la seule lecture RFID.

## 7. Exigences Touch ID / LocalAuthentication

- Utiliser `LAContext` et vérifier `canEvaluatePolicy` avant l'appel d'authentification.
- Choisir explicitement la politique : biométrie seule si le produit exige Touch ID ; politique avec repli code système si le propriétaire décide qu'un fallback est acceptable. Le comportement doit être expliqué dans les réglages.
- Appeler `evaluatePolicy` avec une raison localisée et précise (ex. « Confirmer l'ouverture de votre session Obsidian Gate »).
- Traiter séparément succès, refus, annulation utilisateur, verrouillage biométrique, indisponibilité, erreur système et timeout.
- Créer un contexte par tentative et l'invalider après usage ; ne jamais stocker ni manipuler de gabarit biométrique.
- Aucun succès antérieur ne doit être considéré comme une autorisation permanente. Toute réutilisation éventuelle doit suivre les limites Apple et une politique explicite.
- Touch ID ne fournit pas à l'application les données biométriques ; elle reçoit le résultat d'évaluation de la politique.
- Après succès, n'autoriser que l'action interne prévue et limiter la durée du déverrouillage Gate.

## 8. Architecture cible

### Plugin Obsidian (TypeScript)

- Réutiliser LearnKit pour cartes, révisions, FSRS, coach et vues.
- Ajouter les modules arabes MSA, profil de compétences, règles de correction, registre de sources et générateur de Daily Note.
- Les APIs d'Obsidian restent le point d'intégration au vault ; ne pas synchroniser une base SQLite active via iCloud.

### Application macOS compagnon (Swift / SwiftUI)

- `GateApp` — interface et cycle de vie.
- `GateStateMachine` — transitions d'état testables.
- `GateHardware` — protocole de lecteur et adaptateur Chameleon.
- `GateSecurity` — LocalAuthentication, règles de session et audit local.
- `GateBridge` — échange local authentifié avec le plugin, sans exposer de port réseau non protégé.

### Stockage et communication

- Base opérationnelle locale (SQLite dans Application Support ou stockage plugin local, selon responsabilités).
- Markdown uniquement pour les rapports et contenus que l'utilisateur veut conserver dans le vault.
- Échange app/plugin par canal local documenté et authentifié ; versionner le schéma d'événements.
- Cloud LLM désactivé par défaut ; aucune synchronisation de secrets dans le vault/iCloud.

## 9. Contrats d'événements

Événements minimums :

- `badge.detected`
- `challenge.requested`
- `challenge.presented`
- `answer.submitted`
- `challenge.passed`
- `challenge.failed`
- `biometric.requested`
- `biometric.succeeded`
- `biometric.failed`
- `gate.unlocked`
- `gate.locked`
- `session.completed`
- `daily-note.previewed`
- `daily-note.applied`

Chaque événement porte `eventId`, `schemaVersion`, `timestamp`, `sessionId` et une charge utile minimale. Pas de clé API, de données biométriques, ni de dump RFID dans les événements.

## 10. Exigences non fonctionnelles

- Offline-first : scan local, défi, correction déterministe, scheduler et stockage fonctionnent sans réseau.
- Privacy by default : télémétrie désactivée, collecte minimale, contexte LLM visible, cloud opt-in.
- Robustesse : timeouts, annulation, déconnexion USB, reprise après crash, migrations de schéma.
- Accessibilité : VoiceOver, navigation clavier, contraste et tailles de texte macOS.
- Internationalisation : interface française et anglaise au départ ; contenu arabe MSA avec affichage RTL correct.
- Traçabilité : provenance et licence de chaque ressource pédagogique.
- Maintenabilité : adaptateurs matériels séparés, protocoles versionnés, tests unitaires et intégration.

## 11. Critères d'acceptation

1. Sans lecteur connecté, l'utilisateur peut lancer une session manuellement.
2. Avec Chameleon connecté, un badge HF de test est détecté et un badge inconnu ne déverrouille rien.
3. Débrancher le lecteur pendant un scan ne fait pas planter Gate et ne crée pas de faux événement badge.
4. Le système identifie explicitement les capacités non prises en charge au lieu de les supposer.
5. Une réponse fausse ou non vérifiable n'autorise pas la biométrie.
6. Si Touch ID est indisponible ou annulé, Gate reste verrouillé et explique le résultat.
7. Si Touch ID réussit, seule l'interface Gate est déverrouillée ; la session macOS reste sous le contrôle du système.
8. L'application ne conserve aucune donnée biométrique.
9. Le résumé Daily Note est prévisualisé et l'application répétée ne duplique pas le bloc.
10. Les scénarios hors ligne passent les tests.

## 12. Plan de réalisation et de validation

| Étape | Livrable | Vérification / décision de sortie |
| --- | --- | --- |
| A. Baseline | tests, build, check, inventaire dépendances et architecture LearnKit | CI verte ; aucune régression introduite |
| B. Contrat de sécurité | machine à états, modèle de menace, schéma événements | transitions et cas d'échec testés |
| C. Touch ID POC | petite app Swift testant LAContext sur le Mac cible | succès/annulation/indisponibilité/fallback vérifiés ; aucun unlock macOS revendiqué |
| D. Chameleon POC | détection USB, version firmware, scan HF de badge laboratoire | tests avec matériel réel, timeout et déconnexion |
| E. Gate local | orchestrateur badge → défi → évaluation → Touch ID → soft-unlock | aucun bypass ; journal d'audit local minimal |
| F. MSA adaptive | vocabulaire, normalisation, exercices, FSRS | tests de langue déterministes et session offline |
| G. Daily Note | preview/confirm, bloc possédé, idempotence | aucun texte utilisateur modifié hors bloc Gate |
| H. Hardening | threat model, tests de fuzzing des réponses lecteur, migrations, documentation | revue sécurité et procédure de récupération |

## 13. Risques et décisions ouvertes

- Compatibilité Chameleon V3 : dépend du firmware, du CLI et du mode de connexion ; mesurer sur le matériel réel.
- Couverture badges : préciser les familles de badges effectivement rencontrées ; aucun lecteur universel n'est présumé.
- Sécurité UID : UID clonable/émulable selon la technologie ; badge seul non suffisant.
- Touch ID : disponibilité et politique de fallback dépendent de macOS et de la configuration ; toujours tester `canEvaluatePolicy`.
- Interopérabilité plugin/app : choisir le canal local le plus simple, avec authentification et versionnement.
- Durée de soft-unlock : valeur à choisir dans les préférences ; défaut conservateur proposé : 2 minutes d'inactivité, avec verrouillage immédiat à la fermeture de l'app.
- Badge + quiz + Touch ID : définir si le quiz est requis à chaque détection ou seulement après un délai/risque ; recommandation MVP : quiz à chaque nouvelle session, Touch ID à chaque transition vers l'état Gate déverrouillé.

## 14. Références de recherche

- Apple — `LAContext`, disponibilité, politiques et évaluation biométrique : https://developer.apple.com/documentation/localauthentication/lacontext
- Apple — Guide « Logging a User into Your App with Face ID or Touch ID » : https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id
- Apple — `evaluatePolicy(_:localizedReason:reply:)` et consignes sur la raison affichée : https://developer.apple.com/documentation/localauthentication/lacontext/evaluatepolicy(_:localizedreason:reply:)
- Chameleon Ultra — guide officiel communautaire, CLI, SDK et protocole : https://github.com/RfidResearchGroup/ChameleonUltra/wiki
- Chameleon Ultra — protocole versionné et commandes de scan HF/LF : https://github.com/RfidResearchGroup/ChameleonUltra/wiki/protocol
- Chameleon Ultra — dépôt, matériel, firmware et licence GPL-3.0 : https://github.com/RfidResearchGroup/ChameleonUltra
- LearnKit — dépôt amont MIT : https://github.com/ctrlaltwill/LearnKit
- FSRS — moteur de répétition espacée déjà intégré en amont : https://github.com/open-spaced-repetition/ts-fsrs

## 15. Décision de conception recommandée

Construire d'abord un POC Touch ID autonome et un POC Chameleon indépendants, puis les relier par une machine à états testée. Ne pas commencer par une fonction qui prétend « déverrouiller le Mac ». Le produit doit annoncer clairement « déverrouiller Obsidian Gate » (verrouillage applicatif), tout en laissant macOS gérer l'écran de verrouillage et l'ouverture de session.
