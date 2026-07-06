## 2025-05-14 - Visual Hierarchy in CLI Statuslines
**Learning:** Dimming zero-value statistics (e.g., 0 artifacts, 0 tasks) significantly reduces cognitive load and helps users focus on active data points in information-dense terminal UIs.
**Action:** Use lower-contrast colors (like gray) for zero values and high-contrast/bold colors for non-zero values in status indicators.

## 2025-05-14 - Responsive CLI Layouts for Termux
**Learning:** Users on mobile (Termux) often have narrow terminals (< 80 columns). Critical context like VCS branch and Sandbox status should be preserved even in compact layouts to prevent information loss.
**Action:** Prioritize critical state information over decorative elements or secondary stats when terminal width is limited.
