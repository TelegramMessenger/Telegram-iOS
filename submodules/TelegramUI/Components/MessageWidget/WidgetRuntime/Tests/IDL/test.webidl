// The generator's end-to-end fixture: every construct the emitter supports, bound to wr::testidl's test impls.
[Exposed=Window]
interface TestBase {
  readonly attribute DOMString baseName;
};

dictionary TestOptions {
  DOMString prefix = ">";
  boolean loud = false;
};

[Exposed=Window]
interface TestSample : TestBase {
  constructor(optional DOMString label = "unnamed");
  const unsigned short ONE = 1;
  readonly attribute unsigned long count;
  attribute DOMString? label;
  attribute [LegacyNullToEmptyString] DOMString text;
  TestBase? find(DOMString name, optional boolean deep = false);
  undefined add((TestSample or DOMString)... items);
  DOMString describe(optional (DOMString or TestOptions) options = {});
  undefined fail(DOMString name);
  DOMString primitiveKind((DOMString or unrestricted double or boolean) value);
  static double half(unrestricted double x);
};

[Exposed=Window]
interface TestList {
  readonly attribute unsigned long length;
  getter TestSample? item(unsigned long index);
  iterable<TestSample>;
};

// A pair iterator (V5a plan, Task 5): a list of (DOMString, long) the test fills and shrinks.
[Exposed=Window]
interface TestPairs {
  constructor();
  undefined append(DOMString key, long value);
  undefined removeFirst();
  iterable<DOMString, long>;
};

[LegacyNoInterfaceObject]
interface TestHidden {};

callback TestCallback = DOMString (DOMString value);
[LegacyTreatNonObjectAsNull] callback TestHandlerNonNull = any (any event);
callback interface TestListener {
  undefined handleEvent(DOMString what);
};
typedef (DOMString or TestCallback) TestHandler;

dictionary TestDetailInit {
  any detail = null;
  TestCallback? onDone = null;
};

[Exposed=Window]
interface TestCallbacks {
  constructor();
  attribute TestCallback? stored;
  attribute TestHandlerNonNull? legacy;
  readonly attribute boolean listenerIsFunction;
  DOMString invoke(TestCallback callback, DOMString value);
  DOMString handlerKind(TestHandler handler);
  undefined listen(TestListener listener);
  any detailOf(optional TestDetailInit init = {});
};

[LegacyTreatNonObjectAsNull] callback EventHandlerNonNull = any (any event);
typedef EventHandlerNonNull? EventHandler;
[LegacyTreatNonObjectAsNull] callback OnErrorEventHandlerNonNull = any (any event, optional DOMString source, optional unsigned long lineno, optional unsigned long colno, optional any error);
typedef OnErrorEventHandlerNonNull? OnErrorEventHandler;

[Exposed=Window]
interface TestTarget {
  constructor();
  attribute EventHandler onping;
  attribute OnErrorEventHandler onerror;
  [LegacyUnforgeable] readonly attribute DOMString serial;
  [LegacyUnforgeable] DOMString stamp();
  DOMString handlerTypes();
};

[Global=TestWindow, Exposed=TestWindow]
interface TestGlobal : TestTarget {
  const unsigned short TEN = 10;
  [LegacyUnforgeable] readonly attribute TestGlobal window;
  [Replaceable] readonly attribute TestGlobal self;
  readonly attribute unsigned long ticks;
  unsigned long tick();
};
