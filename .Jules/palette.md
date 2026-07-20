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
