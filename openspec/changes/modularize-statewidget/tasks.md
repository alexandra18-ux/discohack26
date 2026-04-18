## 1. Separate widget module from application entry point

- [x] 1.1 Remove `MainWindow`, `MyApp`, and `main` from `src/statewidget.vala` so the file only contains the reusable status widget module
- [x] 1.2 Ensure `src/statewidget.vala` still exposes `StatusState` and `StatusStateWidget` with the same integration API expected by the window code

## 2. Restore modular application wiring

- [x] 2.1 Create or update `src/main.vala` with the application entry point and a `MainWindow` that imports and uses `StatusStateWidget`
- [x] 2.2 Reconnect the existing demo interactions in `MainWindow` so the modular widget still switches between idle, loading, and error states

## 3. Build and verify

- [x] 3.1 Update `src/meson.build` so the executable target compiles both `main.vala` and `statewidget.vala`
- [x] 3.2 Build the project and fix any compile issues caused by the file split
- [x] 3.3 Verify the application still launches and the widget remains visible and functional after modularization
