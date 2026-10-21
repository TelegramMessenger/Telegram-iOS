// Resize Observer (V3b plan, Task 2; https://drafts.csswg.org/resize-observer/; Sources/DOM/ResizeObserver.cpp). The
// entry's size lists are `any`, frozen arrays the runtime builds: the generator emits no FrozenArray (README.md).
enum ResizeObserverBoxOptions { "border-box", "content-box", "device-pixel-content-box" };

dictionary ResizeObserverOptions {
  ResizeObserverBoxOptions box = "content-box";
};

[Exposed=Window]
interface ResizeObserver {
  constructor(ResizeObserverCallback callback);
  undefined observe(Element target, optional ResizeObserverOptions options = {});
  undefined unobserve(Element target);
  undefined disconnect();
};

callback ResizeObserverCallback = undefined (sequence<ResizeObserverEntry> entries, ResizeObserver observer);

[Exposed=Window]
interface ResizeObserverEntry {
  readonly attribute Element target;
  readonly attribute DOMRectReadOnly contentRect;
  readonly attribute any borderBoxSize;
  readonly attribute any contentBoxSize;
  readonly attribute any devicePixelContentBoxSize;
};

[Exposed=Window]
interface ResizeObserverSize {
  readonly attribute unrestricted double inlineSize;
  readonly attribute unrestricted double blockSize;
};
