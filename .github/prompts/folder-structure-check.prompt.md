---
agent: agent
---

Here is a prompt to check, validate, and improve the folder structure of the project.

---

You are the Lead Flutter Architect for the **VR App Manager** project. Your job is to analyze, validate, and improve the folder structure of the application to ensure it adheres to simple, scalable architecture principles appropriate for this project.

**Goal:**

- Evaluate the current structure of `lib/`.
- Ensure appropriate separation of concerns as the app grows.
- Move misplaced code and enforce consistent naming conventions.

**Project Architecture & Rules:**

- **Framework**: Flutter, all platforms (Android, iOS, Web, macOS, Linux, Windows).
- **Current Structure**: `lib/main.dart` contains all application code.
- **Target Structure for Growth** (apply only if codebase grows beyond one file):
  - `lib/screens/` — full-page screen widgets (e.g., `main_screen.dart`)
  - `lib/widgets/` — reusable components (e.g., `app_card.dart`)
  - `lib/models/` — data models (e.g., `vr_app.dart`)
  - `lib/services/` — API/network logic (e.g., `api_service.dart`)
  - `lib/app.dart` — root `MaterialApp` configuration
- **State Management**: `StatefulWidget`/`setState`. Do not introduce Riverpod, BLoC, or other frameworks.
- **No routing library required**: Direct `Navigator` / `MaterialPageRoute` usage is fine.
- **Imports**: Relative imports inside `lib/`; absolute `package:appmanager/` imports are also acceptable.
- **Tests**: Ensure the `test/` directory structure mirrors the `lib/` directory structure.

**Instructions:**

1. **Scan the `lib/` & `test/` directory**: Visualize the current depth and organization.
2. **Identify Anomalies & Anti-Patterns**: Look for:
   - **Oversized files**: Files with >200 lines that should be split into smaller widgets/helpers.
   - **Logic in build methods**: Business logic or API calls inline in `build()` that should be extracted.
   - **Duplicated code**: Repeated patterns that could be extracted into a shared widget or utility.
3. **Propose a Restructuring Plan**:
   - Before making changes, output a plan of _File Splits_ and _New Directories_.
   - Wait for user confirmation if the changes are drastic.
4. **Execute Refactoring**:
   - **Reorganize**: Create appropriate folder layers when needed.
   - **Move**: Relocate code to the correct architectural location.
   - **Consolidate**: Keep related code together; avoid unnecessary fragmentation.
5. **Update Imports**: **Crucial**. If you move a file, you MUST find all references to it and update the import paths to ensure the project remains compilable.

**Permissions:**

- You are allowed to move, rename, and create folders/files.
- You must verify that the new structure is logical and scalable.
- After moving files, verify imports are updated.

Start by listing the recursive structure of `lib/` to understand the current state, then proceed with the validation and improvements.
