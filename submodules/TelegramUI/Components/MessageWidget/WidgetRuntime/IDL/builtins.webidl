// The built-ins of profile 1 (V5a plan; widgets v0.1.0 client design §5 V5), each against its own standard: not from
// WPT's interface files, which carry more than the runtime implements. Divergences are in README.md.

// Web Cryptography API §10.1, getRandomValues and randomUUID only (no `subtle`). `array` is `any`: the generator has
// no ArrayBufferView, and the standard's TypeError for a non-view comes from the method itself.
[Exposed=Window]
interface Crypto {
  any getRandomValues(any array);
  DOMString randomUUID();
};

partial interface Window {
  [SameObject] readonly attribute Crypto crypto;
};

// HTML §8.3, the Base64 utility methods. HTML's ByteString return is a DOMString here: atob's code units are all at
// most 0xFF.
partial interface Window {
  DOMString btoa(DOMString data);
  DOMString atob(DOMString data);
};

// The Encoding Standard, UTF-8 only (any other label is a RangeError). `any` stands for its buffer sources, its
// dictionaries and its Uint8Array results, which the generator lacks.
[Exposed=Window]
interface TextEncoder {
  constructor();
  readonly attribute DOMString encoding;
  any encode(optional USVString input = "");
  any encodeInto(USVString source, any destination);
};

[Exposed=Window]
interface TextDecoder {
  constructor(optional DOMString label = "utf-8", optional any options);
  readonly attribute DOMString encoding;
  readonly attribute boolean fatal;
  readonly attribute boolean ignoreBOM;
  USVString decode(optional any input, optional any options);
};

// HTML §2.7.10, structuredClone. `options` is `any`: StructuredSerializeOptions' sequence member is outside the
// generator, and a non-empty `transfer` is a DataCloneError (no transfer).
partial interface Window {
  any structuredClone(any value, optional any options);
};

// The URL Standard §6.2. `init` is `any`: the standard's union of sequence<sequence<USVString>>,
// record<USVString, USVString> and USVString is outside the generator, so the constructor tells them apart itself.
[Exposed=Window]
interface URLSearchParams {
  constructor(optional any init);
  readonly attribute unsigned long size;
  undefined append(USVString name, USVString value);
  undefined delete(USVString name, optional USVString value);
  USVString? get(USVString name);
  sequence<USVString> getAll(USVString name);
  boolean has(USVString name, optional USVString value);
  undefined set(USVString name, USVString value);
  undefined sort();
  iterable<USVString, USVString>;
  stringifier;
};

// The URL Standard §6.1, without IDNA (a domain with a non-ASCII code point fails until ICU brings UTS 46), and File
// API's object URL methods, which make nothing (createObjectURL answers "").
[Exposed=Window]
interface URL {
  constructor(USVString url, optional USVString base);
  static URL? parse(USVString url, optional USVString base);
  static boolean canParse(USVString url, optional USVString base);
  stringifier attribute USVString href;
  readonly attribute USVString origin;
  attribute USVString protocol;
  attribute USVString username;
  attribute USVString password;
  attribute USVString host;
  attribute USVString hostname;
  attribute USVString port;
  attribute USVString pathname;
  attribute USVString search;
  [SameObject] readonly attribute URLSearchParams searchParams;
  attribute USVString hash;
  USVString toJSON();
  static DOMString createObjectURL(any obj);
  static undefined revokeObjectURL(DOMString url);
};

// DOM §3.1–3.2. No abort algorithms (nothing in the runtime takes a signal: there is no fetch) and no AbortSignal.any.
[Exposed=Window]
interface AbortController {
  constructor();
  [SameObject] readonly attribute AbortSignal signal;
  undefined abort(optional any reason);
};

[Exposed=Window]
interface AbortSignal : EventTarget {
  [NewObject] static AbortSignal abort(optional any reason);
  [NewObject] static AbortSignal timeout([EnforceRange] unsigned long long milliseconds);
  readonly attribute boolean aborted;
  readonly attribute any reason;
  undefined throwIfAborted();
  attribute EventHandler onabort;
};

// File API §3, Blob. `any` stands for the sequence of BlobParts, BlobPropertyBag and the promises the generator lacks;
// `endings` is ignored.
[Exposed=Window]
interface Blob {
  constructor(optional any blobParts, optional any options);
  readonly attribute unsigned long long size;
  readonly attribute DOMString type;
  [NewObject] Blob slice(optional long long start, optional long long end, optional DOMString contentType);
  any text();
  any arrayBuffer();
};
