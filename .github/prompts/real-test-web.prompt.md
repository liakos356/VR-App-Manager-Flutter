# Role: Agentic "Pro-Max" Auditor (VR App Manager Web Release)

**Task:** Use your native browser agent tools to build, deploy, and perform a deep-tissue audit of the VR App Manager web application. You are acting as a real-world user browsing their VR app library.

---

### Phase 1: Deployment

1. **Ensure the FastAPI backend is running** (configurable at `_apiUrl` in `lib/main.dart`).
2. **Command Execution:** Run the following terminal command:
   `flutter run -d web-server --web-port 3000 --release`
3. **Clear the port if needed:**
   `lsof -ti:3000 | xargs -r kill -9`
4. **Environment Verification:** Once the server is live, use `openBrowserPage` to navigate to `http://localhost:3000`.
5. **Rendering Validation:** Confirm that the app grid loads and displays VR app cards correctly.

---

### Phase 2: Human-Centric "Real Person" Audit

Use `clickElement`, `hoverElement`, `scrollPage`, and `typeInPage` to simulate intense daily usage:

#### 1. Grid Layout & Responsiveness

- Resize the browser to different widths (e.g., 1920, 1440, 1024, 800px).
- Verify that `crossAxisCount` adapts correctly (5 columns at >1200px, 4 at >800px, 2 below).
- Check card proportions (`childAspectRatio: 0.75`) at each breakpoint.
- Verify no overflow or clipping at any tested width.

#### 2. Dark Theme & Visual Fidelity

- Verify the dark purple/pink color scheme is consistent throughout.
- **Contrast & Legibility:** Ensure app names and metadata text are readable against the dark background (`Color(0xFF111827)`).
- **Image Integrity:** Confirm that app preview images load correctly and the error fallback (broken image icon) works.
- **Glow & Shadow:** Check that card elevation and border radius render cleanly in the release build.

#### 3. Performance & "Jank" Analysis

- Scroll through a large list of app cards. Observe if the UI freezes or lags.
- Click through multiple app detail dialogs consecutively.
- Observe the browser console for errors or warnings during data fetching.

#### 4. Desktop "Pro-Max" UX Verification

- **Precision Hover:** Verify every app card has a distinct, elegant hover state.
- **Dialog Interaction:** Open an app's detail dialog using `clickElement`, verify all fields render, then close it.
- **Refresh Button:** Click the refresh button and verify the loading spinner and data reload work correctly.

#### 5. Console & Production Logic Audit

- **Release-Only Bugs:** Look for errors caused by minification or tree-shaking.
- **API Connectivity:** If the FastAPI server is unavailable, confirm graceful error handling (no crash, empty state shown).

---

### Phase 3: Analysis & Priority Reporting

Generate a **Master Change List** structured as follows:

| Priority     | Category | Area          | Problem                                  | Impact on Mobile       |
| :----------- | :------- | :------------ | :--------------------------------------- | :--------------------- |
| **Critical** | BUG/PERF | App Grid      | App freezes in Release during data fetch | None                   |
| **High**     | UI       | App Card      | Image overflow in card at 800px width    | None (Flexible/Layout) |
| **High**     | THEME    | Detail Dialog | Low contrast on metadata in Dark Mode    | None (ThemeData)       |
| **Medium**   | UX       | Nav           | Missing hover state on Refresh button    | None (Web-only)        |

---

### Phase 4: Implementation Guardrails (The Golden Rules)

- **Platform Isolation:** Every fix must be wrapped in `kIsWeb` or use responsive layout builders to ensure **ZERO change** to the mobile application's look, feel, or performance.
- **Architecture Integrity:** Keep code within `lib/main.dart` or appropriate widget files.

---

**Final Step:**
Present the report and ask:
"The live audit of the Release Build is complete. I have identified [X] critical issues and [Y] UX improvements. Should I proceed with generating the fixes for the **Critical** items first?"
