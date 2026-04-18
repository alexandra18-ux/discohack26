# frontend-auth Specification

## Purpose
TBD - created by archiving change complete-frontend-yandex-auth. Update Purpose after archive.
## Requirements
### Requirement: Frontend reads daemon authentication state on startup
The frontend SHALL connect to the session D-Bus service `ru.literallycats.daemon` and read the `IsAuth` property when the window starts so the UI reflects whether the user is already authenticated.

#### Scenario: Daemon reports existing authentication
- **WHEN** the frontend starts and the daemon `IsAuth` property is `true`
- **THEN** the UI shows an authenticated state without requiring the user to click Login

#### Scenario: Daemon reports no authentication
- **WHEN** the frontend starts and the daemon `IsAuth` property is `false`
- **THEN** the UI shows that login is required and keeps the login action available

#### Scenario: Daemon cannot be reached
- **WHEN** the frontend starts and the D-Bus service is unavailable or the property read fails
- **THEN** the UI shows an error state indicating that authentication status could not be loaded

### Requirement: Frontend starts login through the daemon and opens the browser URL
The frontend SHALL call `BeginLogin()` on the daemon when the user requests login and SHALL open the returned `authorize_url` in the default browser instead of constructing the OAuth URL locally.

#### Scenario: Login starts successfully
- **WHEN** the user clicks Login and `BeginLogin()` succeeds
- **THEN** the frontend opens the returned `authorize_url` in the default browser and updates the UI to show that browser-based authorization is in progress

#### Scenario: Daemon rejects the login attempt
- **WHEN** the user clicks Login and `BeginLogin()` returns an error
- **THEN** the frontend shows the error and returns to a retryable unauthenticated state

#### Scenario: Browser launch fails
- **WHEN** `BeginLogin()` succeeds but the frontend cannot open the returned `authorize_url`
- **THEN** the frontend shows a browser-launch error and does not claim that authorization is complete

### Requirement: Frontend subscribes to login completion notifications
The frontend SHALL subscribe to the daemon `LoginCompleted` signal before or during login handling so it can update the UI without polling.

#### Scenario: Login completes after browser authorization
- **WHEN** the frontend is subscribed to `LoginCompleted` and the daemon emits the signal
- **THEN** the frontend refreshes or updates its auth state to authenticated and informs the user that login succeeded

#### Scenario: Frontend is waiting for completion
- **WHEN** the browser has been opened and `LoginCompleted` has not yet been emitted
- **THEN** the frontend keeps the UI in a waiting state rather than reporting success prematurely

### Requirement: Frontend prevents misleading duplicate interactions during login
The frontend SHALL prevent duplicate login actions while a login attempt is already being started or is waiting for completion.

#### Scenario: User clicks Login repeatedly during an active attempt
- **WHEN** the frontend is in a starting or waiting-for-completion state
- **THEN** it does not start additional frontend login flows and keeps the UI focused on the active attempt

