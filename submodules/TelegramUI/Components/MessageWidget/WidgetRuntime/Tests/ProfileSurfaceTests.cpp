// Profile 1's surface (2026-10-22): every API, canvas member and event the vendored profile.json marks as in exists in
// the runtime. The conformance set exercises a sample of them, and a check that guards a call (`window.x || 1`, a call
// inside try) passes without the API: four of the user's games stopped at devicePixelRatio and setPointerCapture, both
// in profile 1, both absent until then.
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

std::string profileJSON() {
    const char* path = std::getenv("WR_PROFILE_JSON");
    std::ifstream in(path ? path : "", std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

// Resolves each name the in-profile features list, as a widget would reach it, and answers the missing ones.
const char* const kResolve = R"JS(
(() => {
  const ins = profile.features.filter(f => f.status === 'in');
  const names = kind => [...new Set(ins.flatMap(f => (f.match && f.match[kind]) || []))].sort();
  const owners = [globalThis, Element.prototype, HTMLElement.prototype, Node.prototype, Document.prototype];
  const api = name => {
    if (name === 'formatToParts') {
      return 'formatToParts' in Intl.DateTimeFormat.prototype && 'formatToParts' in Intl.NumberFormat.prototype;
    }
    const [root, member] = name.split('.');
    if (member === undefined) {
      return owners.some(o => name in o);
    }
    const base = root === 'element' ? HTMLElement.prototype : globalThis[root];
    if (base == null) {
      return false;
    }
    return member in Object(base) || (typeof base === 'function' && base.prototype != null && member in base.prototype);
  };
  const canvas = name => name in CanvasRenderingContext2D.prototype || name in globalThis ||
    name in CanvasGradient.prototype;
  const event = type => ['on' + type].some(on => on in HTMLElement.prototype || on in Document.prototype || on in globalThis);
  return [...names('apis').filter(n => !api(n)), ...names('canvas').filter(n => !canvas(n)).map(n => 'canvas ' + n),
          ...names('events').filter(n => !event(n)).map(n => 'event ' + n)].join(', ');
})()
)JS";

} // namespace

WR_TEST(testEveryInProfileNameExists) {
    const std::string json = profileJSON();
    CHECK(!json.empty());
    RenderEnv env("<!doctype html><html><head></head><body><canvas></canvas></body></html>");
    CHECK_EQ(env.env().eval("globalThis.profile = (" + json + "); 1"), std::string("1"));
    const std::string missing = env.env().eval(kResolve);
    if (!missing.empty()) {
        std::printf("    missing: %s\n", missing.c_str());
    }
    CHECK_EQ(missing, std::string());
    // The resolver itself: names the runtime lacks are reported, each kind with its prefix.
    CHECK_EQ(env.env().eval("profile.features.push({status: 'in', match: {apis: ['noSuchGlobal', 'Element.noSuchMethod'], "
                            "canvas: ['noSuchCanvasMember'], events: ['nosuchevent']}}); 1"),
             std::string("1"));
    CHECK_EQ(env.env().eval(kResolve),
             std::string("Element.noSuchMethod, noSuchGlobal, canvas noSuchCanvasMember, event nosuchevent"));
}

namespace {

// Every CSS property the in-profile features list, the wildcard families expanded to their standard longhands and
// custom properties left out, with the ones getComputedStyle answers "" for on `#id`.
const char* const kEmptyComputed = R"JS(
((id) => {
  const ins = profile.features.filter(f => f.status === 'in');
  const sides = ['top', 'right', 'bottom', 'left'];
  const expand = {
    'animation-*': ['animation-name', 'animation-duration', 'animation-timing-function', 'animation-delay',
                    'animation-iteration-count', 'animation-direction', 'animation-fill-mode', 'animation-play-state'],
    'transition-*': ['transition-property', 'transition-duration', 'transition-timing-function', 'transition-delay',
                     'transition-behavior'],
    'border-*': ['border-width', 'border-style', 'border-color', ...sides.map(s => 'border-' + s),
                 ...sides.flatMap(s => ['width', 'style', 'color'].map(k => 'border-' + s + '-' + k))],
    'border-*-radius': ['border-top-left-radius', 'border-top-right-radius', 'border-bottom-right-radius',
                        'border-bottom-left-radius'],
    'margin-*': sides.map(s => 'margin-' + s),
    'padding-*': sides.map(s => 'padding-' + s),
    'outline-*': ['outline-color', 'outline-style', 'outline-width', 'outline-offset'],
    'text-decoration-*': ['text-decoration-line', 'text-decoration-style', 'text-decoration-color',
                          'text-decoration-thickness'],
  };
  const props = [...new Set(ins.flatMap(f => (f.match && f.match.properties) || [])
                   .flatMap(p => expand[p] || (p.startsWith('--') ? [] : [p])))];
  const cs = getComputedStyle(document.getElementById(id));
  return props.filter(p => cs.getPropertyValue(p) === '').sort().join(', ');
})
)JS";

} // namespace

/// Every in-profile CSS property answers a computed value (2026-10-22: about 100 of 169 answered ""), on an unstyled
/// element and on an absolutely positioned one.
WR_TEST(testEveryInProfilePropertyComputes) {
    const std::string json = profileJSON();
    CHECK(!json.empty());
    RenderEnv env("<!doctype html><html><head></head><body><div id=plain>x</div>"
                  "<div style='position:relative;width:200px;height:100px'><div id=placed "
                  "style='position:absolute'>y</div></div></body></html>");
    CHECK_EQ(env.env().eval("globalThis.profile = (" + json + "); 1"), std::string("1"));
    for (const char* id : {"plain", "placed"}) {
        const std::string empty = env.env().eval(std::string(kEmptyComputed) + "('" + id + "')");
        if (!empty.empty()) {
            std::printf("    %s answers nothing for: %s\n", id, empty.c_str());
        }
        CHECK_EQ(empty, std::string());
    }
}
