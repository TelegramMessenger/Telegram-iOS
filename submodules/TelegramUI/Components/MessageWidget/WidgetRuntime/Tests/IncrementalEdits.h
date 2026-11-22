// The randomized oracles' page and edits (RenderStructurePatchTests' testRandomEditsMatchARebuild, LayerMirrorTests'
// testOpsMatchAFreshMirror): one page of the shapes the render paths care about, and `__edit(kind, a, b, c)`, installed by
// kEditHelpersJS, which makes one edit of `kind` and names it.
#pragma once

#include <cstdint>
#include <string>

#include "Sources/Render/RenderHost.h"

namespace wr_test {

/// The page: `sheet` in a <style>, `prefix` first in the body, then lists, a table with a caption, a <pre>, form controls,
/// an <svg>, a <template> and a tail, then `filler`. Elements with id `filler`, `filler2` or `inputs` are left alone by
/// the edits.
std::string editPage(const std::string& sheet, const std::string& filler, const std::string& prefix = std::string());

/// Installs `globalThis.__edit(kind, a, b, c)` and evaluates to 'ok'. Kinds: 0 append, 1 insertBefore (each naming what
/// it inserted: its local name, or #text), 2 remove, 3 move,
/// 4 textContent, 5 innerHTML, 6 class, 7 style, 8 hidden, 9 a Text's data, 10 an append into the <template>'s content,
/// 11 (and any other) a node moved out of it, 12 a table part inserted into a table, 20 textContent on an element whose
/// only child is a Text (a swap), 21 an attribute set or removed (SVG geometry on SVG elements; data-k, value, href,
/// dir, lang, id and title on others), 22 a style that changes the box (position, float, display, border width,
/// white-space, font-size, z-index), 23 the text of `<style id=s2>` (an attribute rule, a `::before` content rule, a
/// media query, an inline list, a `:hover` rule) or that element removed or inserted, 24 `class`, `style` or `dir` on
/// the document element or the body, 25 the class `pc` toggled, 26 a style with custom properties and var(), 27 a
/// <circle> or a <g> inserted into an <svg> or a <g>, or one of their children removed, 28 the document's own children,
/// 29 the document's own head and body (removed, put back, `document.body` set, a body inserted before the body, a
/// `body` element appended under a div), 30 an attribute on a `<br>` (inserted first when there is none), 31 one batch
/// of 5,000 changes, each its own journal entry (spans appended one by one to `#mass`, then their class set, then
/// removed one by one). `a`, `b` and `c` pick the nodes and values.
extern const char* const kEditHelpersJS;
/// The shapes kEditHelpersJS's make() switches over: an insertion whose `b` is 13 modulo it inserts a table of refused
/// rows.
constexpr uint32_t kEditShapes = 17;

/// What an environment step changes the rendering of: a `:hover` rule, and a rule under each media feature the host
/// answers from its options (prefers-color-scheme from the theme, prefers-reduced-motion).
extern const char* const kEnvironmentSheet;
/// The root declarations the host passes for `theme` with the default palette and tokens (HostState::applyTheme).
std::string themeDeclarations(wr::Theme theme);

} // namespace wr_test
