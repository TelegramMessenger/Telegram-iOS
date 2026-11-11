// High Resolution Time (https://w3c.github.io/hr-time/). The DOMHighResTimeStamp typedef is copied byte for byte from
// third-party/wpt/interfaces/hr-time.idl at the pin; Performance is rewritten (README.md).
typedef double DOMHighResTimeStamp;

[Exposed=(Window,Worker)]
interface Performance : EventTarget {
  DOMHighResTimeStamp now();
  readonly attribute DOMHighResTimeStamp timeOrigin;
  object toJSON();
};
