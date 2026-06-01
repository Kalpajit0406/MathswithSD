# AGENTS.md

Scope: This file guides AI coding agents working in this repository.

## Fast Start
- Install deps: `flutter pub get`
- Analyze: `flutter analyze`
- Run app: `flutter run`
- Build debug APK: `flutter build apk --debug`
- Build release APK: `flutter build apk --release`

## Project Shape
- App code: [lib](lib)
- State management: [lib/providers](lib/providers)
- Data and API: [lib/services](lib/services)
- UI screens: [lib/screens](lib/screens)
- Shared widgets: [lib/widgets](lib/widgets)

## Core Rules
- Keep changes surgical. Do not rewrite working systems.
- Validate provider lifecycle and timer disposal when touching exam flows.
- Preserve endpoint constants and avoid hardcoded URLs outside [lib/utils/constants.dart](lib/utils/constants.dart).
- Prefer links to existing docs instead of duplicating architecture notes.
- Treat study and reference snapshots as read-only context unless explicitly requested:
  - [_study/frontend/MathsWsd-frontend-main](./_study/frontend/MathsWsd-frontend-main)
  - [_study/backend/mathswithsd-backend-main](./_study/backend/mathswithsd-backend-main)
  - [_ref_source](./_ref_source)

## Known Pitfalls
- Emulator blocking exists in startup logic. Confirm target device assumptions before changing launch flow.
- Exam autosave and timer sync are sensitive to race conditions in provider updates.
- OCR and large image flows can trigger memory pressure if image quality and dimensions are not constrained.
- This repo has limited test coverage. Prefer adding targeted tests for new logic.

## Read Before Large Changes
- Architecture map: [FLUTTER_ARCHITECTURE_ANALYSIS.md](FLUTTER_ARCHITECTURE_ANALYSIS.md)
- Architecture index: [FLUTTER_ANALYSIS_INDEX.md](FLUTTER_ANALYSIS_INDEX.md)
- Diagrams: [ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md)
- Crash risks: [CRASH_VULNERABILITIES_SUMMARY.md](CRASH_VULNERABILITIES_SUMMARY.md)
- Feature notes: [PHASE6_FEATURES.md](PHASE6_FEATURES.md)
- Existing repo guidance: [GEMINI.md](GEMINI.md)

## Custom Agents
- Specialized test-system auditor: [.github/agents/TEST-SYSTEM-ARCHITECT.agent.md](.github/agents/TEST-SYSTEM-ARCHITECT.agent.md)

## Output Expectations For Agents
- State scope and assumptions first.
- List findings by severity when auditing.
- Include validation steps and residual risks.
