# modular-status-widget Specification

## Purpose
TBD - created by archiving change modularize-statewidget. Update Purpose after archive.
## Requirements
### Requirement: Status widget module SHALL be reusable from a separate main source file
The system SHALL provide the status widget definitions in a standalone Vala source module that can be compiled together with and used from an independent `main.vala` implementation.

#### Scenario: Main source instantiates widget from module
- **WHEN** the project is built with separate `statewidget.vala` and `main.vala` files
- **THEN** `main.vala` can instantiate `StatusStateWidget` and reference `StatusState`
- **AND** the widget module does not require application entry-point classes to be present in the same file

### Requirement: Build configuration SHALL include widget module and main source
The system SHALL configure the Meson build to compile both the widget module source file and the application main source file into the executable.

#### Scenario: Build target references both source files
- **WHEN** the developer reviews or runs the Meson build configuration
- **THEN** the executable target includes `statewidget.vala` and `main.vala`
- **AND** the project no longer depends on all application code living in a single source file

