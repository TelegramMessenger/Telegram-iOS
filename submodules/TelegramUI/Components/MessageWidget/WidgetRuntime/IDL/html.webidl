// The widget profile's HTML (and SVG) element interfaces. From third-party/wpt/interfaces/{html,SVG}.idl; changes in
// README.md.
enum DocumentReadyState { "loading", "interactive", "complete" };
enum DocumentVisibilityState { "visible", "hidden" };
partial interface Document {
  // DOM tree accessors
  [CEReactions] attribute DOMString title;
  [CEReactions] attribute HTMLElement? body;
  readonly attribute HTMLHeadElement? head;
  NodeList getElementsByName(DOMString elementName);
  readonly attribute HTMLScriptElement? currentScript; // classic scripts in a document tree only
  readonly attribute DocumentReadyState readyState;
  readonly attribute Window? defaultView;

  readonly attribute boolean hidden;
  readonly attribute DocumentVisibilityState visibilityState;

  // DocumentOrShadowRoot's (M1d plan, Task 3)
  readonly attribute Element? activeElement;

  // special event handler IDL attributes that only apply to Document objects
  [LegacyLenientThis] attribute EventHandler onreadystatechange;
  attribute EventHandler onvisibilitychange;
};

[Exposed=Window]
interface HTMLElement : Element {
  // metadata attributes
  [CEReactions, Reflect] attribute DOMString title;
  [CEReactions, Reflect] attribute DOMString lang;
  // Reflected as written (HTML limits it to the known values ltr, rtl and auto: a divergence).
  [CEReactions, Reflect] attribute DOMString dir;

  // user interaction
  [CEReactions, Reflect] attribute boolean hidden;
  [CEReactions, Reflect] attribute boolean inert;
  undefined click();
  [CEReactions, Reflect] attribute DOMString accessKey;

  // HTMLOrSVGOrMathMLElement's focus members, on HTMLElement only (M1d plan, Task 3).
  [CEReactions] attribute long tabIndex;
  undefined focus();
  undefined blur();
};

// The form-associated elements a tap acts on (M1d plan, Task 3): only the members their activation reads. The rest of
// the forms surface is M2's.
[Exposed=Window]
interface HTMLInputElement : HTMLElement {
  [CEReactions, Reflect] attribute boolean checked;
  [CEReactions, Reflect] attribute boolean disabled;
  [CEReactions, Reflect] attribute DOMString name;
  [CEReactions, Reflect] attribute DOMString type;
  [CEReactions, Reflect] attribute DOMString value;

  // No-ops, as in profile 1's sandbox (V4 plan, Task 8; RB §8.1): the element is not rendered.
  undefined select();
  undefined setSelectionRange(unsigned long start, unsigned long end, optional DOMString direction);
};

[Exposed=Window]
interface HTMLButtonElement : HTMLElement {
  [CEReactions, Reflect] attribute boolean disabled;
  [CEReactions, Reflect] attribute DOMString name;
  [CEReactions, Reflect] attribute DOMString type;
  [CEReactions, Reflect] attribute DOMString value;
};

[Exposed=Window]
interface HTMLLabelElement : HTMLElement {
  [CEReactions, Reflect=for] attribute DOMString htmlFor;
};

[Exposed=Window]
interface HTMLDetailsElement : HTMLElement {
  [CEReactions, Reflect] attribute boolean open;
};

// As profile 1's sandbox has it (V4 plan, Task 8; RB §8.2): show() and showModal() set open, close() removes it and
// fires close synchronously. The renderer's copy is an inert div: no top layer, no ::backdrop.
[Exposed=Window]
interface HTMLDialogElement : HTMLElement {
  [CEReactions, Reflect] attribute boolean open;
  attribute DOMString returnValue;
  undefined show();
  undefined showModal();
  undefined close(optional DOMString returnValue);
};

// The img members a canvas source needs (V5d plan, Task 5; README.md).
[Exposed=Window]
interface HTMLImageElement : HTMLElement {
  [CEReactions, Reflect] attribute DOMString alt;
  [CEReactions, Reflect] attribute DOMString src;
  [CEReactions] attribute unsigned long width;
  [CEReactions] attribute unsigned long height;
  readonly attribute unsigned long naturalWidth;
  readonly attribute unsigned long naturalHeight;
  readonly attribute boolean complete;
  readonly attribute DOMString currentSrc;
};

[Exposed=Window]
interface HTMLFormElement : HTMLElement {
  [CEReactions, Reflect] attribute DOMString name;
};

HTMLElement includes HTMLOrSVGOrMathMLElement;

partial interface Element {
  [CEReactions] attribute [LegacyNullToEmptyString] DOMString innerHTML;
  [CEReactions] attribute [LegacyNullToEmptyString] DOMString outerHTML;
  [CEReactions] undefined insertAdjacentHTML(DOMString position, DOMString string);
};

[Exposed=Window]
interface HTMLUnknownElement : HTMLElement { };

interface mixin HTMLOrSVGOrMathMLElement {
  [SameObject] readonly attribute DOMStringMap dataset;

  [CEReactions, Reflect] attribute boolean autofocus;
};

[Exposed=Window,
 LegacyOverrideBuiltIns]
interface DOMStringMap {
  getter DOMString (DOMString name);
  [CEReactions] setter undefined (DOMString name, DOMString value);
  [CEReactions] deleter undefined (DOMString name);
};

[Exposed=Window]
interface HTMLHtmlElement : HTMLElement { };

[Exposed=Window]
interface HTMLHeadElement : HTMLElement { };

[Exposed=Window]
interface HTMLBodyElement : HTMLElement { };

[Exposed=Window]
interface HTMLDivElement : HTMLElement { };

[Exposed=Window]
interface HTMLSpanElement : HTMLElement { };

[Exposed=Window]
interface HTMLParagraphElement : HTMLElement { };

[Exposed=Window]
interface HTMLAnchorElement : HTMLElement {
  [CEReactions, Reflect] attribute DOMString download;
  [CEReactions, Reflect] attribute DOMString rel;
};
HTMLAnchorElement includes HyperlinkElementUtils;
HTMLAnchorElement includes HTMLHyperlinkElementUtils;

interface mixin HyperlinkElementUtils {
  [CEReactions, Reflect] attribute DOMString hreflang;
  [CEReactions, Reflect] attribute DOMString type;
};

interface mixin HTMLHyperlinkElementUtils {
  [CEReactions, Reflect] stringifier attribute DOMString href;
  [CEReactions, Reflect] attribute DOMString target;
};

[Exposed=Window]
interface HTMLTemplateElement : HTMLElement {
  readonly attribute DocumentFragment content;
};

[Exposed=Window]
interface HTMLScriptElement : HTMLElement {
  [CEReactions, Reflect] attribute DOMString type;
  [CEReactions, Reflect] attribute DOMString src;
  [CEReactions, Reflect] attribute boolean noModule;
  [CEReactions] attribute boolean async;
  [CEReactions, Reflect] attribute boolean defer;
  [CEReactions] attribute DOMString text;

  static boolean supports(DOMString type);
};

partial interface HTMLScriptElement {
  [CEReactions, Reflect] attribute DOMString charset;
  [CEReactions, Reflect] attribute DOMString event;
  [CEReactions, Reflect="for"] attribute DOMString htmlFor;
};

[Exposed=Window]
interface HTMLStyleElement : HTMLElement {
  [CEReactions, Reflect] attribute DOMString media;
};

[Exposed=Window]
interface SVGElement : Element { };

// SVG 2's geometry interfaces (V3b plan, Task 4; Sources/DOM/SVGGeometry.cpp): what getBBox, the path lengths and the
// text length need; lengths are `double` where SVG has `float` (README.md).
dictionary SVGBoundingBoxOptions {
  boolean fill = true;
  boolean stroke = false;
  boolean markers = false;
  boolean clipped = false;
};

interface SVGGraphicsElement : SVGElement {
  [NewObject] DOMRect getBBox(optional SVGBoundingBoxOptions options = {});
};

interface SVGGeometryElement : SVGGraphicsElement {
  unrestricted double getTotalLength();
  [NewObject] DOMPoint getPointAtLength(unrestricted double distance);
};

interface SVGTextContentElement : SVGGraphicsElement {
  long getNumberOfChars();
  double getComputedTextLength();
};

SVGElement includes HTMLOrSVGOrMathMLElement;

// Event handlers, from third-party/wpt/interfaces/html.idl (M1b Task 12). The mixins are profile-trimmed and
// GlobalEventHandlers gains Pointer Events' and Touch Events' partials (README).
[LegacyTreatNonObjectAsNull]
callback EventHandlerNonNull = any (Event event);
typedef EventHandlerNonNull? EventHandler;

[LegacyTreatNonObjectAsNull]
callback OnErrorEventHandlerNonNull = any ((Event or DOMString) event, optional DOMString source, optional unsigned long lineno, optional unsigned long colno, optional any error);
typedef OnErrorEventHandlerNonNull? OnErrorEventHandler;

interface mixin GlobalEventHandlers {
  attribute EventHandler onabort;
  attribute EventHandler onauxclick;
  attribute EventHandler onbeforeinput;
  attribute EventHandler onbeforetoggle;
  attribute EventHandler onblur;
  attribute EventHandler oncancel;
  attribute EventHandler onchange;
  attribute EventHandler onclick;
  attribute EventHandler onclose;
  attribute EventHandler oncommand;
  attribute EventHandler oncontextmenu;
  attribute EventHandler oncopy;
  attribute EventHandler oncut;
  attribute EventHandler ondblclick;
  attribute OnErrorEventHandler onerror;
  attribute EventHandler onfocus;
  attribute EventHandler oninput;
  attribute EventHandler oninvalid;
  attribute EventHandler onkeydown;
  attribute EventHandler onkeypress;
  attribute EventHandler onkeyup;
  attribute EventHandler onload;
  attribute EventHandler onmousedown;
  [LegacyLenientThis] attribute EventHandler onmouseenter;
  [LegacyLenientThis] attribute EventHandler onmouseleave;
  attribute EventHandler onmousemove;
  attribute EventHandler onmouseout;
  attribute EventHandler onmouseover;
  attribute EventHandler onmouseup;
  attribute EventHandler onpaste;
  attribute EventHandler onreset;
  attribute EventHandler onresize;
  attribute EventHandler onscroll;
  attribute EventHandler onscrollend;
  attribute EventHandler onselect;
  attribute EventHandler onsubmit;
  attribute EventHandler ontoggle;
  attribute EventHandler onwebkitanimationend;
  attribute EventHandler onwebkitanimationiteration;
  attribute EventHandler onwebkitanimationstart;
  attribute EventHandler onwebkittransitionend;
  attribute EventHandler onwheel;
};

// From Pointer Events (interfaces/pointerevents.idl) and Touch Events (interfaces/touch-events.idl) at the pin,
// copied byte for byte (README.md).
partial interface mixin GlobalEventHandlers {
    attribute EventHandler onpointerover;
    attribute EventHandler onpointerenter;
    attribute EventHandler onpointerdown;
    attribute EventHandler onpointermove;
    [SecureContext] attribute EventHandler onpointerrawupdate;
    attribute EventHandler onpointerup;
    attribute EventHandler onpointercancel;
    attribute EventHandler onpointerout;
    attribute EventHandler onpointerleave;
    attribute EventHandler ongotpointercapture;
    attribute EventHandler onlostpointercapture;
};

partial interface mixin GlobalEventHandlers {
                    attribute EventHandler ontouchstart;
                    attribute EventHandler ontouchend;
                    attribute EventHandler ontouchmove;
                    attribute EventHandler ontouchcancel;
};

interface mixin WindowEventHandlers {
  attribute EventHandler onpagehide;
  attribute EventHandler onpageshow;
  attribute EventHandler onrejectionhandled;
  attribute EventHandler onunhandledrejection;
};

Document includes GlobalEventHandlers;
HTMLElement includes GlobalEventHandlers;
SVGElement includes GlobalEventHandlers;
HTMLBodyElement includes WindowEventHandlers;
