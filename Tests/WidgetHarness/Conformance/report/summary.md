# Conformance results

Generated 2026-10-21 18:54 UTC by `packages/conformance/tools/report.mjs` (profile 1; ios telegram-native — iOS 26.5, iPhone18,3 simulator @ d895dcb5; policy strict, features webAnimations).

Verdict per catalogue ID over the automatic set: ✅ pass, ◐ partly, ❌ fail, ⏳ expected to fail (not implemented yet: D23, the profile in the validator, …), ❗ passes although expected to fail, – not applicable here, · not tested. For **out** features "pass" means *neutralised as the profile says*. The native columns are a plain browser engine without the pipeline: a reference for the tests, not an expectation.

## Totals

| Renderer | in (173) ✅ / ◐ / ❌ / ⏳ | out (82) neutralised ✅ / not yet ⏳ / ❌ | auto runs loaded | errors |
|---|---|---|---|---|
| ios telegram-native | 127 / 27 / 8 / 0 | 74 / 1 / 1 | 40 / 40 | 0 |

## In the profile

| ID | ios telegram-native | native chromium |
|---|---|---|
| `html.el.structure` | ◐ | ✅ |
| `html.el.headings` | ✅ | ✅ |
| `html.el.sections` | ✅ | ✅ |
| `html.el.inline-text` | ◐ | ✅ |
| `html.el.sub-sup` | ✅ | ✅ |
| `html.el.pre` | ✅ | ✅ |
| `html.el.blockquote` | ✅ | ✅ |
| `html.el.lists` | ✅ | ✅ |
| `html.el.table` | ✅ | ✅ |
| `html.el.img` | ✅ | ✅ |
| `html.el.canvas` | ✅ | · |
| `html.el.button` | ✅ | ✅ |
| `html.el.details` | ◐ | ✅ |
| `html.el.a-fragment` | ◐ | ✅ |
| `html.el.a-external` | ◐ | ✅ |
| `html.el.unknown` | ✅ | ✅ |
| `html.attr.global` | ◐ | ✅ |
| `html.attr.dir` | ❌ | ✅ |
| `html.attr.data-aria` | ✅ | ✅ |
| `html.attr.event-handlers` | ✅ | ✅ |
| `svg.shapes` | ✅ | ✅ |
| `svg.structure` | ◐ | ✅ |
| `svg.text` | ◐ | ✅ |
| `svg.gradients` | ✅ | · |
| `svg.css` | ◐ | ✅ |
| `css.display.basic` | ✅ | ✅ |
| `css.display.flex` | ✅ | ✅ |
| `css.gap.flex` | ✅ | ✅ |
| `css.display.grid` | ✅ | ✅ |
| `css.display.table` | ❌ | ✅ |
| `css.box.size` | ◐ | ✅ |
| `css.box.spacing` | ✅ | ✅ |
| `css.box.border` | ◐ | ✅ |
| `css.box.radius` | ✅ | · |
| `css.box.sizing` | ✅ | ✅ |
| `css.box.aspect-ratio` | ✅ | ✅ |
| `css.box.outline` | ◐ | ✅ |
| `css.box.shadow` | ✅ | · |
| `css.box.float` | ✅ | ✅ |
| `css.box.object-fit` | ❌ | · |
| `css.position.relative-absolute` | ✅ | ✅ |
| `css.position.fixed` | ✅ | ✅ |
| `css.position.z-index` | ✅ | ✅ |
| `css.overflow.clip` | ✅ | ✅ |
| `css.visibility` | ✅ | ✅ |
| `css.opacity` | ✅ | ✅ |
| `css.color.basic` | ◐ | ✅ |
| `css.color.light-dark` | ✅ | ✅ |
| `css.background.basic` | ❌ | ✅ |
| `css.gradient.linear` | ✅ | · |
| `css.gradient.radial` | ✅ | · |
| `css.gradient.conic` | ❌ | · |
| `css.font.generic` | ✅ | ✅ |
| `css.font.ui-families` | ✅ | ✅ |
| `css.font.basic` | ✅ | ✅ |
| `css.font.variant-numeric` | ◐ | ✅ |
| `css.text.align` | ◐ | ✅ |
| `css.text.decoration` | ✅ | ✅ |
| `css.text.transform` | ◐ | ✅ |
| `css.text.white-space` | ✅ | ✅ |
| `css.text.wrap` | ◐ | ✅ |
| `css.text.overflow` | ❌ | · |
| `css.text.vertical-align` | ✅ | ✅ |
| `css.text.list-style` | ✅ | ✅ |
| `css.text.rtl` | ◐ | ✅ |
| `css.text.emoji` | ✅ | ✅ |
| `css.transform.2d` | ❌ | ✅ |
| `css.filter.blur-brightness-drop-shadow` * | ◐ | ✅ |
| `css.backdrop-filter` * | ✅ | · |
| `css.pointer-events` | ✅ | ✅ |
| `css.touch-action` | ❌ | ✅ |
| `css.cursor` | ✅ | ✅ |
| `css.value.units` | ✅ | ✅ |
| `css.value.vw` | ✅ | ✅ |
| `css.value.math` | ◐ | ✅ |
| `css.value.custom-properties` | ✅ | ✅ |
| `css.value.keywords` | ◐ | ✅ |
| `css.value.content` | ◐ | ✅ |
| `sel.basic` | ✅ | ✅ |
| `sel.structural` | ◐ | ✅ |
| `sel.is-where` | ✅ | ✅ |
| `sel.root` | ✅ | ✅ |
| `sel.before-after` | ✅ | ✅ |
| `sel.hover` | ✅ | ✅ |
| `sel.active` | ✅ | ✅ |
| `at.media.width` | ✅ | ✅ |
| `at.media.color-scheme` | ✅ | ✅ |
| `at.media.reduced-motion` | ✅ | ✅ |
| `at.supports` | ✅ | ✅ |
| `at.keyframes` | ✅ | · |
| `anim.transition` | ✅ | ✅ |
| `anim.keyframes` | ✅ | ✅ |
| `anim.play-state` | ✅ | ✅ |
| `anim.easing` | ✅ | ✅ |
| `anim.events` | ✅ | ✅ |
| `anim.waapi` * | ✅ | ✅ |
| `anim.waapi-css-control` * | ✅ | ✅ |
| `canvas.rect` | ✅ | · |
| `canvas.path` | ✅ | · |
| `canvas.line-style` | ✅ | · |
| `canvas.colors` | ✅ | · |
| `canvas.gradients` | ✅ | · |
| `canvas.transform` | ✅ | · |
| `canvas.clip` | ✅ | · |
| `canvas.text` | ✅ | ✅ |
| `canvas.alpha` | ✅ | · |
| `canvas.path2d` | ✅ | · |
| `canvas.draw-image` | ✅ | ✅ |
| `canvas.hit-test` | ✅ | ✅ |
| `canvas.hidpi` | ✅ | ✅ |
| `js.dom.core` | ✅ | ✅ |
| `js.dom.query` | ✅ | ✅ |
| `js.dom.style` | ✅ | ✅ |
| `js.dom.events` | ✅ | ✅ |
| `js.layout.rect` | ✅ | ✅ |
| `js.layout.box` | ✅ | ✅ |
| `js.layout.computed-style` | ✅ | ✅ |
| `js.layout.match-media` | ✅ | ✅ |
| `js.layout.resize-observer` | ✅ | ✅ |
| `js.layout.intersection-observer` | ✅ | ✅ |
| `js.layout.element-from-point` | ✅ | ✅ |
| `js.layout.measure-text` | ✅ | ✅ |
| `js.timers` | ✅ | ✅ |
| `js.raf` | ✅ | ✅ |
| `js.microtasks` | ✅ | ✅ |
| `js.storage.local` | ✅ | ✅ |
| `js.storage.session` | ✅ | ✅ |
| `js.intl` | ✅ | ✅ |
| `js.intl.format-to-parts` | ✅ | ✅ |
| `js.locale` | ✅ | ✅ |
| `js.crypto-random` | ✅ | ✅ |
| `js.builtins` | ✅ | ✅ |
| `js.eval` | ✅ | ✅ |
| `js.css-supports` | ✅ | ✅ |
| `js.visibility` | ✅ | ✅ |
| `tw.ready` | ✅ | – |
| `tw.theme` | ✅ | – |
| `tw.theme-params` | ✅ | – |
| `tw.events` | ✅ | – |
| `tw.is-active` | ✅ | – |
| `tw.open-link` | ✅ | – |
| `tw.open-telegram-link` | ✅ | – |
| `tw.haptic` | ✅ | – |
| `tw.profile` | ✅ | – |
| `input.tap` | ✅ | ✅ |
| `input.pointer` | ✅ | ✅ |
| `input.mouse-compat` | ✅ | ✅ |
| `input.drag` | ◐ | ✅ |
| `input.hover-events` | – | ✅ |
| `input.user-activation` | ✅ | · |
| `input.prevent-default` | ✅ | ✅ |
| `limit.text-node` | ◐ | ✅ |
| `limit.text-budget` | ◐ | ✅ |
| `limit.nodes` | · | · |
| `limit.timers` | ✅ | – |
| `limit.cpu` | · | · |
| `limit.memory` | · | · |
| `limit.storage` | ✅ | – |
| `limit.url-length` | ✅ | – |
| `limit.event-handlers` | ✅ | – |
| `limit.haptic-rate` | ✅ | · |
| `limit.html-size` | · | · |
| `behaviour.theme-switch` | ✅ | – |
| `behaviour.offscreen-pause` | ✅ | – |
| `behaviour.auto-height` | ✅ | · |
| `behaviour.no-selection` | ✅ | · |
| `behaviour.restart` | · | · |
| `behaviour.gesture-claim` | · | · |
| `behaviour.storage-persist` | · | · |
| `behaviour.storage-forward` | · | · |
| `behaviour.message-edit` | · | · |
| `behaviour.size-hint` | · | · |
| `behaviour.policy-strict` | ◐ | ✅ |

## Out of the profile (pass = neutralised)

| ID | ios telegram-native | native chromium |
|---|---|---|
| `html.el.ruby` | ✅ | ❌ |
| `html.el.legacy` | ✅ | ❌ |
| `html.el.img-svg` | ✅ | ❌ |
| `html.el.img-other-formats` | ✅ | ❌ |
| `html.el.img-remote` | ✅ | – |
| `html.el.forms` | ✅ | ❌ |
| `html.el.progress-meter` | ✅ | ❌ |
| `html.el.dialog-popover` | ✅ | ❌ |
| `html.el.media` | ✅ | ❌ |
| `html.el.embedding` | ✅ | ❌ |
| `html.attr.legacy-presentational` | ✅ | ❌ |
| `html.attr.contenteditable` | ✅ | ❌ |
| `html.attr.draggable` | ✅ | ❌ |
| `html.attr.tabindex` | ✅ | ❌ |
| `svg.clip-mask` | ✅ | · |
| `svg.filters` | ✅ | · |
| `svg.smil` | ✅ | · |
| `svg.foreign-object` | ✅ | · |
| `svg.image` | ✅ | · |
| `css.display.other` | ✅ | ❌ |
| `css.box.logical` | ◐ | ❌ |
| `css.box.columns` | ✅ | ❌ |
| `css.position.sticky` | ✅ | ❌ |
| `css.overflow.scroll` | ✅ | ❌ |
| `css.color.modern` | ✅ | · |
| `css.color.mix` | ✅ | ❌ |
| `css.background.clip-text` | ✅ | · |
| `css.url.remote` | ✅ | – |
| `css.font.named` | ✅ | ❌ |
| `css.font.face` | ✅ | ✅ |
| `css.text.line-clamp` | ✅ | ❌ |
| `css.text.shadow` | ✅ | · |
| `css.text.writing-mode` | ✅ | ❌ |
| `css.text.selection` | ❌ | ✅ |
| `css.transform.3d` | ✅ | ❌ |
| `css.filter.other` | ✅ | · |
| `css.filter.url` | ✅ | · |
| `css.blend` | ✅ | · |
| `css.clip-path` | ✅ | · |
| `css.mask` | ✅ | · |
| `css.value.vh` | ✅ | ❌ |
| `css.value.env` | ✅ | ❌ |
| `sel.has` | ✅ | ❌ |
| `sel.first-letter-line` | ✅ | ❌ |
| `sel.focus` | ✅ | ❌ |
| `sel.form-state` | ✅ | ❌ |
| `sel.host-scoped` | ✅ | ❌ |
| `sel.target` | ✅ | ✅ |
| `at.media.hover-pointer` | ✅ | ❌ |
| `at.media.other` | ✅ | ✅ |
| `at.import-namespace` | ✅ | ❌ |
| `at.container` | ✅ | ◐ |
| `at.layer` | ✅ | ❌ |
| `at.property` | ✅ | ❌ |
| `at.exotic` | ✅ | ❌ |
| `at.nesting` | ✅ | ◐ |
| `anim.magic-move` | ✅ | – |
| `canvas.conic-gradient` | ✅ | · |
| `canvas.pattern` | ✅ | · |
| `canvas.composite` | ✅ | · |
| `canvas.shadow` | ✅ | · |
| `canvas.filter` | ✅ | · |
| `canvas.image-data` | ✅ | ❌ |
| `canvas.readback` | ✅ | ❌ |
| `canvas.webgl` | ✅ | – |
| `js.focus` | ✅ | ❌ |
| `js.libraries` | ✅ | – |
| `js.network` | ✅ | – |
| `js.navigation` | ✅ | – |
| `js.dialogs` | ✅ | – |
| `js.device` | ✅ | – |
| `js.shadow-dom` | ✅ | – |
| `js.blob-file` | ✅ | – |
| `js.fullscreen` | ✅ | – |
| `tw.send-message` | ✅ | – |
| `input.touch-events` | – | – |
| `input.dblclick` | – | ❌ |
| `input.long-press` | – | ❌ |
| `input.keyboard` | – | ❌ |
| `input.key-activation` | – | ❌ |
| `input.key-gesture` | ✅ | · |
| `input.wheel-scroll` | – | ❌ |

`*` in the profile if every client draws it (D3a).

## ios telegram-native: in-profile failures

- `html.el.structure`: 01-html-elements-a: p has 1em block margins (got 0, want 13 ±0.5)
- `html.el.inline-text`: 01-html-elements-a: q adds quotation marks (14.4599609375 vs 14.4599609375)
- `html.el.details`: 01-html-elements-c: summary is a list item (disclosure marker) (got "block", want "list-item")
- `html.el.a-fragment`: 01-html-elements-c: a[href=#…] is a link (UA link colour, underline) (17,17,17,1)
- `html.el.a-external`: 01-html-elements-c: it is still drawn as a link (none)
- `html.attr.global`: 02-attributes-images-a: lang reaches the renderer (:lang(ru)) (got "17,17,17,1", want "0,100,0,1")
- `html.attr.dir`: 02-attributes-images-a: dir=rtl sets direction (got "ltr", want "rtl"); 02-attributes-images-a: dir=rtl lays out inline boxes right to left (a 8 b 18); 02-attributes-images-a: dir=auto with Hebrew text resolves to rtl (got "ltr", want "rtl")
- `svg.structure`: 13-svg-a: structure (diff 60.0 % of ink (max 5 %))
- `svg.text`: 13-svg-a: text (diff 21.6 % of ink (max 50 %); #222 949/696px, #c33 0/235px, #36c 222/204px)
- `svg.css`: 13-svg-a: a stylesheet fill reaches SVG (computed fill)
- `css.display.table`: 03-layout-c: table cells side by side, the second takes the rest (0/200 200/0)
- `css.box.size`: 03-layout-b: width: fit-content shrinks to the text (w 200)
- `css.box.border`: 03-layout-b: border (diff 37.8 % of ink (max 5 %))
- `css.box.outline`: 05-colour-backgrounds-b: outline (diff 14.1 % of ink (max 5 %))
- `css.box.object-fit`: 05-colour-backgrounds-b: object-fit (diff 28.3 % of ink (max 5 %))
- `css.color.basic`: 05-colour-backgrounds-a: named colour (got "0,0,0,0", want "102,51,153,1"); 05-colour-backgrounds-a: basic (diff 25.0 % of ink (max 5 %))
- `css.background.basic`: 05-colour-backgrounds-b: background-image keeps the data: image; 05-colour-backgrounds-b: background-size (got "", want "10px 12px"); 05-colour-backgrounds-b: background-position (got "", want "1px 2px"); 05-colour-backgrounds-b: background-repeat (got "", want "no-repeat")
- `css.gradient.conic`: 05-colour-backgrounds-b: conic (diff 11.9 % of ink (max 5 %))
- `css.font.variant-numeric`: 06-text-fonts-a: font-feature-settings "tnum" (got 23.82, want 32.45 ±0.5)
- `css.text.align`: 06-text-fonts-b: text-align: end in RTL is the left edge (got 114, want 0 ±1)
- `css.text.transform`: 06-text-fonts-b: word-spacing: 10px adds 10px per space (got 0, want 20 ±1.5)
- `css.text.wrap`: 06-text-fonts-b: word-break: break-all breaks a long word (16)
- `css.text.overflow`: 06-text-fonts-c: ellipsis (diff 13.7 % of ink (max 50 %); #36c 11/70px)
- `css.text.rtl`: 06-text-fonts-c: Hebrew in dir=rtl starts at the right edge (got 73.9, want 128 ±1)
- `css.transform.2d`: 09-transforms-effects-a: translateX(30px) moves the box (got 0, want 30 ±0.5); 09-transforms-effects-a: rotate(90deg) swaps the bounding box (40x20); 09-transforms-effects-a: scale(2) with transform-origin 0 0 (110 10); 09-transforms-effects-a: the translate property (150,0)
- `css.filter.blur-brightness-drop-shadow`: 09-transforms-effects-a: filter functions are kept
- `css.touch-action`: 09-transforms-effects-b: touch-action reaches the renderer (got "auto", want "none")
- `css.value.math`: 04-values-units: calc(50% - 10px) (got 200, want 90 ±0.5); 04-values-units: min(50px, 30%) (got 200, want 50 ±0.5); 04-values-units: max(10px, 20%) (got 200, want 40 ±0.5); 04-values-units: clamp(20px, 50%, 60px) (got 200, want 60 ±0.5)
- `css.value.keywords`: 04-values-units: display: initial is inline (got "block", want "inline"); 04-values-units: color: unset inherits (got "200,0,0,1", want "0,0,140,1"); 04-values-units: display: revert is the UA block (got "inline", want "block")
- `css.value.content`: 04-values-units: quotes (auto)
- `sel.structural`: 07-selectors-b: :empty (got "29,0,0,1", want "28,0,0,1")
- `input.drag`: 17-drag-hover: movementX adds up to the distance (movementX 0 vs 160)
- `limit.text-node`: 19-limits: a text node over 64 KB is refused (16)
- `limit.text-budget`: 19-limits: past 8192 complex-script units in the document the text is refused (16)
- `behaviour.policy-strict`: 19-limits: a 300 KB data-* attribute does not reach the renderer (9,9,9,1)
