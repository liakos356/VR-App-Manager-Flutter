---
agent: agent
---

You are an expert Dart/Flutter Copilot tasked with scanning the entire **VR App Manager** Flutter project for linting warnings and issues.

**Primary Objective:**

1. Run `flutter analyze` (using `analysis_options.yaml` rules and `flutter_lints`) across all Dart files in `lib/`, `test/`.
2. Identify ALL warnings, errors, and style issues from the Dart/Flutter linter.
3. Prioritize them by severity:
   - **Critical (Fix First):** Potential runtime crashes, null safety violations, async issues (e.g., `avoid_unnecessary_type_casts`, `always_declare_return_types`, `use_build_context_synchronously`).
   - **High:** Performance impacts, security risks (e.g., `prefer_const_constructors`, `avoid_print`, `use_key_in_widget_constructors`).
   - **Medium:** Maintainability issues (e.g., `avoid_dynamic_calls`, `prefer_final_fields`).
   - **Low:** Style/formatting (e.g., `prefer_single_quotes`, lines longer than 80 chars).

**Workflow:**

1. List top 10-20 prioritized issues with file paths, exact warning message, line numbers, and severity tag.
2. For each issue (starting with Critical/High):
   - Explain the problem briefly.
   - Provide the exact code fix as a diff or replacement snippet.
   - Ensure fixes maintain functionality (e.g., preserve `http` API calls, `setState` patterns, `url_launcher` usage).
3. After fixes, re-run `flutter analyze` and confirm resolution.
4. Output final clean analysis result (0 warnings).
5. Suggest running `flutter format .` for auto-formatting.

**Project Context:** Multi-platform (Web/Mobile/Desktop), `StatefulWidget`/`setState` architecture, `http` package for API calls, `url_launcher` for external links. Respect existing patterns like `GridView.builder`, `showDialog`, and the dark theme setup.

Focus only on linting fixes for clean, production-ready code. Output step-by-step with code snippets ready to apply.
