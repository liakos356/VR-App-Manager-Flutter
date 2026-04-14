---
agent: agent
---

Focus on optimizing UI design and development specifically for desktop (native and web) while ensuring no disruptions or functional regressions on mobile platforms.

- Prioritize layouts, interaction patterns, and performance characteristics tailored to large screens, high‑resolution displays, and pointer/keyboard input on desktop OSes and desktop web.
- Implement visual and interaction enhancements exclusively for desktop environments (web and native) without degrading or altering existing mobile behavior.
- Safeguard mobile and tablet experiences by isolating desktop‑specific layout, navigation, and styling changes behind platform checks or viewport‑based conditions.
- Avoid disrupting mobile or web layouts when making desktop-first improvements.
- Document desktop breakpoints, input modality assumptions (mouse, trackpad, keyboard), and window-resizing behavior to maintain clear platform boundaries and predictable UI behavior.
- Use platform detection (e.g., Flutter kIsWeb, Platform.isWindows/macOS/linux) and/or media queries to apply desktop‑only components, density, and interaction affordances.
- Validate backward compatibility to keep native mobile apps and any future narrow‑screen layouts unaffected by desktop optimizations and experiments.
