// Web Storage per SDK v1 §2.8 (V2a plan, Task 2; Sources/Host/Storage.cpp): localStorage and sessionStorage, 16 KB of
// keys and values in UTF-8 per area, the area stored for this message given by the host at the first read and committed
// back at the end of a task that changed it. No `storage` event.
[Exposed=Window]
interface Storage {
  readonly attribute unsigned long length;
  DOMString? key(unsigned long index);
  DOMString? getItem(DOMString key);
  undefined setItem(DOMString key, DOMString value);
  undefined removeItem(DOMString key);
  undefined clear();
  getter DOMString (DOMString name);
  setter undefined (DOMString name, DOMString value);
  deleter undefined (DOMString name);
};

partial interface Window {
  [SameObject] readonly attribute Storage localStorage;
  [SameObject] readonly attribute Storage sessionStorage;
};
