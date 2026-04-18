## Context

The GTK4/Vala frontend currently contains placeholder Yandex OAuth code with hardcoded values and does not talk to the real backend. The backend daemon already exposes the required D-Bus contract on the session bus (`ru.literallycats.daemon` at `/ru/literallycats/daemon`) with the `IsAuth` property, `BeginLogin()` method, and `LoginCompleted` signal. The frontend must now become the user-facing entrypoint for that flow: detect auth state, start login over D-Bus, open the returned browser URL, and react when the daemon reports completion.

Constraints:
- Frontend stack is GTK4 + Vala with GLib/GIO available.
- OAuth URL construction belongs to the daemon; the frontend should not reimplement PKCE logic.
- The backend callback happens on localhost and completes outside the app, so the UI must remain responsive while waiting for a D-Bus signal.
- The daemon may be unavailable, already authenticated, or return login errors that must be shown clearly.

## Goals / Non-Goals

**Goals:**
- Replace hardcoded login behavior with the real D-Bus-driven auth flow.
- Show the current auth state when the window opens.
- Launch the exact `authorize_url` returned by `BeginLogin()` in the default browser.
- Subscribe to `LoginCompleted` early enough to avoid missing the success signal.
- Keep the UI usable and informative during waiting and error states.

**Non-Goals:**
- Reimplement OAuth, PKCE, token exchange, or localhost callback handling in the frontend.
- Add logout, token management, or mount management controls.
- Redesign the whole UI beyond the status and login interaction needed for auth.
- Introduce persistent frontend-side auth storage.

## Decisions

### 1. Use GIO D-Bus APIs directly from Vala
The frontend will use `Gio.DBusProxy`/GIO D-Bus calls against the session bus instead of custom bindings or manual shelling out.

Rationale:
- Fits the current GTK/Vala stack with no extra runtime dependency.
- Keeps the contract explicit through shared constants for bus name, object path, and interface name.
- Supports both property reads and signal subscriptions in one place.

Alternatives considered:
- Generate custom bindings from introspection data: adds setup overhead for a small surface area.
- Call `gdbus` as a subprocess: brittle and harder to manage asynchronously from the UI.

### 2. Treat auth as an explicit UI state machine
The frontend will model a small set of states such as `checking`, `unauthenticated`, `starting-login`, `waiting-for-browser-completion`, `authenticated`, and `error`.

Rationale:
- Prevents contradictory UI such as showing "browser opened" before `BeginLogin()` succeeds.
- Makes it easy to disable the login button while a login attempt is in progress.
- Gives a predictable place to map daemon failures and browser-launch failures to user-visible text.

Alternatives considered:
- Update the label ad hoc in callbacks: faster to write but easy to break as asynchronous branches grow.

### 3. Subscribe to `LoginCompleted` before launching the browser
The frontend will connect to the daemon signal as part of initialization or, at minimum, before it opens the returned `authorize_url`.

Rationale:
- Matches the documented sequence and avoids a race where the user finishes OAuth before the frontend starts listening.
- Lets the UI update without polling.

Alternatives considered:
- Poll `IsAuth` periodically after opening the browser: simpler signal handling, but worse UX and unnecessary bus traffic.
- Subscribe only after browser launch: risks missing a fast completion event.

### 4. Use daemon-returned `authorize_url` as the source of truth
The frontend will open the `authorize_url` returned by `BeginLogin()` and will not construct or mutate OAuth query parameters locally. `code_challenge` and `redirect_uri` may be logged or sanity-checked, but not used to rebuild the URL.

Rationale:
- Keeps OAuth/PKCE ownership in the backend where the verifier and pending session are managed.
- Avoids drift between frontend and backend URL-building logic.
- Matches the daemon README and archived backend spec.

Alternatives considered:
- Rebuild the browser URL in the frontend from `client_id`, `redirect_uri`, and `code_challenge`: duplicates protocol logic and creates contract mismatch risk.

### 5. Surface recoverable errors in-place and allow retry
Failures to connect to D-Bus, call `BeginLogin()`, or open the browser will update the status label and return the UI to a retryable state.

Rationale:
- The most likely field failures are environmental and transient.
- A login UI that dead-ends on first error is frustrating and makes backend validation harder.

Alternatives considered:
- Crash or log-only failures: unacceptable for a user-facing auth entrypoint.

## Risks / Trade-offs

- [The exact D-Bus response shape may be awkward to unpack in Vala] → Mitigation: keep the client isolated in a helper layer and validate the returned tuple/struct with targeted manual testing against the running daemon.
- [The daemon might emit `LoginCompleted` before the frontend is listening] → Mitigation: establish the signal subscription during initialization or before browser launch.
- [Browser launch succeeds but the user never completes OAuth] → Mitigation: keep the UI in a waiting state with clear text and allow app restart or retry after an error from a subsequent `BeginLogin()` call.
- [Daemon unavailable on session bus] → Mitigation: show a clear status message indicating that `ru.literallycats.daemon` must be running.
- [Frontend state can become stale if auth changes outside the app] → Mitigation: refresh `IsAuth` on startup and on `LoginCompleted`; defer broader property-change syncing unless needed later.

## Migration Plan

1. Add frontend D-Bus constants/helpers for the daemon contract.
2. Replace the hardcoded OAuth URL logic in `src/main.vala` with async D-Bus property/method usage.
3. Wire status text and button sensitivity to the auth state machine.
4. Validate manually with the running daemon: startup unauthenticated, call `BeginLogin()`, open the browser URL, complete OAuth, receive `LoginCompleted`, and confirm the UI flips to authenticated.
5. If rollout fails, revert to the previous frontend commit; no backend or data migration is required.

## Open Questions

- Should the app close automatically after successful login, or stay open and show an authenticated state?
- Do we want to listen for broader `PropertiesChanged` updates in addition to `LoginCompleted`, or is startup + completion sufficient for the first iteration?
