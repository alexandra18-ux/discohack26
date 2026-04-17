## Why

The frontend currently shows a placeholder Yandex login button and hardcoded OAuth URL fragments instead of using the daemon-driven authentication flow. We need to complete the real login experience now so the GTK app can authorize against the existing backend over D-Bus and hand off the browser redirect to the user.

## What Changes

- Replace the hardcoded frontend OAuth logic with a D-Bus client for `ru.literallycats.daemon`.
- Read the daemon `IsAuth` property on startup and reflect the current auth state in the UI.
- Call `BeginLogin()` when the user presses Login and open the returned `authorize_url` in the default browser.
- Subscribe to the daemon `LoginCompleted` signal and update the UI when authorization finishes.
- Handle common failure cases such as daemon unavailability, D-Bus call failures, and browser launch errors.

## Capabilities

### New Capabilities
- `frontend-auth`: GTK frontend authorization flow backed by the daemon D-Bus API, including auth-state read, login initiation, browser redirect, and login-completion handling.

### Modified Capabilities
- None.

## Impact

- Affected code: `src/main.vala`, `src/meson.build`, and any new frontend D-Bus/auth helper files.
- Affected systems: GTK4 frontend, session D-Bus, browser URI launch integration, and the existing `../discohack-daemon` authentication backend.
- External contract used: D-Bus service `ru.literallycats.daemon`, property `IsAuth`, method `BeginLogin()`, signal `LoginCompleted`.
