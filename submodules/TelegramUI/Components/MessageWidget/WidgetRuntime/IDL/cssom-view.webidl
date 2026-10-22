// CSSOM View's geometry members and the Geometry Interfaces' rectangles (V3 plan, Task 3), written from the specs:
// https://drafts.csswg.org/cssom-view/ and https://drafts.fxtf.org/geometry/. Changes from the specs: README.md.

[Exposed=(Window,Worker)]
interface DOMRectReadOnly {
  readonly attribute unrestricted double x;
  readonly attribute unrestricted double y;
  readonly attribute unrestricted double width;
  readonly attribute unrestricted double height;
  readonly attribute unrestricted double top;
  readonly attribute unrestricted double right;
  readonly attribute unrestricted double bottom;
  readonly attribute unrestricted double left;

  object toJSON();
};

[Exposed=(Window,Worker)]
interface DOMRect : DOMRectReadOnly {
};

[Exposed=Window]
interface DOMRectList {
  readonly attribute unsigned long length;
  getter DOMRect? item(unsigned long index);
};

partial interface Element {
  DOMRectList getClientRects();
  [NewObject] DOMRect getBoundingClientRect();
  attribute unrestricted double scrollTop;
  attribute unrestricted double scrollLeft;
  readonly attribute long scrollWidth;
  readonly attribute long scrollHeight;
  readonly attribute long clientTop;
  readonly attribute long clientLeft;
  readonly attribute long clientWidth;
  readonly attribute long clientHeight;
};

partial interface HTMLElement {
  readonly attribute Element? offsetParent;
  readonly attribute long offsetTop;
  readonly attribute long offsetLeft;
  readonly attribute long offsetWidth;
  readonly attribute long offsetHeight;
};

partial interface Document {
  Element? elementFromPoint(double x, double y);
};

// Geometry Interfaces' points (V3b plan, Task 4): what SVGGeometryElement.getPointAtLength returns; no constructors,
// matrices or setters (README.md).
[Exposed=Window]
interface DOMPointReadOnly {
  readonly attribute unrestricted double x;
  readonly attribute unrestricted double y;
  readonly attribute unrestricted double z;
  readonly attribute unrestricted double w;
  object toJSON();
};

[Exposed=Window]
interface DOMPoint : DOMPointReadOnly {
};

partial interface Window {
  [Replaceable] readonly attribute long innerWidth;
  [Replaceable] readonly attribute long innerHeight;
  [Replaceable] readonly attribute double devicePixelRatio;
  [NewObject] MediaQueryList matchMedia(DOMString query);
};

// CSSOM View's media queries (V3b plan, Task 1; Sources/DOM/MediaQueries.cpp). CSSOMString is DOMString here, as in
// cssom.webidl (README.md).
[Exposed=Window]
interface MediaQueryList : EventTarget {
  readonly attribute DOMString media;
  readonly attribute boolean matches;
  undefined addListener(EventListener? callback);
  undefined removeListener(EventListener? callback);
  attribute EventHandler onchange;
};

[Exposed=Window]
interface MediaQueryListEvent : Event {
  constructor(DOMString type, optional MediaQueryListEventInit eventInitDict = {});
  readonly attribute DOMString media;
  readonly attribute boolean matches;
};

dictionary MediaQueryListEventInit : EventInit {
  DOMString media = "";
  boolean matches = false;
};
