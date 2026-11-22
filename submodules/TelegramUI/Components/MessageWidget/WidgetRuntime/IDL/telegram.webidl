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
  // SDK v1 §2.12 (widget-sandbox v0.1.3): `edge` is `any` so that anything but exactly 'top' or 'bottom' is a TypeError.
  undefined setResizeAnchor(optional any edge);
  // SDK v1 §2.13 (widget-sandbox v0.2): the bot's state and where the widget is, as the host passed them. `viewer` is a
  // frozen WebAppUser object or null.
  readonly attribute DOMString? chatData;
  readonly attribute DOMString? publicData;
  readonly attribute boolean isForward;
  readonly attribute DOMString? chatType;
  readonly attribute any viewer;
  readonly attribute boolean isPreview;
  // SDK v1 §2.17 (widget-sandbox v0.4.0): what the client draws over the widget, a frozen { top, right, bottom, left,
  // cornerLeft, cornerRight } in CSS px, the same object until a change.
  readonly attribute any contentSafeAreaInset;
  // SDK v1 §2.13–§2.15 (widget-sandbox v0.2): `data` and `text` are `any` so that anything but a string within its
  // limits is a TypeError. request returns a promise. Its `options` (v0.5.0, §2.18): an object with at most `wallet`.
  any request(optional any data, optional any options);
  // SDK v1 §2.18 (widget-sandbox v0.5.0): Gram Wallet, a frozen { sendTransaction, signData } or null.
  readonly attribute any wallet;
  undefined copyText(optional any text);
  undefined watchPublicData();
  undefined unwatchPublicData();
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
