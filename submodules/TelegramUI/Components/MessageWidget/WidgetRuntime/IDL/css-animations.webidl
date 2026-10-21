// CSS animations and transitions (V5f plan, Task 3): the events and handlers of WPT's interfaces/css-animations.idl and
// css-transitions.idl (Level 1), and CSSAnimation and CSSTransition from css-animations-2.idl and css-transitions-2.idl,
// for profile 1's anim.* features. CSSOMString is DOMString here; the rule interfaces (CSSKeyframesRule,
// CSSKeyframeRule, CSSStartingStyleRule) and Level 2's `animation` member of the events are left out (README.md).

[Exposed=Window]
interface AnimationEvent : Event {
  constructor(DOMString type, optional AnimationEventInit animationEventInitDict = {});
  readonly attribute DOMString animationName;
  readonly attribute double elapsedTime;
  readonly attribute DOMString pseudoElement;
};

dictionary AnimationEventInit : EventInit {
  DOMString animationName = "";
  double elapsedTime = 0.0;
  DOMString pseudoElement = "";
};

[Exposed=Window]
interface TransitionEvent : Event {
  constructor(DOMString type, optional TransitionEventInit transitionEventInitDict = {});
  readonly attribute DOMString propertyName;
  readonly attribute double elapsedTime;
  readonly attribute DOMString pseudoElement;
};

dictionary TransitionEventInit : EventInit {
  DOMString propertyName = "";
  double elapsedTime = 0.0;
  DOMString pseudoElement = "";
};

[Exposed=Window]
interface CSSAnimation : Animation {
  readonly attribute DOMString animationName;
};

[Exposed=Window]
interface CSSTransition : Animation {
  readonly attribute DOMString transitionProperty;
};

partial interface mixin GlobalEventHandlers {
  attribute EventHandler onanimationstart;
  attribute EventHandler onanimationiteration;
  attribute EventHandler onanimationend;
  attribute EventHandler onanimationcancel;
};

partial interface mixin GlobalEventHandlers {
  attribute EventHandler ontransitionrun;
  attribute EventHandler ontransitionstart;
  attribute EventHandler ontransitionend;
  attribute EventHandler ontransitioncancel;
};
