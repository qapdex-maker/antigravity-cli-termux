## 2025-05-14 - Visual Hierarchy in CLI Statuslines
**Learning:** Dimming zero-value statistics (e.g., 0 artifacts, 0 tasks) significantly reduces cognitive load and helps users focus on active data points in information-dense terminal UIs.
**Action:** Use lower-contrast colors (like gray) for zero values and high-contrast/bold colors for non-zero values in status indicators.

## 2025-05-14 - Responsive CLI Layouts for Termux
**Learning:** Users on mobile (Termux) often have narrow terminals (< 80 columns). Critical context like VCS branch and Sandbox status should be preserved even in compact layouts to prevent information loss.
**Action:** Prioritize critical state information over decorative elements or secondary stats when terminal width is limited.

## 2025-05-15 - Multi-Dimensional Color Affordance in CLI Interfaces
**Learning:** Relying solely on color for alerts (like high context-window usage) is not fully accessible. Pairing color changes with text or bar length transitions (such as dynamic truncation/scaling) provides multiple cognitive affordances. Moreover, aligning the color of numerical text with the bar warning color creates a strong unified visual highlight.
**Action:** Always coordinate color highlights on numeric stats with associated warning progress bars, and pair visual-alert changes with size/layout adaptations.
