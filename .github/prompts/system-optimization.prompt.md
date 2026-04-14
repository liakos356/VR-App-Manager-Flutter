---
agent: agent
---

Here is an updated prompt including refactoring and folder/file changes while preserving behavior.

---

# System Resource Optimization Prompt for VR App Manager

Role: Act as a Senior Flutter Performance Engineer.

Context:
You are analyzing **VR App Manager**, a Flutter application for browsing and managing VR apps. The app fetches app data from a FastAPI backend, displays it in a responsive grid, and shows detail dialogs for individual apps.

- Tech Stack: Flutter (Dart ^3.11.4), `StatefulWidget`/`setState`, `http` package, `url_launcher`.
- Current State: The app uses a simple fetch-on-load pattern with `_fetchApps()` called in `initState()` and on manual refresh.
- Data Flow: `MainScreen` → `http.get()` → `setState()` → `GridView.builder()` → `_AppCard`.
- Goal: Reduce main-thread blocking, minimize unnecessary widget rebuilds, and optimize memory usage without changing observable behavior.

Your job is to analyze the described architecture and propose refactorings that fit the existing patterns (`StatefulWidget`/`setState`, `http` package, no state-management framework).

## 1. Network & Data Fetching Optimization

The current implementation makes a single HTTP GET request on screen load and on manual refresh. Network errors are silently caught with `debugPrint`.

- Instruction:
  - Focus on `_fetchApps()` in `_MainScreenState`.
- Action:
  - Propose concrete refactors that:
    - Add proper error state (show an error widget instead of silent failure).
    - Consider caching the last-known response to avoid full re-fetches on rebuild.
    - Use `Isolate.run()` or `compute()` if JSON parsing becomes expensive for large app lists.
    - Implement retry logic for transient network failures.
- Constraint:
  - Keep the `http` package; do not switch to Dio.
  - Preserve the `StatefulWidget`/`setState` pattern.

## 2. Widget Build Optimization (reducing rebuilds)

The app uses `GridView.builder` with `_AppCard` widgets. Each card renders a network image and app metadata.

- Instruction:
  - Review `_AppCard` and `MainScreen.build()`.
- Action:
  - Suggest specific refactors such as:
    - Add `const` constructors wherever possible to allow Flutter to short-circuit rebuilds.
    - Wrap image-heavy card widgets in `RepaintBoundary` to isolate repaint cost from the rest of the grid.
    - Add image caching (e.g., `cached_network_image` package) to avoid re-downloading images on every rebuild.
    - Extract the detail `Dialog` into a separate stateless widget.
- Constraint:
  - Do not introduce new state management frameworks.

## 3. Asynchronous Flow and Error Management

The current `_fetchApps()` uses a simple `try/catch` with `debugPrint`.

- Instruction:
  - Analyze async patterns in `_MainScreenState`.
- Action:
  - Propose refactors to:
    - Track a distinct error state alongside `_isLoading` to surface errors in the UI.
    - Ensure all async callbacks from user interaction (e.g., URL launch) properly handle errors.
    - Use `unawaited()` with proper error handling for fire-and-forget operations.

## 4. Memory and Resource Management

The app holds the entire app list in `_apps` as `List<dynamic>`, and network images are loaded without explicit caching.

- Instruction:
  - Review how app data is stored in `_MainScreenState`.
- Action:
  - Suggest refactors to:
    - Use typed model classes (e.g., `VrApp`) instead of `dynamic` for type safety.
    - Ensure any `AnimationController`s added in future are properly disposed in `dispose()`.
    - Consider pagination if the app list grows large enough to cause jank.
- Constraint:
  - Preserve existing behavior; data correctness must not be compromised.

---

## Expected output format

For each relevant file or method you analyze, respond using the following Markdown structure:

**File: [path/to/file.dart]**

1. **Issue:** [Technical explanation, e.g., "JSON parsed synchronously on main thread."]
2. **Optimization:** [Concrete strategy, e.g., "Offload to `compute()`."]
3. **Code Diff:**

```dart
// Previous implementation
final data = json.decode(response.body) as List<dynamic>;

// Optimized implementation
final data = await compute(_parseApps, response.body);
```

4. **Impact:** [Estimated impact, e.g., "Reduces main-thread blocking, improving scroll smoothness."]

Repeat this block for each file/method. Use realistic paths (e.g., `lib/main.dart`, `lib/services/api_service.dart`).
