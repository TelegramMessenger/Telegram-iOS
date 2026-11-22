# TelegramUIPreferences

## Theme settings and the bubble-free mode

`PresentationThemeSettings` is stored as one shared-data entry. The bubble-free mode (Appearance ▸ Bubble Mode off)
and its own theme choices live in `PresentationChatBubbleSettings`: `bubbleMode`, `bubblelessTheme`,
`bubblelessAutomaticTheme` (nil means Neutral, or Neutral Night after a dark bubbles theme, and Neutral Night at night).

- **Older builds crash on a theme they do not know.** They, and the Share and Notification Content extensions,
  force-unwrap the builtin raw value in `"t"` and `"theme_v2"` at launch. Neutral (4) and Neutral Night (5) therefore
  never go there: both keys encode through `legacyStorable`, which stores them as Classic and Night.
  `testOlderBuildsNeverReadNeutralInTheirKeys` (`//submodules/TelegramPresentationData:TelegramPresentationDataTests`)
  pins it for every combination.
- **With bubbles on, the stored bytes are what they were before the mode existed**: `bubbleMode` is written only when
  false, and the two choices only when set. The bytes tests in the same target pin it against bytes captured from
  master.
- **Read and write the theme choice through `currentModeTheme` / `currentModeAutomaticThemeSwitchSetting`**
  (`BubblelessThemeSettings.swift`). With bubbles they are `theme` / `automaticThemeSwitchSetting` themselves; without,
  the bubble-free choices, so a pick in one mode leaves the other's alone. Accent and message colours, wallpapers and
  the auto-night trigger stay keyed by theme and shared between the modes.
