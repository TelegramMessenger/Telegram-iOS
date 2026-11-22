// The Window global and Location. From third-party/wpt/interfaces/html.idl; changes in README.md.
[Global=Window, Exposed=Window]
interface Window : EventTarget {
  // the current browsing context
  [LegacyUnforgeable] readonly attribute Window window;
  [Replaceable] readonly attribute Window self;
  [LegacyUnforgeable] readonly attribute Document document;
  [LegacyUnforgeable] readonly attribute Location location;

  // other browsing contexts
  [Replaceable] readonly attribute Window frames;
  [Replaceable] readonly attribute unsigned long length;
  [LegacyUnforgeable] readonly attribute Window? top;
  readonly attribute any opener;
  [Replaceable] readonly attribute Window? parent;
};

interface mixin WindowOrWorkerGlobalScope {
  [Replaceable] readonly attribute Performance performance;
};
Window includes WindowOrWorkerGlobalScope;

[Exposed=Window]
interface Location {
  stringifier readonly attribute USVString href;
  readonly attribute USVString origin;
  readonly attribute USVString protocol;
  readonly attribute USVString host;
  readonly attribute USVString hostname;
  readonly attribute USVString port;
  readonly attribute USVString pathname;
  readonly attribute USVString search;
  readonly attribute USVString hash;
};

// From third-party/wpt/interfaces/html.idl, WindowOrWorkerGlobalScope (M1b Task 9).
partial interface mixin WindowOrWorkerGlobalScope {
  undefined reportError(any e);

  // microtask queuing
  undefined queueMicrotask(VoidFunction callback);
};

// From third-party/wpt/interfaces/html.idl (M1b Task 10). TrustedScript removed (README).
typedef (DOMString or Function) TimerHandler;

partial interface mixin WindowOrWorkerGlobalScope {
  // timers
  long setTimeout(TimerHandler handler, optional long timeout = 0, any... arguments);
  undefined clearTimeout(optional long id = 0);
  long setInterval(TimerHandler handler, optional long timeout = 0, any... arguments);
  undefined clearInterval(optional long id = 0);
};

// From third-party/wpt/interfaces/html.idl (M1b Task 11).
callback FrameRequestCallback = undefined (DOMHighResTimeStamp time);

interface mixin AnimationFrameProvider {
  unsigned long requestAnimationFrame(FrameRequestCallback callback);
  undefined cancelAnimationFrame(unsigned long handle);
};
Window includes AnimationFrameProvider;

Window includes GlobalEventHandlers;
Window includes WindowEventHandlers;
