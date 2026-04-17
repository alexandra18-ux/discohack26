## 1. Status widget foundation

- [x] 1.1 Define a dedicated status state enum and `StatusStateWidget` class in the GTK UI layer
- [x] 1.2 Build the widget UI so it can present idle, loading, and error states with the correct text and loading indicator
- [x] 1.3 Add a single state update method that switches visible elements consistently for all supported states

## 2. Main window integration

- [x] 2.1 Add the status widget to `MainWindow` layout in a visible position
- [x] 2.2 Wire existing user interaction handlers to demonstrate transitions between idle, loading, and error states

## 3. Verification

- [x] 3.1 Run the project and verify each state can be triggered from the main window
- [x] 3.2 Confirm loading hides in idle/error states and the UI remains stable after repeated transitions
