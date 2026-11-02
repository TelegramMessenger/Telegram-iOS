// Web Animations (V5e plan, Tasks 2–4): WPT's interfaces/web-animations.idl (Level 1) with Level 2's time members and
// iterationComposite (web-animations-2.idl), for profile 1's anim.waapi. CSSNumberish is double and CSSOMString is
// DOMString here; the generator has no Promise, no dictionary returns, no sequence arguments and no overloads, so
// README.md lists every change.

enum FillMode { "none", "forwards", "backwards", "both", "auto" };
enum PlaybackDirection { "normal", "reverse", "alternate", "alternate-reverse" };
enum CompositeOperation { "replace", "add", "accumulate" };
enum CompositeOperationOrAuto { "replace", "add", "accumulate", "auto" };
enum IterationCompositeOperation { "replace", "accumulate" };

dictionary EffectTiming {
  double delay = 0;
  double endDelay = 0;
  FillMode fill = "auto";
  double iterationStart = 0.0;
  unrestricted double iterations = 1.0;
  (unrestricted double or DOMString) duration = "auto";
  PlaybackDirection direction = "normal";
  DOMString easing = "linear";
};

dictionary OptionalEffectTiming {
  double delay;
  double endDelay;
  FillMode fill;
  double iterationStart;
  unrestricted double iterations;
  (unrestricted double or DOMString) duration;
  PlaybackDirection direction;
  DOMString easing;
};

dictionary KeyframeEffectOptions : EffectTiming {
  CompositeOperation composite = "replace";
  IterationCompositeOperation iterationComposite = "replace";
  DOMString? pseudoElement = null;
};

[Exposed=Window]
interface AnimationEffect {
  object getTiming();
  object getComputedTiming();
  undefined updateTiming(optional OptionalEffectTiming timing = {});
};

[Exposed=Window]
interface KeyframeEffect : AnimationEffect {
  constructor(any target, optional any keyframes, optional (unrestricted double or KeyframeEffectOptions) options = {});
  attribute Element? target;
  attribute DOMString? pseudoElement;
  attribute CompositeOperation composite;
  attribute IterationCompositeOperation iterationComposite;
  sequence<object> getKeyframes();
  undefined setKeyframes(object? keyframes);
};

[Exposed=Window]
interface AnimationTimeline {
  readonly attribute double? currentTime;
  readonly attribute double? duration;
};

dictionary DocumentTimelineOptions {
  DOMHighResTimeStamp originTime = 0;
};

[Exposed=Window]
interface DocumentTimeline : AnimationTimeline {
  constructor(optional DocumentTimelineOptions options = {});
};

enum AnimationPlayState { "idle", "running", "paused", "finished" };
enum AnimationReplaceState { "active", "removed", "persisted" };

[Exposed=Window]
interface Animation : EventTarget {
  constructor(optional AnimationEffect? effect = null, optional any timeline);
  attribute DOMString id;
  attribute AnimationEffect? effect;
  attribute AnimationTimeline? timeline;
  attribute double? startTime;
  attribute double? currentTime;
  attribute double playbackRate;
  readonly attribute AnimationPlayState playState;
  readonly attribute AnimationReplaceState replaceState;
  readonly attribute boolean pending;
  readonly attribute any ready;
  readonly attribute any finished;
  attribute EventHandler onfinish;
  attribute EventHandler oncancel;
  attribute EventHandler onremove;
  undefined cancel();
  undefined finish();
  undefined play();
  undefined pause();
  undefined updatePlaybackRate(double playbackRate);
  undefined reverse();
  undefined persist();
  [CEReactions] undefined commitStyles();
};

dictionary AnimationPlaybackEventInit : EventInit {
  double? currentTime = null;
  double? timelineTime = null;
};

[Exposed=Window]
interface AnimationPlaybackEvent : Event {
  constructor(DOMString type, optional AnimationPlaybackEventInit eventInitDict = {});
  readonly attribute double? currentTime;
  readonly attribute double? timelineTime;
};

dictionary KeyframeAnimationOptions : KeyframeEffectOptions {
  DOMString id = "";
  AnimationTimeline? timeline;
};

dictionary GetAnimationsOptions {
  boolean subtree = false;
  DOMString? pseudoElement = null;
};

interface mixin Animatable {
  Animation animate(object? keyframes, optional (unrestricted double or KeyframeAnimationOptions) options = {});
  sequence<Animation> getAnimations(optional GetAnimationsOptions options = {});
};
Element includes Animatable;

partial interface Document {
  readonly attribute DocumentTimeline timeline;
  sequence<Animation> getAnimations();
};
