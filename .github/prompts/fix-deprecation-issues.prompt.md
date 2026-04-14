---
agent: agent
---

Run `flutter analyze` on the **VR App Manager** Flutter project and use the analyzer output to systematically fix all deprecation notices, warnings, and strong-mode issues across the codebase.

When you work, follow these steps:

- Open the existing Flutter project in the `VR-App-Manager-Flutter` workspace and ensure it uses the documented stack (Flutter, Dart ^3.11.4, `http`, `url_launcher`).
- Execute `flutter analyze` from the project root and capture the full output, including file paths, line numbers, error/warning codes, and deprecation messages.
- Group the analyzer findings by category, for example: deprecated APIs, nullable/late issues, type mismatches, unused imports, dead code, outdated package usage, or lints from `analysis_options.yaml`.
- For each category, propose concrete code changes that:
  - Replace deprecated Flutter/Dart APIs with their current recommended alternatives.
  - Update package usages (`http`, `url_launcher`) to non-deprecated methods or patterns, keeping compatibility with the versions in `pubspec.yaml`.
  - Respect project constraints:
    - Do not change the fundamental `StatefulWidget`/`setState` architecture.
    - Do not introduce new state management frameworks.
    - Keep initialization logic in `main()` / `runApp()`.
- When a deprecation has multiple possible replacements, choose the option that:
  - Minimizes code churn.
  - Preserves existing behavior for all supported platforms (desktop, mobile, web).
- After implementing changes, run `flutter analyze` again and confirm that all deprecations and warnings have been resolved or, if any remain, are explicitly justified.
- Produce a final summary that includes:
  - A short, categorized list of the main changes made.
  - Any remaining warnings or deprecations that cannot be fixed yet, with an explanation.
  - Any places where analyzer rules needed to be adjusted in `analysis_options.yaml`, with justification.
