# The profile's WebIDL

`dom.webidl` and `html.webidl` are the interfaces and members the widget profile needs, copied from
`third-party/wpt/interfaces/{dom,html,SVG}.idl` (see that directory's VENDOR.md for the commit). An interface or member
enters only when the profile needs it (spec 2026-10-16-message-widgets-native-runtime-design.md, section 6.1), so
both files grow with the milestones. Copy text verbatim; every change from the source is listed here.

## Changes from the source

- `[HTMLConstructor] constructor();` removed from HTMLElement and its subclasses: custom elements are not in the
  profile.
- `ElementCreationOptions`: `customElementRegistry` removed (no custom element registries).
- `(TrustedHTML or [LegacyNullToEmptyString] DOMString)` written as `[LegacyNullToEmptyString] DOMString`,
  `(TrustedHTML or DOMString)` (`insertAdjacentHTML`'s markup) as `DOMString`, and `(TrustedScript or DOMString)` as
  `DOMString`: no Trusted Types.
- `Element`'s `setHTMLUnsafe` and `getHTML` are left out: the profile has no declarative shadow DOM and no script uses
  them. So are the other markup methods of that partial interface: `appendHTMLUnsafe`, `prependHTMLUnsafe`, and the
  Sanitizer API's `setHTML`, `appendHTML` and `prependHTML`.
- `[ReflectURL] attribute USVString` written as `[Reflect] attribute DOMString` until M2's URL parser: the value reads
  back as written, not resolved against the document URL.
- `HTMLElement.hidden` is `(boolean or unrestricted double or DOMString)?` in the source; here
  `[CEReactions, Reflect] attribute boolean hidden;` (no `until-found`).
- importNode's second argument is (boolean or ImportNodeOptions) in the source; here optional boolean subtree = false
  (ImportNodeOptions only carries custom element registries and selfOnly).
- `setAttribute`'s and `setAttributeNS`'s value is `(TrustedType or DOMString)` in the source; here `DOMString`.
- `HTMLHyperlinkElementUtils.href` is `[CEReactions, ReflectSetter] stringifier attribute USVString href` in the
  source; here `[CEReactions, Reflect] stringifier attribute DOMString href` (no URL parsing until M2: it reads back as
  written). `HyperlinkElementUtils` keeps only `hreflang` and `type`: its URL members (`origin`, `protocol`, `host`,
  …) need the URL parser.
- `HTMLScriptElement.src` is `[CEReactions] attribute (TrustedScriptURL or USVString) src` in the source (a URL,
  through Trusted Types); here `[CEReactions, Reflect] attribute DOMString src`.
- `HTMLScriptElement` keeps `type`, `src`, `noModule`, `async`, `defer`, `text` and `supports()`, and the obsolete
  `charset`, `event` and `htmlFor`. Left out: `crossOrigin`, `referrerPolicy`, `integrity`, `fetchPriority` and
  `blocking`, which do nothing without a network, and the Trusted Types overrides of `innerText` and `textContent`
  (`(TrustedScript or DOMString)` in the source). `text` is `(TrustedScript or DOMString)` in the source; here
  `DOMString`. `supports()` answers true for "classic" and "module" only: import maps and speculation rules are not
  supported.
- `Document.currentScript` is `HTMLOrSVGScriptElement?` in the source; here `HTMLScriptElement?` (no SVG scripts, and
  the generator returns no unions).
- `Document.defaultView` is `WindowProxy?` in the source; here `Window?` (no browsing contexts: the global is the
  window). It is the window for the main document and null for any other (`new Document()`, template contents).
- `HTMLOrSVGOrMathMLElement` carries only `dataset` and `autofocus`. Its focus members are on `HTMLElement` alone
  (M1d plan, Task 3; SVG elements have no focus model yet), in `html.webidl`: `tabIndex` is `[CEReactions]` with
  native accessors, the getter answering the parsed attribute or else the default (0 for a focusable kind, -1 for the
  rest) and the setter writing the attribute
  (`[CEReactions, ReflectSetter]` in the source), `focus()` takes no options
  (`optional FocusOptions options = {}` in the source; there is no `FocusOptions`), and `blur()` is as written. `nonce`
  is left out: nothing reads it.
- The partial `Document` is `[LegacyOverrideBuiltIns]` in the source, for its named getter (`getter object (DOMString
  name)`); here neither: Document has no named properties in M1a.
- `NamedNodeMap`'s named getter (`getNamedItem`) binds as an ordinary method only. The generator gives an interface
  with an indexed getter the indexed exotic alone, so `attributes.id` is `undefined`; `HTMLCollection`'s named
  properties wait for M2 the same way (M1a plan, ruling 3).
- `EventTarget` and the event interfaces are in `events.webidl`: DOM's `Event`, `CustomEvent`, `EventTarget`,
  `EventListener` and their dictionaries (dom.idl), and HTML's `ErrorEvent`, `PromiseRejectionEvent` and
  `PageTransitionEvent` (html.idl).
- `AddEventListenerOptions.signal` is left out: `AbortSignal` waits for M2 (M1b plan, Ruling 5). So is DOM's
  `partial interface Window { [Replaceable] readonly attribute (Event or undefined) event; }`.
- `ErrorEventInit.filename` is `USVString` in the source; here `DOMString`, because the generator cannot default a
  `USVString` member yet. `ErrorEvent.filename` stays `USVString`.
- `hr-time.webidl` carries `typedef double DOMHighResTimeStamp;` and `Performance` from High Resolution Time. The
  typedef line is copied byte for byte from `third-party/wpt/interfaces/hr-time.idl`;
  `Performance` is the pin's, rewritten as the next item says.
- `Document.createEvent` knows `Event` (`event`, `events`, `htmlevents`, `svgevents`), `CustomEvent`, and since M1d
  `FocusEvent`, `MouseEvent` (`mouseevent`, `mouseevents`), `TouchEvent` and `UIEvent` (`uievent`, `uievents`). The other
  names in DOM's table (`KeyboardEvent`, `CompositionEvent`, …) throw `NotSupportedError`: there is no keyboard path
  into widgets.
- The UI events (M1d plan, Task 2) are in `events.webidl`. `UIEvent`, `FocusEvent`, `MouseEvent` and
  `EventModifierInit` are written from UI Events (no `uievents.idl` is vendored); `MouseEvent` carries CSSOM View's
  `pageX`/`pageY`, `x`/`y` and `offsetX`/`offsetY` (all the client point: a widget has no scroll viewport, and offsets
  need M2's layout queries), and none of the legacy `initMouseEvent`/`which`. `PointerEvent` is Pointer Events'
  without `getCoalescedEvents`/`getPredictedEvents` (sequence returns of events the runtime never coalesces) and
  `Element`'s pointer-capture methods. `TouchEventInit` has none of its `touches`/`targetTouches`/`changedTouches`
  members (the generator takes no sequence members), so a constructed `TouchEvent` has empty lists.
- `Window` (window.webidl) has only `window`, `self`, `document`, `location`, `frames`, `length`, `top`, `opener`
  and `parent`, plus its mixins; everything else waits for M2 (M1b plan, Ruling 10). `WindowProxy` is written
  `Window`: the global is the Window itself, with no WindowProxy exotic object. `location` loses `[PutForwards=href]`,
  `opener` is `readonly attribute any` and reads `null`, and the named getter with
  `[LegacyUnenumerableNamedProperties]` is left out.
- `Location`'s members are `[LegacyUnforgeable]` in the source, with writable `href`…`hash` and
  `assign`/`replace`/`reload`/`ancestorOrigins`. Here they are plain read-only attributes, split from the document's URL
  without a URL parser. Navigation and the URL parser wait for M2.
- `Performance` (hr-time.webidl): `[Default] object toJSON()` is written `object toJSON()`. The window's `performance`
  attribute sits in `WindowOrWorkerGlobalScope` itself; the source declares it in a partial mixin in hr-time.idl.
- `console` is not IDL. It is a plain namespace object with `log`, `info`, `warn`, `error` and `debug` (Ruling 10).
- `webidl.webidl` holds the WebIDL standard's callback types (`VoidFunction`; Task 10 adds `Function`), copied
  byte for byte from `third-party/wpt/interfaces/webidl.idl` at the pin (the upstream file name is lower case).
  `Function` comes first there, as here.
- `TimerHandler` is `(DOMString or Function or TrustedScript)` in the source; here `(DOMString or Function)` (no Trusted
  Types). A string handler runs as a global classic script, as HTML says.
- `WindowOrWorkerGlobalScope` grows by milestone: Task 9 binds `reportError` and `queueMicrotask`, Task 10
  `setTimeout`, `setInterval`, `clearTimeout` and `clearInterval`; `origin`, `isSecureContext`, `crossOriginIsolated`,
  `btoa`/`atob`, `createImageBitmap` and `structuredClone` wait for M2.
- `AnimationFrameProvider` is included by `Window` only (no workers). `requestAnimationFrame` shares the 256 live
  timers and callbacks limit with the timers (M1b plan, Ruling 8): past it, a RangeError.
- `GlobalEventHandlers` keeps the members whose events the profile can fire.
  - Removed (the events never fire): `onbeforematch`, `oncanplay`, `oncanplaythrough`, `oncontextlost`,
    `oncontextrestored`, `oncuechange`, `ondrag`, `ondragend`, `ondragenter`, `ondragleave`, `ondragover`,
    `ondragstart`, `ondrop`, `ondurationchange`, `onemptied`, `onended`, `onformdata`, `onloadeddata`,
    `onloadedmetadata`, `onloadstart`, `onpause`, `onplay`, `onplaying`, `onprogress`, `onratechange`,
    `onsecuritypolicyviolation`, `onseeked`, `onseeking`, `onslotchange`, `onstalled`, `onsuspend`, `ontimeupdate`,
    `onvolumechange` and `onwaiting`.
  - Added: Pointer Events' `on*pointer*` handlers and Touch Events' `ontouch*` handlers. Each is a
    `partial interface mixin GlobalEventHandlers` copied byte for byte from the pin's `interfaces/pointerevents.idl`
    and `interfaces/touch-events.idl`, `[SecureContext]` on `onpointerrawupdate` included.
  - The CSS Animations and Transitions handlers (`onanimation*`, `ontransition*`) are `css-animations.webidl`'s (V5f).
- `WindowEventHandlers` keeps `onpagehide`, `onpageshow`, `onrejectionhandled` and `onunhandledrejection`.
  - `onbeforeunload` (`OnBeforeUnloadEventHandler`) is removed: there is no unload model.
  - So are the printing, history, messaging, online, storage, language and unload handlers.
  - `HTMLFrameSetElement` and `SVGSVGElement` are not in the profile: a `frameset`'s window-reflecting content
    attributes still reach the window, but it has no IDL attributes.
- At the pin, `DocumentAndElementEventHandlers` no longer exists: `oncopy`, `oncut` and `onpaste` are in
  `GlobalEventHandlers`.
- `[LegacyLenientThis]` (on `onmouseenter`, `onmouseleave` and Document's `onreadystatechange`) stays in the text but
  the generator ignores it (M1b plan, Ruling 4): the getter or setter called on an object that does not implement the
  interface throws a TypeError, where WebIDL returns undefined.
- `telegram.webidl` (M1d plan, Task 4; SDK v1 since the V2a plan) is not from WPT: `TelegramWidget` is
  widget-sandbox v0.1.0's SDK object (`docs/sdk-v1.md`), `[LegacyNoInterfaceObject]`, reached as the window's
  `[LegacyUnforgeable]` `TelegramWidget`. Arguments the SDK ignores or rejects by type rather than converting are
  `optional any`: `isProfileAtLeast(n)` (a non-number is false), `onEvent`/`offEvent` (an unknown type or a non-function
  is ignored), `openLink`/`openTelegramLink` (a non-string is a `TypeError`), and `HapticFeedback`'s style and type (only
  the listed strings pass). `themeParams` is `object`: one frozen plain object until the theme changes.
  `HapticFeedback` is `[LegacyNoInterfaceObject]` and its methods return it. The window members differ from HTML:
  `open(url)` returns `null` (no browsing contexts; HTML's returns `WindowProxy?`) and follows the URL as an
  `<a href>` would; `alert` and `confirm` take one optional `DOMString` and `prompt` two (no overloads) and do nothing
  (`confirm` false, `prompt` null). `Navigator` has `clipboard`, `language`, `languages` (`any`: a fresh frozen array,
  not a `FrozenArray`, which the generator lacks), `sendBeacon`, `vibrate`, `share` and `canShare`; `Clipboard` (not an
  `EventTarget` here) has the four methods, typed `any` because the generator returns no `Promise`, each returning a
  promise rejected with `NotAllowedError`.
- `inert.webidl` (V2a plan, Task 1) is not from WPT: SDK v1's network globals as bare constructors (`any...`
  arguments, no members) that throw `NetworkDisabledError`, with `fetch`, `importScripts` and `requestFullscreen`; only
  what a widget can call, so a page testing `typeof WebSocket` sees a function, as in the reference.
- `storage.webidl` (V2a plan, Task 2) is HTML's `Storage` without the `storage` event, `[LegacyOverrideBuiltIns]`
  left to the named-property code (which checks visibility itself), with `localStorage` and `sessionStorage` on the
  window.
- `builtins.webidl` (V5a plan) is not from WPT: each built-in is written from its own standard and carries only what
  the runtime implements. `Crypto` has `getRandomValues` and `randomUUID` (no `subtle`), and takes `any` where Web
  Crypto has `ArrayBufferView`: the generator has no buffer types, so the method itself raises the standard's
  `TypeError` for a non-view and `TypeMismatchError` for a float array or a `DataView`.
  `atob` returns `DOMString` where HTML has `ByteString` (each of its code units is at most 0xFF).
  `TextEncoder` and `TextDecoder` know UTF-8 only (another label is a `RangeError`), take `any` for the standard's
  buffer sources and dictionaries, and return a plain object for `encodeInto`'s dictionary.
  `structuredClone` takes `options` as `any` (StructuredSerializeOptions has a sequence member) and refuses a
  non-empty `transfer` with `DataCloneError`.
  `URLSearchParams` takes `init` as `any` (the standard's union of sequence, record and string is outside the
  generator) and tells the three apart in its constructor. Its `delete` is `delete_` in C++: the generator appends `_`
  to a member named with a C++ keyword.
  `URL` follows the URL Standard's IDL; its parser has no IDNA (a domain with a non-ASCII code point fails until V5b's
  ICU) and its setters re-parse instead of using the state override; `createObjectURL` and `revokeObjectURL` (File API)
  make nothing.
  `Blob` takes `any` for its parts, its options and its promises; `slice`'s indices are plain `long long` (the
  generator has no `[Clamp]`), and `endings` is ignored.
- The form elements a tap acts on (M1d plan, Task 3): `HTMLInputElement`, `HTMLButtonElement`, `HTMLLabelElement`,
  `HTMLDetailsElement` and `HTMLFormElement` carry only plain `[Reflect]` members. `checked` reflects the content
  attribute (HTML's dirty checkedness is M2's forms), so a toggle writes the attribute, which litehtml's `:checked` and
  its control drawing read. `type` reads the attribute as written (no enumerated default: `""` when absent).
  `HTMLElement` carries `click()`, `focus()`, `blur()` and `tabIndex` (HTMLOrSVGOrMathMLElement's focus members, not on
  `SVGElement` yet), and `Document` carries `activeElement`.
- `cssom.webidl` is CSSOM's inline style declaration block only, from the pin's `interfaces/cssom.idl`:
  `CSSStyleDeclaration` without `parentRule` (no `CSSRule` yet), `CSSOMString` written as `DOMString` (its typedef),
  and `ElementCSSInlineStyle` on `HTMLElement` and `SVGElement` (MathML is not in the profile). Its declarations are
  the `style` attribute's, parsed on each access; values are kept as their text, so a shorthand is not expanded into
  its longhands (`style.margin = '1px'` leaves `marginTop` empty), a value is not normalized or validated beyond its
  syntax (no top-level `;` or `!`), and `getComputedStyle` is not here. `cssom-properties.webidl` is CSSOM's
  `CSSStyleProperties`, generated by `generate-css-properties.py` from `css-properties.txt`: the camel-cased attribute
  of every listed property (the webkit-cased one too for a `-webkit-` property; `float`'s is `cssFloat` only, `float`
  being an IDL keyword), each `[CSSProperty=<name>]`, a WidgetIDL extended attribute that routes the attribute to the
  block's generic accessors by the property's name and adds the dashed attribute (`style['background-color']`).
- `cssom-view.webidl` (V3 plan, Task 3) is written from CSSOM View (https://drafts.csswg.org/cssom-view/) and Geometry
  Interfaces (https://drafts.fxtf.org/geometry/), which `third-party/wpt/interfaces` does not carry. Only what the
  geometry queries return and read: `DOMRectReadOnly` and `DOMRect` have no constructors and no `fromRect`, `DOMRect`'s
  `x`/`y`/`width`/`height` are read-only (its setters are not bound), `toJSON` is `object toJSON()` without
  `[Default]`; `DOMRectList` keeps `length` and its indexed `item`. `Element` gains `getClientRects`,
  `getBoundingClientRect`, the client sizes and the scroll sizes and offsets (nothing scrolls: `scrollTop` and
  `scrollLeft` read 0 and ignore writes; no `scroll()`, `scrollTo()`, `scrollBy()` or `scrollIntoView()`);
  `HTMLElement` the offset members; `Document` `elementFromPoint` (no `elementsFromPoint`, `caretPositionFromPoint`);
  `Window` `innerWidth` and `innerHeight` (`long`, the layout width and the document's height: a widget has no
  viewport; no `scrollX`, `outerWidth`, `devicePixelRatio`, `screen`).
- `matchMedia`, `MediaQueryList` and `MediaQueryListEvent` (V3b plan, Task 1; `cssom-view.webidl`) are CSSOM View's,
  with `DOMString` for `CSSOMString`. `media` is the query with its whitespace collapsed and trimmed, not the
  serialization of the parsed list (`'(MIN-WIDTH: 1px)'` keeps its case). A query is evaluated by litehtml's media query
  parser against the features `@media` sees: `prefers-color-scheme` follows the theme, `hover`, `pointer` and
  `prefers-reduced-motion` are not features litehtml knows (so they never match, as profile 1 wants hover and pointer),
  `print` never applies. `change` is reported after every task and frame, so a theme or width change reaches its
  listeners after the task that made it (a width change queues one). A query longer than `work::kMaxMediaQueryBytes`
  (16384) is refused before it is copied: it reads as `not all` and never matches.
- `resize-observer.webidl` (V3b plan, Task 2) is Resize Observer's, with the entry's `borderBoxSize`, `contentBoxSize`
  and `devicePixelContentBoxSize` as `any` (frozen arrays of one `ResizeObserverSize` the runtime builds: the generator
  emits no `FrozenArray`). The writing mode is horizontal, so inline is the width; the device-pixel box is the content
  box (the runtime lays out in CSS px). Delivery follows the spec's loop without its depth rule: at most
  `work::kResizeObserverRounds` rounds per rendering update, then the loop error, the rest next time.
- `intersection-observer.webidl` (V3b plan, Task 3) is Intersection Observer's, with `root` an `Element?` (no
  `Document` root), the `threshold` option as `any` (a number, or an array of numbers, converted by the runtime: the
  generator emits no sequence member), `thresholds` and `takeRecords()` as `any` (a frozen array and an array the
  runtime builds), and
  without `scrollMargin`, `delay`, `trackVisibility` or the entry's constructor. The implicit root is the widget's whole
  area, `(0, 0, layout width, document height)`: a widget has no viewport, and the bubble's clip at its maximum height
  is not applied (content below it reports intersecting).
- SVG geometry (V3b plan, Task 4; `html.webidl`): `SVGGraphicsElement.getBBox` (its options are not read: the fill
  geometry, untransformed), `SVGGeometryElement.getTotalLength`/`getPointAtLength` and
  `SVGTextContentElement.getNumberOfChars`/`getComputedTextLength`, with `double` where SVG 2 has `float`; no
  `pathLength`, `isPointInFill`/`isPointInStroke`, `getCTM`/`getScreenCTM` or the other text members. What the SVG
  painter does not draw (display none by CSS or attribute, under a hidden ancestor inside the `<svg>`, `defs` and the
  other never-drawn elements) has no geometry: zero rects and `getBBox`, as Chrome; SVG 2 leaves it open. Known gap:
  `getBBox` still answers for a shape whose `<svg>` itself is hidden or that has no `<svg>` (Chrome gives zeros); its
  client rects are already zero there. `DOMPointReadOnly`
  and `DOMPoint` (`cssom-view.webidl`) have no constructors, `fromPoint`, `matrixTransform` or setters.
- `getComputedStyle` (V3 plan, Task 4; `cssom.webidl`) takes `optional DOMString? pseudoElt` (`CSSOMString?` in the
  source) and returns a read-only `CSSStyleDeclaration`: the same interface as `element.style`, its values computed
  for the element (or its `::before`/`::after`) after a layout query's flush, every write throwing
  `NoModificationAllowedError`, its `cssText` "". It lists and answers the properties `Render/ComputedStyle.cpp` models;
  any other reads "", and so does every property of an element that is not rendered.
- `canvas.webidl` (V5d plan, Task 3) is the canvas section of `third-party/wpt/interfaces/html.idl` (HTMLCanvasElement,
  CanvasRenderingContext2D and every mixin it includes, CanvasGradient, CanvasPattern, TextMetrics, Path2D, ImageData,
  their enums) and geometry-1's DOMMatrix2DInit, with these changes:
  - The generator takes no overloads: `fill`, `clip` (`optional any` ×2), `stroke` (`optional any`), `isPointInPath`
    (`any, any, any...`), `isPointInStroke`, `setTransform` (`any...`), `drawImage` (`any image, any, any, any...`),
    `createImageData`, `putImageData`, `drawFocusIfNeeded` and the `ImageData` constructor take `any` arguments and
    are resolved natively by HTML's rules (a Path2D first argument, the argument count), so their `length` is the
    shortest overload's and a wrong count is a TypeError. `setTransform(1, 2, undefined, …)` counts its `undefined`s.
  - No unions are returned and no sequence is taken: `fillStyle`/`strokeStyle` are `attribute any` (a serialized
    colour, or the gradient or pattern object; anything else set is ignored), `getContext`, `createPattern` and
    `ImageData.data` are `any`, `getContextAttributes` returns `object`, `setLineDash`, `roundRect`'s radii and the
    DOMMatrix constructor take `any` converted natively (`setLineDash` reads at most 65 entries, and ignores a longer
    list, a deviation that bounds the read).
  - `CanvasImageSource` is `any`, checked natively: an HTMLCanvasElement (an HTMLImageElement from Task 5).
  - `[HTMLConstructor]` is left out; `toBlob`'s callback is `any` (a TypeError unless callable) and is called with null
    from a queued task; `transferControlToOffscreen` returns `undefined` (it always throws NotSupportedError).
  - `[EnforceRange] long` converts as `long` in `getImageData` (the generator has no EnforceRange); the natively
    resolved `createImageData` and `putImageData` enforce the range.
  - DOMMatrix is geometry-1's attributes on a single interface (no DOMMatrixReadOnly, no methods, no string init);
    `DOMPointInit` is read natively for `roundRect`.
  - Profile 1's out members are present and inert: `createConicGradient` and `createPattern` paint nothing,
    `globalCompositeOperation`, the shadow attributes, `filter`, `letterSpacing`, `wordSpacing`, `fontKerning`,
    `fontStretch`, `fontVariantCaps` and `textRendering` read back what was set, `getImageData` returns transparent
    pixels and `putImageData` draws nothing; there is no `OffscreenCanvas`.
- `web-animations.webidl` (V5e plan, Tasks 2–6) is `third-party/wpt/interfaces/web-animations.idl` (Level 1) with
  Level 2's `startTime`/`currentTime` (Animation), `currentTime` (AnimationTimeline), `delay`, `endDelay` and
  `duration` (EffectTiming), `iterationComposite` (KeyframeEffect and its options) and the time members of
  `ComputedEffectTiming` and `AnimationPlaybackEvent` from `web-animations-2.idl`, with these changes:
  - `CSSNumberish` is `double` and `CSSOMString` is `DOMString`; Level 2's group and sequence effects, triggers, ranges,
    `overallProgress`, `AnimationTimeline.play()` and `EffectTiming.playbackRate` are left out.
  - The partial dictionaries are written merged (`EffectTiming` and `OptionalEffectTiming` with Level 2's members,
    `KeyframeEffectOptions` with `iterationComposite`).
  - No dictionary is returned: `getTiming()` and `getComputedTiming()` return `object`, built natively with the
    dictionary's members as own data properties (`getComputedTiming()` has `activeDuration`, `currentIteration`,
    `endTime`, `localTime` and `progress`, not Level 2's `startTime`); `getKeyframes()` returns `sequence<object>`.
  - The generator takes no overloads: `KeyframeEffect`'s two constructors are one, `constructor(any target, optional
    any keyframes, optional (unrestricted double or KeyframeEffectOptions) options = {})`, resolved natively: a
    `KeyframeEffect` first argument with no keyframes is the copy form; otherwise the target converts as `Element?` and
    the keyframes as `object?` (`length` is 1, the copy form's).
  - `AnimationEffect` has no constructor (Level 1); `KeyframeEffect.pseudoElement` keeps a valid pseudo-element
    selector (a SyntaxError otherwise) and renders nothing.
  - No Promise type: `Animation.ready` and `finished` are `readonly attribute any` holding the promise objects
    (resolved synchronously where Level 1 resolves them, rejected in a queued job; `Sources/Support/Promises.h`).
  - `Animation`'s constructor takes `optional any timeline`, converted natively: the generator passes an absent nullable
    argument and `null` alike, and Level 1 gives the first `document.timeline` and the second no timeline.
  - `AnimationTimeline` has no constructor (Level 1); its `duration` (Level 2) is always null.
  - `GetAnimationsOptions.pseudoElement` is accepted and ignored (no pseudo-element is animated).
  - `partial interface mixin DocumentOrShadowRoot`'s `getAnimations()` is on `partial interface Document` (no shadow
    roots), and every document of the runtime shares the one `document.timeline`.
- `css-animations.webidl` (V5f plan, Task 3) is `third-party/wpt/interfaces/css-animations.idl` and `css-transitions.idl`
  (Level 1: `AnimationEvent`, `TransitionEvent`, their init dictionaries and the eight `GlobalEventHandlers` handlers)
  with `CSSAnimation` and `CSSTransition` from `css-animations-2.idl` and `css-transitions-2.idl`, with these changes:
  - `CSSOMString` is `DOMString`.
  - Left out: `CSSKeyframesRule`, `CSSKeyframeRule`, `CSSRule`'s keyframe constants and `CSSStartingStyleRule` (no
    CSSOM rule objects in the runtime; `@keyframes` are read from the sheets' text), and Level 2's `animation` member of
    the two events and their init dictionaries.
- `HTMLImageElement` (V5d plan, Task 5; `html.webidl`) keeps what a canvas source needs: `alt`, `src` (`[Reflect]
  DOMString`, as every URL member until the URL parser reaches reflection), `width`/`height` (native: the attribute when
  it parses, else the natural size, since the rendered size needs layout), `naturalWidth`/`naturalHeight`, `complete`
  and `currentSrc`. `Image(width, height)` (the LegacyFactoryFunction, which the generator has no support for) is a
  hand-built lazy global (`installImageConstructor`) whose `prototype` is HTMLImageElement's. Left out:
  `[HTMLConstructor]`, `srcset`, `sizes`, `crossOrigin`, `useMap`, `isMap`, `referrerPolicy`, `decoding`,
  `loading`, `fetchPriority`, `decode()` and the obsolete members. Only `data:` images decode (the container's
  decision, made at once), so `complete` is always true; `load`/`error` fire from a task when `src` changes and, for
  parsed images, before the window's load. Known gap: an image a fragment parse (`innerHTML`) makes with a `src` gets
  no event.
