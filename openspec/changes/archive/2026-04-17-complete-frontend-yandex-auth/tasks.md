## 1. D-Bus auth client setup

- [x] 1.1 Define frontend constants/helpers for the daemon bus name, object path, interface name, and `BeginLogin()` response unpacking
- [x] 1.2 Add the GIO/GDBus-based connection/proxy code needed to talk to `ru.literallycats.daemon` from the GTK app
- [x] 1.3 Subscribe to the `LoginCompleted` signal during window initialization so the frontend can react without polling

## 2. Startup auth-state handling

- [x] 2.1 Replace the placeholder startup status with an async `IsAuth` read from the daemon
- [x] 2.2 Map startup results into clear UI states for authenticated, unauthenticated, and daemon-unavailable cases
- [x] 2.3 Wire button sensitivity and status text updates through a small auth-state flow so the UI stays consistent

## 3. Login flow and browser handoff

- [x] 3.1 Remove the hardcoded Yandex OAuth URL/client values from the frontend login handler
- [x] 3.2 Call `BeginLogin()` when the user presses Login and unpack the returned `authorize_url`, `code_challenge`, and `redirect_uri`
- [x] 3.3 Open the returned `authorize_url` in the default browser and show a waiting-for-completion status only after launch succeeds
- [x] 3.4 Handle `BeginLogin()` failures, browser launch failures, and repeated clicks by returning the UI to a retryable state or keeping the active wait state

## 4. Completion handling and validation

- [x] 4.1 Update the frontend on `LoginCompleted` by refreshing or setting the authenticated state in the UI
- [ ] 4.2 Run the documented end-to-end flow against `../discohack-daemon`: startup check, login click, browser redirect, signal receipt, authenticated UI
- [x] 4.3 Clean up any obsolete placeholder auth code/messages so the README-described flow is the only supported path
