# Role: Agentic Mobile-Simulator Auditor (VR App Manager)

**Task:** Use your native browser agent tools to perform a deep-tissue audit of the VR App Manager Mobile UI. You will simulate a mobile viewport (375x812) to evaluate the full user experience at narrow screen widths.

---

### Phase 1: Deployment & Viewport Setup

1. **Ensure the FastAPI backend is running** (configurable at `_apiUrl` in `lib/main.dart`).
2. **Command Execution:** Build and run the Flutter web app:
   `flutter run -d web-server --web-port 3000 --release`
3. **Clear the port if needed:**
   `lsof -ti:3000 | xargs -r kill -9`
4. **Launch & Resize:**
   - Use `openBrowserPage` to navigate to `http://localhost:3000`.
   - **MANDATORY:** Resize the browser window to **375x812** to trigger the mobile layout.
5. **Environment Verification:** Confirm that the app grid adapts to 2 columns at narrow width.

---

### Phase 2: Human-Centric Mobile Audit

Use `clickElement`, `scrollPage`, `screenshotPage`, and `typeInPage` to simulate a real mobile user:

#### 1. Grid Layout & Responsiveness

- Verify that `crossAxisCount` adapts to **2** on narrow screens.
- Check that `_AppCard` widgets display correctly without overflow or clipping.
- Look for "Yellow Tape" / `RenderFlex` overflow errors.
- Verify card cover images scale correctly within the 375px width.

#### 2. Dark Theme & Visual Fidelity

- Verify that the dark theme (`Color(0xFF111827)`) renders correctly on mobile.
- Confirm that purple/pink accent colors (`Colors.purpleAccent`, `Colors.pinkAccent`) remain legible at small sizes.
- **Touch Targets:** Verify that all interactive elements are at least 44x44 dp for thumb-friendliness.

#### 3. App Detail Dialog

- Tap on an app card and verify the detail dialog renders correctly at 375px width.
- Ensure images (400px wide in the dialog) don't overflow the viewport.
- Check that text, buttons, and layout adapt gracefully to the narrow width.

#### 4. Performance & Logic

- **Scroll Test:** Scroll through the app grid. Report any jank or layout issues.
- **Console Check:** Monitor the browser console for any errors.
- **Refresh Action:** Tap the refresh button and verify the loading spinner and data reload work correctly.

---

### Phase 3: Analysis & Priority Reporting

Cross-reference observations with `lib/main.dart`. Generate a **Master Change List**:

| Priority     | Category    | Area          | Problem                                  | Impact on Desktop      |
| :----------- | :---------- | :------------ | :--------------------------------------- | :--------------------- |
| **Critical** | BUG/UI      | App Card      | Text overflow in narrow card             | None (Mobile-specific) |
| **High**     | THEME       | Detail Dialog | Low contrast in dark mode at mobile size | None (Shared Theme)    |
| **Medium**   | PERFORMANCE | Grid          | Jank when loading many app images        | None                   |

---

### Phase 4: Implementation Guardrails

- **Isolation:** Every fix must be wrapped in platform/size checks. **Do not break the Desktop version.**
- **Architecture:** Keep changes within `lib/main.dart` or appropriate widget files.

---

**Final Step:**
Present the report and ask:
"The simulated mobile audit is complete. I have identified [X] mobile issues. Should I proceed with generating the fixes for the **Critical** items first while ensuring the desktop layout remains untouched?"
