// CSSOM (https://drafts.csswg.org/cssom/), from third-party/wpt/interfaces/cssom.idl: the inline style declaration
// block (`element.style`) only. README.md lists the changes; cssom-properties.webidl holds the property attributes.

[Exposed=Window]
interface CSSStyleDeclaration {
  [CEReactions] attribute [LegacyNullToEmptyString] DOMString cssText;
  readonly attribute unsigned long length;
  getter DOMString item(unsigned long index);
  DOMString getPropertyValue(DOMString property);
  DOMString getPropertyPriority(DOMString property);
  [CEReactions] undefined setProperty(DOMString property, [LegacyNullToEmptyString] DOMString value, optional [LegacyNullToEmptyString] DOMString priority = "");
  [CEReactions] DOMString removeProperty(DOMString property);
  [CEReactions] attribute [LegacyNullToEmptyString] DOMString cssFloat;
};

interface mixin ElementCSSInlineStyle {
  [SameObject, PutForwards=cssText] readonly attribute CSSStyleDeclaration style;
};

HTMLElement includes ElementCSSInlineStyle;
SVGElement includes ElementCSSInlineStyle;

// CSSOM's getComputedStyle (V3 plan, Task 4): `pseudoElt` is `CSSOMString?` in the source (README.md).
partial interface Window {
  [NewObject] CSSStyleDeclaration getComputedStyle(Element elt, optional DOMString? pseudoElt);
};
