---
agent: agent
---

Analyze the **VR App Manager** Flutter project codebase, which targets multiple platforms including desktop (Windows, macOS, Linux), mobile (Android, iOS), and web.

**Platform Prioritization Rule**: If the user specifies one or more platforms (e.g., "Android and web only"), concentrate exclusively on those platforms for all analysis, builds, and fixes. Ignore all other platforms completely and note this focus in the output summary.

Run the following steps to identify and fix all build errors and warnings across all platforms (or user-specified platforms only):

- Execute `flutter clean` followed by `flutter pub get` to reset dependencies.
- Run `flutter analyze` and capture all lint warnings from `analysis_options.yaml` (strict rules enforced).
- For each platform (or user-specified platforms only), build in release mode and log errors:
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios --release`
  - Web: `flutter build web --release`
  - Desktop: `flutter build windows --release`, `flutter build macos --release`, `flutter build linux --release`
- Prioritize fixes:
  1. Dependency conflicts: Update via `flutter pub upgrade`; validate with `dependency_validator`.
  2. Platform-specific: Resolve Dart/Flutter version mismatches (Dart ^3.11.4), `http` or `url_launcher` API errors, or platform channel issues.
  3. Lint violations: Fix `flutter_lints` rules (e.g., prefer `const` constructors, avoid `print`, use `key` in widget constructors).
- After fixes, re-run builds and `flutter analyze` to verify zero errors/warnings.
- Commit changes with descriptive messages referencing fixed issues.

Output a summary of changes made, including before/after build logs and updated `pubspec.yaml` if modified.
