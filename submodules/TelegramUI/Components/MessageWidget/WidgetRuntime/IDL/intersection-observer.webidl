// Intersection Observer (V3b plan, Task 3; https://w3c.github.io/IntersectionObserver/; Sources/DOM/IntersectionObserver.cpp).
// `root` is an Element (no Document root); the `threshold` option is `any` (a number or an array of numbers: the
// generator emits no sequence member), `thresholds` and takeRecords() are `any` (a frozen array and an array the
// runtime builds); no scrollMargin, delay or trackVisibility; the entry has no constructor (README.md).
callback IntersectionObserverCallback = undefined (sequence<IntersectionObserverEntry> entries, IntersectionObserver observer);

dictionary IntersectionObserverInit {
  Element? root = null;
  DOMString rootMargin = "0px";
  any threshold;
};

[Exposed=Window]
interface IntersectionObserver {
  constructor(IntersectionObserverCallback callback, optional IntersectionObserverInit options = {});
  readonly attribute Element? root;
  readonly attribute DOMString rootMargin;
  readonly attribute any thresholds;
  undefined observe(Element target);
  undefined unobserve(Element target);
  undefined disconnect();
  any takeRecords();
};

[Exposed=Window]
interface IntersectionObserverEntry {
  readonly attribute DOMHighResTimeStamp time;
  readonly attribute DOMRectReadOnly? rootBounds;
  readonly attribute DOMRectReadOnly boundingClientRect;
  readonly attribute DOMRectReadOnly intersectionRect;
  readonly attribute boolean isIntersecting;
  readonly attribute double intersectionRatio;
  readonly attribute Element target;
};
