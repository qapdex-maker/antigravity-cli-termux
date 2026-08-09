## 2025-05-14 - Visual Hierarchy in CLI Statuslines
**Learning:** Dimming zero-value statistics (e.g., 0 artifacts, 0 tasks) significantly reduces cognitive load and helps users focus on active data points in information-dense terminal UIs.
**Action:** Use lower-contrast colors (like gray) for zero values and high-contrast/bold colors for non-zero values in status indicators.

## 2025-05-14 - Responsive CLI Layouts for Termux
**Learning:** Users on mobile (Termux) often have narrow terminals (< 80 columns). Critical context like VCS branch and Sandbox status should be preserved even in compact layouts to prevent information loss.
**Action:** Prioritize critical state information over decorative elements or secondary stats when terminal width is limited.

## 2025-05-15 - Multi-Dimensional Color Affordance in CLI Interfaces
**Learning:** Relying solely on color for alerts (like high context-window usage) is not fully accessible. Pairing color changes with text or bar length transitions (such as dynamic truncation/scaling) provides multiple cognitive affordances. Moreover, aligning the color of numerical text with the bar warning color creates a strong unified visual highlight.
**Action:** Always coordinate color highlights on numeric stats with associated warning progress bars, and pair visual-alert changes with size/layout adaptations.

## 2025-05-16 - Professionalizing CLI Window Titles via State Mapping
**Learning:** Raw lowercase system/agent state keys (such as `tool_use`, `thinking`) can appear unpolished and machine-like to users. Mapping them to polished, title-cased labels (e.g., `Using Tool`, `Thinking`) in window titles significantly elevates the UI's look and feel, providing a highly polished, professional user interface.
**Action:** Always translate internal system states or raw technical keys into clean, human-friendly presentation labels in CLI window headers.

## 2025-07-17 - Cognitive Polishing & Dynamic Density in CLI Interfaces
**Learning:** Raw system state codes (like `tool_use`) in terminal window titles create unnecessary cognitive friction. Mapping them to descriptive, title-cased labels (like "Using Tool") elevates UI professionalism. Furthermore, on extremely narrow Termux displays, dynamically filtering statusline metrics to display only active non-zero counters maintains high utility without triggering layout overflow or text wrapping.
**Action:** Always map backend status keys to polished human-friendly string labels, and dynamically filter optional data fields under constrained screen widths.

## 2025-10-24 - Multi-Dimensional Affordances for Security Indicators in CLI Environments
**Learning:** For critical safety/security status indicators (such as Sandbox mode), communicating the active or inactive state solely through simple colored text or a monochrome "on/off" label is highly error-prone and inaccessible (e.g., to color-blind users or distracted operators). Coupling status transitions with highly distinct lock/unlock symbols (🔒 vs 🔓) and using strong semantic contrast (bold green ON vs bold red OFF) provides redundant, highly recognizable visual cues across multiple dimensions (shape/glypht, color, textual casing).
**Action:** Pair critical state transitions with contrasting emojis/symbols and distinct semantic colors to build highly accessible, fault-tolerant terminal dashboard elements.

## 2025-10-25 - Multi-Dimensional Safety Cues in Color-Constrained Environments (CLI Title)
**Learning:** Standard terminal window titles do not support ANSI color escape sequences or complex styles, making color-based safety indicators impossible. For critical environments like Sandboxes, appending distinct text badges with rich glyphs (e.g., `(🔒 Sandbox ON)` vs `(🔓 Sandbox OFF)`) inside the window title ensures high accessibility and clear visual verification of safety status directly from the desktop/taskbar window title.
**Action:** Use rich emoji-symbol pairings along with descriptive text badges in window titles to convey critical/security status in color-constrained terminal host environments.

## 2025-10-26 - Emoji Compatibility and Visual Alignment Across CLI Output Environments
**Learning:** Different monospaced terminal fonts and mobile host environments (such as Termux) may not correctly render less common Unicode icons (such as the gear `⚙` symbol), causing visual corruption. Aligning state emojis (e.g., using `🏃` for working across both statusline and window title) ensures reliable cross-platform rendering and visual coherence. Additionally, pairing color-only warnings (like PATH red alerts) with distinct multi-dimensional visual cues (like `⚠️`) improves accessibility for color-blind users and screen readers.
**Action:** Align status emojis across statusline and title components, use common high-compatibility emojis, and supplement color-coded alerts with visual warning glyphs.

## 2025-10-27 - Mobile CLI Density & Compact Metric Iconography
**Learning:** On narrow terminal displays (like Termux under 80 columns), displaying verbose text labels next to statistics leads to severe text wrapping and layout overflow. By conditionally omitting the textual labels (e.g. "artifacts", "subagents", "tasks") and displaying only the highly recognizable icons (e.g. 📦, 👥, 📋) and their values, the interface remains extremely compact and perfectly readable without layout corruption.
**Action:** Use conditional label rendering in terminal statuslines based on screen width, prioritizing standard iconography over full text.

## 2026-07-29 - Actionable Installer Guidance on Missing Dependencies
**Learning:** Augmenting missing dependency or environmental checks in installer terminal scripts with exact, copy-pasteable command resolutions (e.g. `pkg install jq` or `pkg install ca-certificates` on Termux) replaces ambiguous errors with actionable, self-documenting guidance to greatly reduce setup friction.
**Action:** When a prerequisite or binary check fails in a CLI setup script, always append the exact commands required to install or set up that dependency to minimize user cognitive overhead.

## 2026-08-01 - Proactive Early Error Handling in Interactive CLI Setup Scripts
**Learning:** Moving critical dependency checks (like `curl` and `awk`) to the very beginning of installation scripts—prior to executing any decorative headers, ASCII logo downloads, or progress updates—avoids raw, confusing shell parser crashes and ensures users get an accessible, clear, and styled error message detailing how to resolve the system requirement before any script-internal logic executes.
**Action:** Always validate the existence of all tools used in rendering terminal headers or download sequences at the absolute entry-point of installer files.

## 2026-08-02 - Multi-Dimensional VCS Branch Indicators in CLI Window Titles
**Learning:** Appending the active development branch (e.g. `(🌿 main)` or `(🌿 main*)` when dirty) in terminal window/tab titles provides immediate, low-friction state confirmation directly on the user's desktop/taskbar workspace without cluttering CLI prompt lines. To prevent parsing failures in environments without a VCS, optional JSON keys must be parsed using `jq` safe navigation `?.`.
**Action:** When incorporating nested, optional VCS properties into terminal output pipelines, always safe-navigate keys using `?.` and render status changes cleanly with recognizable badges.

## 2026-08-03 - Contrast-Enhanced Terminal Progress Bars
**Learning:** In terminal progress bars (such as context-window usage trackers), coloring both the filled and unfilled portions with a single accent color diminishes the visual boundary between active usage and remaining capacity. Applying a dimmed, inactive color (like `FG_GRAY`) specifically to the empty dots of the progress bar, while reserving the bright warning/accent color for the filled segment, dramatically enhances contrast and visual scanning.
**Action:** Always color empty progress bar components with a low-contrast neutral/gray hue while utilizing high-contrast/bold semantic colors solely for active/filled metrics.

## 2026-08-04 - Colors Block and Utility Early Initialization in Installer Scripts
**Learning:** Initializing the terminal colors and UI logging/exit helpers (like `die`) at the absolute beginning of an installer shell script (before any parameter, repository, or system environment validation is performed) ensures that even the earliest configuration failures are styled with high-contrast, multi-dimensional error indicators (`❌ [ERR]`) instead of failing with unformatted plain terminal outputs.
**Action:** Always place ANSI style variable declarations and standardized logging/exit functions as the topmost blocks in CLI installer scripts.
