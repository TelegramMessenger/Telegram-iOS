// The profile's events: DOM's Event, CustomEvent and EventTarget, and HTML's ErrorEvent, PromiseRejectionEvent and
// PageTransitionEvent. From third-party/wpt/interfaces/dom.idl and html.idl; changes in README.md.
[Exposed=*]
interface Event {
  constructor(DOMString type, optional EventInit eventInitDict = {});

  readonly attribute DOMString type;
  readonly attribute EventTarget? target;
  readonly attribute EventTarget? srcElement; // legacy
  readonly attribute EventTarget? currentTarget;
  sequence<EventTarget> composedPath();

  const unsigned short NONE = 0;
  const unsigned short CAPTURING_PHASE = 1;
  const unsigned short AT_TARGET = 2;
  const unsigned short BUBBLING_PHASE = 3;
  readonly attribute unsigned short eventPhase;

  undefined stopPropagation();
           attribute boolean cancelBubble; // legacy alias of .stopPropagation()
  undefined stopImmediatePropagation();

  readonly attribute boolean bubbles;
  readonly attribute boolean cancelable;
           attribute boolean returnValue;  // legacy
  undefined preventDefault();
  readonly attribute boolean defaultPrevented;
  readonly attribute boolean composed;

  [LegacyUnforgeable] readonly attribute boolean isTrusted;
  readonly attribute DOMHighResTimeStamp timeStamp;

  undefined initEvent(DOMString type, optional boolean bubbles = false, optional boolean cancelable = false); // legacy
};

dictionary EventInit {
  boolean bubbles = false;
  boolean cancelable = false;
  boolean composed = false;
};

[Exposed=*]
interface CustomEvent : Event {
  constructor(DOMString type, optional CustomEventInit eventInitDict = {});

  readonly attribute any detail;

  undefined initCustomEvent(DOMString type, optional boolean bubbles = false, optional boolean cancelable = false, optional any detail = null); // legacy
};

dictionary CustomEventInit : EventInit {
  any detail = null;
};

[Exposed=*]
interface EventTarget {
  constructor();

  undefined addEventListener(DOMString type, EventListener? callback, optional (AddEventListenerOptions or boolean) options = {});
  undefined removeEventListener(DOMString type, EventListener? callback, optional (EventListenerOptions or boolean) options = {});
  boolean dispatchEvent(Event event);
};

callback interface EventListener {
  undefined handleEvent(Event event);
};

dictionary EventListenerOptions {
  boolean capture = false;
};

dictionary AddEventListenerOptions : EventListenerOptions {
  boolean passive;
  boolean once = false;
};

[Exposed=*]
interface ErrorEvent : Event {
  constructor(DOMString type, optional ErrorEventInit eventInitDict = {});

  readonly attribute DOMString message;
  readonly attribute USVString filename;
  readonly attribute unsigned long lineno;
  readonly attribute unsigned long colno;
  readonly attribute any error;
};

dictionary ErrorEventInit : EventInit {
  DOMString message = "";
  DOMString filename = "";
  unsigned long lineno = 0;
  unsigned long colno = 0;
  any error;
};

[Exposed=*]
interface PromiseRejectionEvent : Event {
  constructor(DOMString type, PromiseRejectionEventInit eventInitDict);

  readonly attribute object promise;
  readonly attribute any reason;
};

dictionary PromiseRejectionEventInit : EventInit {
  required object promise;
  any reason;
};

[Exposed=Window]
interface PageTransitionEvent : Event {
  constructor(DOMString type, optional PageTransitionEventInit eventInitDict = {});

  readonly attribute boolean persisted;
};

dictionary PageTransitionEventInit : EventInit {
  boolean persisted = false;
};

// M1d (Task 2): the UI events taps dispatch. UI Events' UIEvent, MouseEvent and FocusEvent (with EventModifierInit),
// from https://w3c.github.io/uievents/ (no uievents.idl is vendored); Pointer Events' PointerEvent and Touch Events'
// Touch, TouchList and TouchEvent from third-party/wpt/interfaces/pointerevents.idl and touch-events.idl. Changes in
// README.md.
[Exposed=Window]
interface UIEvent : Event {
  constructor(DOMString type, optional UIEventInit eventInitDict = {});
  readonly attribute Window? view;
  readonly attribute long detail;
};

dictionary UIEventInit : EventInit {
  Window? view = null;
  long detail = 0;
};

[Exposed=Window]
interface FocusEvent : UIEvent {
  constructor(DOMString type, optional FocusEventInit eventInitDict = {});
  readonly attribute EventTarget? relatedTarget;
};

dictionary FocusEventInit : UIEventInit {
  EventTarget? relatedTarget = null;
};

dictionary EventModifierInit : UIEventInit {
  boolean ctrlKey = false;
  boolean shiftKey = false;
  boolean altKey = false;
  boolean metaKey = false;
};

[Exposed=Window]
interface MouseEvent : UIEvent {
  constructor(DOMString type, optional MouseEventInit eventInitDict = {});
  readonly attribute double screenX;
  readonly attribute double screenY;
  readonly attribute double clientX;
  readonly attribute double clientY;
  readonly attribute double pageX;
  readonly attribute double pageY;
  readonly attribute double x;
  readonly attribute double y;
  readonly attribute double offsetX;
  readonly attribute double offsetY;
  readonly attribute boolean ctrlKey;
  readonly attribute boolean shiftKey;
  readonly attribute boolean altKey;
  readonly attribute boolean metaKey;
  readonly attribute short button;
  readonly attribute unsigned short buttons;
  readonly attribute EventTarget? relatedTarget;
  boolean getModifierState(DOMString keyArg);
  // Pointer Lock 2's MouseEvent extension (fidelity plan, Task 4): the delta from the last move delivered.
  readonly attribute double movementX;
  readonly attribute double movementY;
};

dictionary MouseEventInit : EventModifierInit {
  double screenX = 0;
  double screenY = 0;
  double clientX = 0;
  double clientY = 0;
  short button = 0;
  unsigned short buttons = 0;
  EventTarget? relatedTarget = null;
  double movementX = 0;
  double movementY = 0;
};

dictionary PointerEventInit : MouseEventInit {
  long pointerId = 0;
  double width = 1;
  double height = 1;
  float pressure = 0;
  float tangentialPressure = 0;
  long tiltX = 0;
  long tiltY = 0;
  long twist = 0;
  double altitudeAngle = 1.5707963267948966;
  double azimuthAngle = 0;
  DOMString pointerType = "";
  boolean isPrimary = false;
  long persistentDeviceId = 0;
};

[Exposed=Window]
interface PointerEvent : MouseEvent {
  constructor(DOMString type, optional PointerEventInit eventInitDict = {});
  readonly attribute long pointerId;
  readonly attribute double width;
  readonly attribute double height;
  readonly attribute float pressure;
  readonly attribute float tangentialPressure;
  readonly attribute long tiltX;
  readonly attribute long tiltY;
  readonly attribute long twist;
  readonly attribute double altitudeAngle;
  readonly attribute double azimuthAngle;
  readonly attribute DOMString pointerType;
  readonly attribute boolean isPrimary;
  readonly attribute long persistentDeviceId;
};

// Pointer Events' capture (profile 1's input.drag; Sources/Events/Taps.cpp).
partial interface Element {
  undefined setPointerCapture(long pointerId);
  undefined releasePointerCapture(long pointerId);
  boolean hasPointerCapture(long pointerId);
};

enum TouchType {
  "direct",
  "stylus"
};

dictionary TouchInit {
  required long identifier;
  required EventTarget target;
  double clientX = 0;
  double clientY = 0;
  double screenX = 0;
  double screenY = 0;
  double pageX = 0;
  double pageY = 0;
  float radiusX = 0;
  float radiusY = 0;
  float rotationAngle = 0;
  float force = 0;
  double altitudeAngle = 0;
  double azimuthAngle = 0;
  TouchType touchType = "direct";
};

[Exposed=Window]
interface Touch {
  constructor(TouchInit touchInitDict);
  readonly attribute long identifier;
  readonly attribute EventTarget target;
  readonly attribute double screenX;
  readonly attribute double screenY;
  readonly attribute double clientX;
  readonly attribute double clientY;
  readonly attribute double pageX;
  readonly attribute double pageY;
  readonly attribute float radiusX;
  readonly attribute float radiusY;
  readonly attribute float rotationAngle;
  readonly attribute float force;
  readonly attribute float altitudeAngle;
  readonly attribute float azimuthAngle;
  readonly attribute TouchType touchType;
};

[Exposed=Window]
interface TouchList {
  readonly attribute unsigned long length;
  getter Touch? item(unsigned long index);
};

dictionary TouchEventInit : EventModifierInit {
};

[Exposed=Window]
interface TouchEvent : UIEvent {
  constructor(DOMString type, optional TouchEventInit eventInitDict = {});
  readonly attribute TouchList touches;
  readonly attribute TouchList targetTouches;
  readonly attribute TouchList changedTouches;
  readonly attribute boolean altKey;
  readonly attribute boolean metaKey;
  readonly attribute boolean ctrlKey;
  readonly attribute boolean shiftKey;
  boolean getModifierState(DOMString keyArg);
};
