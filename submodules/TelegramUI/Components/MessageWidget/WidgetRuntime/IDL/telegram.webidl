// The bridge to the chat (M1d plan, Task 4): widget-sandbox's TelegramWidget surface, and the window and navigator
// members today's sandbox bundle routes through it. Not from WPT. Changes against the HTML and Clipboard API
// signatures are in README.md.
callback TelegramThemeCallback = undefined (DOMString theme);

// SDK v1 §2.1 (V2a plan, Task 3): `type` and `handler` are `any` so that unknown types and non-functions are ignored,
// not TypeErrors (§2.11). sendMessage and on are removed.
[LegacyNoInterfaceObject, Exposed=Window]
interface TelegramWidget {
  readonly attribute long profile;
  boolean isProfileAtLeast(optional any n);
  readonly attribute DOMString colorScheme;
  readonly attribute object themeParams;
  readonly attribute DOMString theme;
  readonly attribute boolean isActive;
  undefined onEvent(optional any type, optional any handler);
  undefined offEvent(optional any type, optional any handler);
  undefined openLink(optional any url);
  undefined openTelegramLink(optional any url);
  [SameObject] readonly attribute HapticFeedback HapticFeedback;
  undefined ready();
  undefined onTheme(TelegramThemeCallback callback);
};

// SDK v1 §2.6 (V2a plan, Task 6): Mini Apps' HapticFeedback; each method returns the object for chaining. `style` and
// `type` are `any` so that only the listed strings pass (anything else, a non-string too, is a TypeError).
[LegacyNoInterfaceObject, Exposed=Window]
interface HapticFeedback {
  HapticFeedback impactOccurred(optional any style);
  HapticFeedback notificationOccurred(optional any type);
  HapticFeedback selectionChanged();
};

// SDK v1 §2.10: the clipboard and sharing reject with NotAllowedError and reach nothing; sendBeacon throws
// NetworkDisabledError; vibrate is false. No geolocation or mediaDevices.
[Exposed=Window]
interface Navigator {
  [SameObject] readonly attribute Clipboard clipboard;
  readonly attribute DOMString language;
  readonly attribute any languages;
  boolean sendBeacon(any... arguments);
  boolean vibrate(any... pattern);
  any share(any... arguments);
  boolean canShare(any... arguments);
};

[Exposed=Window]
interface Clipboard {
  any writeText(any... arguments);
  any readText();
  any write(any... arguments);
  any read();
};

// SDK v1 §2.10 and §2.5: no dialog, nothing sent to the host (confirm is false, prompt null); window.open returns null.
partial interface Window {
  [LegacyUnforgeable] readonly attribute TelegramWidget TelegramWidget;
  [Replaceable] readonly attribute Navigator navigator;
  any open(optional DOMString url = "", optional DOMString target = "", optional DOMString features = "");
  undefined alert(optional DOMString message = "");
  boolean confirm(optional DOMString message = "");
  DOMString? prompt(optional DOMString message = "", optional DOMString default = "");
};
