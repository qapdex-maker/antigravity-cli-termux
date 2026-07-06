# Bolt's Journal

## 2025-05-24 - [Overhead in Progress Bars]
**Learning:** Shell scripts often use external tools like `awk` or `bc` for simple arithmetic and string formatting inside high-frequency loops (like progress bars). Spawning a new process every 100-200ms adds significant CPU overhead and can make the UI feel "heavy" or laggy on resource-constrained environments like Termux.
**Action:** Use Bash built-in arithmetic `$((...))` and string manipulation `${var:offset:length}` to handle formatting and calculations within loops.
