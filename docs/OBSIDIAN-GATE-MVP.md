# Obsidian Gate — Product direction and MVP

> Working product brief for the Obsidian Gate fork. The upstream LearnKit project and its MIT license notices are preserved; this document records the additional product direction for this fork.

## Product

Obsidian Gate is an offline-first learning companion for Obsidian, initially focused on **Modern Standard Arabic (MSA / al-Fuṣḥā)**. It combines spaced repetition, adaptive practice, a hybrid AI coach, and a macOS access ritual built around an optional NFC/RFID badge and app-level Touch ID confirmation.

The goal is not to replace Obsidian or LearnKit's study engine. The goal is to extend the existing study workflow into a reliable, source-grounded language-learning system.

## Confirmed product decisions

- **Learning scope:** Modern Standard Arabic (MSA) only for the MVP. Quranic Arabic is explicitly out of scope.
- **Coach:** hybrid, local-first. A local model/provider is the default path; cloud providers are optional and opt-in.
- **Knowledge store:** the user's Obsidian vault is the human-readable source of truth. Operational indexes and scheduling state should remain local to the device.
- **iCloud:** do not place a live SQLite database in an iCloud-synchronised vault. Keep active databases in local application/plugin storage and export Markdown reports/notes into the vault.
- **Sources:** open resources first. Commercial resources may be integrated only where their licence and terms permit the intended use and they provide meaningful value.
- **Privacy:** no telemetry by default. Never send the whole vault to a model. Send only the minimum user-selected note/context required for a requested action.
- **Hardware:** NFC/RFID is an optional signal for the Gate workflow, not a cryptographic identity proof. UID-only badge checks must not be treated as strong authentication.
- **Biometrics:** Touch ID may authenticate an action inside the macOS app using Apple's LocalAuthentication APIs. It does not unlock the macOS login session or replace the system lock screen.

## MVP outcomes

1. Preserve LearnKit's existing flashcard, review, and FSRS behaviour.
2. Add an Arabic MSA learning layer with normalisation, lexical entries, morphology-aware examples, and answer validation.
3. Deliver a short adaptive practice session using due reviews and identified weak skills.
4. Provide a local-first coach interface with a cloud provider disabled until explicitly configured.
5. Generate a review summary for the Obsidian Daily Note through a preview-and-confirm flow. Never overwrite unrelated note content.
6. Keep the existing plugin usable without NFC hardware, a local LLM, or a cloud API key.

## Technical principles

### Learning engine

- Reuse the existing LearnKit scheduler and ts-fsrs; do not create a competing scheduler.
- The scheduler owns review timing. The LLM may suggest content or difficulty, but it must not directly decide FSRS state.
- Model Arabic content explicitly: surface form, normalised form, lemma, root (when known), part of speech, morphology/features, gloss, example, source, and confidence.
- Support Arabic script and diacritics without silently discarding distinctions needed by an exercise.
- Validate generated answers against vetted variants and structured rules before marking a response correct.

### Coach and privacy

- Define a provider-neutral coach interface.
- Local inference is the default; cloud inference requires an explicit user choice.
- Keep credentials out of Markdown, logs, source control, and ordinary exported settings where a secure platform store is available.
- Provide transparent context previews and clear boundaries around note/attachment access.
- Treat model output as untrusted until it passes schema and domain validation.

### Obsidian integration

- Read only configured or user-selected sources.
- Use incremental indexing and retain provenance (vault path, heading, content hash, source/version metadata).
- Daily Note updates must be idempotent and non-destructive: show a preview, ask for confirmation, and update only the Gate-owned block.
- Exclude .obsidian, private folders, and attachments by default unless the user opts in.

### macOS Gate and hardware

- Keep the macOS companion app and hardware integration as a later phase after the learning workflow is stable.
- Separate badge detection, challenge generation, answer evaluation, biometric request, and biometric result into explicit events.
- A successful quiz plus Touch ID may release the app's own soft lock. It must never be described as unlocking the macOS desktop.
- Hardware support must be capability-driven. No single reader should be assumed to support all LF, HF, and UHF technologies.

## Proposed delivery sequence

| Phase | Scope | Exit condition |
| --- | --- | --- |
| 0. Fork hygiene | Verify upstream baseline, preserve MIT/third-party notices, establish project docs and CI baseline | Clean, reproducible baseline with upstream attribution intact |
| 1. Knowledge foundation | Source registry, provenance model, schemas, licence metadata | Every imported learning item has traceable provenance and rights metadata |
| 2. Arabic vertical slice | MSA lexicon, Unicode normalisation, diacritics policy, morphology-aware examples | Offline vocabulary and sentence exercises pass deterministic tests |
| 3. Adaptive practice | Skill profile, validated exercise types, existing FSRS integration | A daily session adapts to learner performance without bypassing FSRS |
| 4. Hybrid coach | Provider abstraction, local-first configuration, cloud opt-in, output verification | Same exercise workflow works without a network connection |
| 5. Daily Notes | Preview, confirmation, owned-block updates, idempotence | Repeated runs update only the Gate block and never destroy user text |
| 6. Content expansion | Reading/listening material and licensed datasets | Each source has explicit reuse and redistribution permissions |
| 7. macOS Gate | Companion app, NFC/RFID adapters, app-level Touch ID | Hardware remains optional; security claims match platform capabilities |

## Non-goals for the MVP

- Quranic Arabic curriculum.
- Unlocking or controlling the macOS login session.
- Treating a badge UID as a secure credential.
- Uploading or indexing the entire vault by default.
- Bundling or redistributing copyrighted dictionaries, textbooks, audio, or corpora without permission.
- Replacing LearnKit's existing review engine before a demonstrated need and migration plan exist.

## Initial engineering checks

Before changing core behaviour, record the upstream baseline for npm ci, npm test, npm run build, and npm run check.

Audit the current settings/key storage, SQLite persistence and migration paths, FSRS integration, Companion context assembly, and Daily Note APIs before implementing new services. Any change to upstream behaviour should be isolated, tested, and documented.
