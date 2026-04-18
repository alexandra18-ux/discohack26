## MODIFIED Requirements

### Requirement: Main window SHALL integrate the widget
The main window SHALL include the status state widget as part of the visible UI, SHALL be able to switch its state from existing user interaction handlers, and SHALL do so while consuming the widget from a separate reusable source module.

#### Scenario: Existing actions can update widget state
- **WHEN** a user triggers one of the existing UI actions wired by the main window
- **THEN** the main window can change the widget to idle, loading, or error
- **AND** the updated state becomes visible without reopening the window

#### Scenario: Main window uses modular widget implementation
- **WHEN** the application source is split so the status widget lives in `statewidget.vala` and the window logic lives in `main.vala`
- **THEN** the main window still constructs and embeds `StatusStateWidget`
- **AND** the visible widget behavior remains available through the separated module boundary
