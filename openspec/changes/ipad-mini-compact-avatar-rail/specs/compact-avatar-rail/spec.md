## ADDED Requirements

### Requirement: Gesture Isolation in Compact Avatar Rail
In compact avatar rail mode on iPad (`tablet && width <= 160.0`), the system SHALL disable folder horizontal swipe gesture recognizers and selection mode gesture recognizers.

#### Scenario: User swipes or drags horizontally across the compact rail
- **WHEN** the master pane width is 160pt or less on an iPad device and a touch occurs on the avatar list
- **THEN** the `panRecognizer` does not intercept the gesture and does not cancel the item touch event

#### Scenario: User touches with multiple fingers or performs selection gestures
- **WHEN** the master pane width is 160pt or less on an iPad device
- **THEN** selection/edit mode (checkbox overlay) is not activated

### Requirement: Chat Avatar Hit-Testing and Responsiveness Across All Scroll Positions
In compact avatar rail mode, every visible chat avatar SHALL receive touch events and open the corresponding chat view on a single tap, without obstruction from static overlays.

#### Scenario: User taps any visible chat avatar
- **WHEN** the user taps any visible chat avatar in the compact rail (at initial scroll or after scrolling)
- **THEN** the system immediately opens the selected chat in the detail view pane

#### Scenario: User taps chat avatar inside a filtered folder
- **WHEN** the chat list is filtered by any folder and the user taps any visible avatar in the compact rail
- **THEN** the system opens the correct chat without activating story creation or misaligned touch targets

### Requirement: Suppression of Story Mechanics in Compact Mode
In compact avatar rail mode, the system SHALL strictly disable story header expansion, story posting availability, and overscroll top insets.

#### Scenario: User pulls down or double-taps upper area
- **WHEN** the user pulls down the chat list or taps the upper area in compact mode
- **THEN** no story creation screen opens and no residual `storiesInset` top gap remains

### Requirement: Clean Restoration on Expansion
When the master pane transitions from compact rail to regular width (`width > 160.0`), the system SHALL fully restore standard folder swipe gestures, selection gestures, search bar, and story headers.

#### Scenario: Master pane expands to regular width
- **WHEN** the user drags or triggers expansion of the master pane beyond 160pt
- **THEN** full search bar, folder tabs, folder swipe gestures, selection gestures, and story headers are restored with standard layout insets
