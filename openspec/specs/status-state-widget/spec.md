# status-state-widget Specification

## Purpose
TBD - created by archiving change add-status-state-widget. Update Purpose after archive.
## Requirements
### Requirement: Widget SHALL display idle state
The system SHALL provide a status state widget that can render an idle state when no active process is running.

#### Scenario: Idle state is shown by default
- **WHEN** the status state widget is created without an active operation
- **THEN** it displays an idle message indicating that nothing is happening
- **AND** it does not show an active loading indicator

#### Scenario: UI returns to idle after reset
- **WHEN** the application requests the idle state after another state was visible
- **THEN** the widget updates its message to the idle presentation
- **AND** any loading indicator is stopped or hidden

### Requirement: Widget SHALL display loading state
The system SHALL provide a loading presentation that clearly communicates an ongoing operation.

#### Scenario: Loading state activates progress indicator
- **WHEN** the application sets the widget state to loading
- **THEN** the widget displays a loading message
- **AND** it shows an active spinner or equivalent loading indicator

### Requirement: Widget SHALL display error state
The system SHALL provide an error presentation that communicates that the last operation failed.

#### Scenario: Error state shows failure feedback
- **WHEN** the application sets the widget state to error
- **THEN** the widget displays an error message
- **AND** it hides any active loading indicator

### Requirement: Main window SHALL integrate the widget
The main window SHALL include the status state widget as part of the visible UI and SHALL be able to switch its state from existing user interaction handlers.

#### Scenario: Existing actions can update widget state
- **WHEN** a user triggers one of the existing UI actions wired by the main window
- **THEN** the main window can change the widget to idle, loading, or error
- **AND** the updated state becomes visible without reopening the window

