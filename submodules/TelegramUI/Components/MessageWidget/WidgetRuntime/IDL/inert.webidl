// SDK v1's removed and inert APIs (V2a plan, Task 1; widget-sandbox v0.1.0 docs/sdk-v1.md §2.10; Sources/Host/Inert.cpp):
// the network globals throw NetworkDisabledError, a DOMException (invariant 5: a widget never causes a network request),
// and fullscreen is refused. Only what a widget can call: the constructors, fetch, importScripts, requestFullscreen.
[Exposed=Window] interface XMLHttpRequest { constructor(any... arguments); };
[Exposed=Window] interface WebSocket { constructor(any... arguments); };
[Exposed=Window] interface EventSource { constructor(any... arguments); };
[Exposed=Window] interface RTCPeerConnection { constructor(any... arguments); };
[Exposed=Window] interface Worker { constructor(any... arguments); };
[Exposed=Window] interface SharedWorker { constructor(any... arguments); };
[Exposed=Window] interface BroadcastChannel { constructor(any... arguments); };

partial interface Window {
  any fetch(any... arguments);
  undefined importScripts(any... urls);
};

partial interface Element {
  any requestFullscreen(any... arguments);
};
