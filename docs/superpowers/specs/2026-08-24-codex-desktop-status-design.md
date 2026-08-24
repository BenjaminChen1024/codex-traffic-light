# Codex Desktop Status Integration

## Goal

Make Lights reflect the state of a Codex Desktop task without relying on Codex CLI lifecycle hooks.

## Scope

- Read only local Codex Desktop task state.
- Map a running task to red, a task waiting for the user to yellow, and a completed or idle task to green.
- Keep the existing Codex CLI hook integration unchanged.
- Keep the desktop-specific implementation isolated so an update to Codex can be repaired in one component.

## Design

Introduce a `CodexDesktopAccessibilityMonitor` that obtains the currently active desktop task's visible local state through macOS Accessibility. It publishes a normalized state (`executing`, `permission`, or `idle`) to the existing floating traffic-light notification path.

The monitor is read-only and runs only while Lights is open. It asks macOS for Accessibility permission, polls at a short interval, and reads only visible UI attributes such as title, description, value, and help text. It never performs actions, stores chat content, or transmits data. If Codex Desktop cannot be found, permission is absent, or the interface changes, Lights keeps working for CLI hooks and leaves the current light unchanged rather than producing false task status.

## Validation

1. Start Lights and Codex Desktop.
2. Start a Codex Desktop task and verify red.
3. Cause a user-input or approval request and verify yellow.
4. Let the task finish and verify green.
5. Confirm Codex CLI hook behavior continues to work.
