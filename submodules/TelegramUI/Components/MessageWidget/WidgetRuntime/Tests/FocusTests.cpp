// Profile 1 has no focus (V4 plan, Task 8; RB §8.1): a tap moves no focus, focus() and blur() do nothing and fire
// nothing, :focus and :focus-within never match, and document.activeElement is always the body. :hover and :active
// still match and render.
#include <cstdio>
#include <string>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::RenderEnv;

namespace {

const char* const kTwo =
    "<!doctype html><html><head><style>body{margin:0;padding:0} #b,#d{position:absolute;top:10px;width:80px;"
    "height:30px;display:block} #b{left:10px} #d{left:100px}</style></head><body><div id=w><button id=b>b</button>"
    "</div><div id=d>d</div><script>window.log = []; for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "for (const k of ['focus','blur','focusin','focusout']) for (const id of ['b','d','w'])"
    "  document.getElementById(id).addEventListener(k, e => log.push(k + ':' + id + ':' +"
    "    (e.relatedTarget ? e.relatedTarget.id : '-')));"
    "</script></body></html>";

void down(RenderEnv& env, double x, double y) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Down, x, y, 1, true);
    env.env().drain();
}

void up(RenderEnv& env, double x, double y) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Up, x, y, 1, true);
    env.env().drain();
}

} // namespace

WR_TEST(testATapMovesNoFocus) {
    RenderEnv env(kTwo);
    down(env, 40, 25);
    up(env, 40, 25);
    CHECK_EQ(env.env().eval("document.activeElement === document.body"), std::string("true"));
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string(""));
}

WR_TEST(testFocusAndBlurDoNothing) {
    RenderEnv env(kTwo);
    CHECK_EQ(env.env().eval("b.focus(); [document.activeElement === document.body, log.length].join()"),
             std::string("true,0"));
    CHECK_EQ(env.env().eval("b.blur(); d.focus(); d.blur(); [document.activeElement === document.body, log.length].join()"),
             std::string("true,0"));
    CHECK_EQ(env.env().eval("document.querySelector(':focus') === null && document.querySelector(':focus-within') === null"),
             std::string("true"));
    // tabIndex still reflects the attribute.
    CHECK_EQ(env.env().eval("d.tabIndex = 0; [d.tabIndex, d.getAttribute('tabindex')].join()"), std::string("0,0"));
}

WR_TEST(testHoverActiveRender) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} button{position:absolute;left:10px;"
                  "top:10px;width:80px;height:30px;display:block;border:0;background:#eee;color:#000}"
                  "button:hover{background:#00f} button:active{color:#f00}"
                  "</style></head><body><button>b</button></body></html>");
    const std::string before = env.render().layerTree()->dump();
    down(env, 40, 25);
    const std::string pressed = env.render().layerTree()->dump();
    CHECK(pressed != before);
    CHECK_EQ(env.env().eval("document.querySelector('button:active') !== null"), std::string("true"));
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK_EQ(pressed, rebuilt);
    up(env, 40, 25);
    const std::string released = env.render().layerTree()->dump();
    CHECK(released != pressed);
    CHECK(released != before);
    // The hover stays after the up, as touch browsers keep it; the press is over.
    CHECK_EQ(env.env().eval("[!!document.querySelector('button:hover'), !!document.querySelector('button:active')].join()"),
             std::string("true,false"));
    auto [layout2, input2, rebuilt2] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout2);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt2);
}

// A tap's :hover and :active change is a patch (twidget edit 75): no new document, the layout and the layer tree a fresh
// build's, and operations. A page whose CSS never reads the state (and with no form control) publishes nothing.
WR_TEST(testATapIsAPatch) {
    struct Case {
        const char* page;
        double x, y;
        bool publishes;
        const char* what;
    };
    const Case cases[] = {
        {"button{position:absolute;left:10px;top:10px;width:80px;height:30px;display:block;border:0;background:#eee;"
         "color:#000} button:hover{background:#00f} button:active{color:#f00}</style></head><body><button>b</button>",
         40, 25, true, "hover and active on a button"},
        {"</style></head><body><button style='margin:10px'>press</button>", 30, 20, true, "the UA sheet's :active opacity"},
        {".card{padding:10px} .card:hover{opacity:.8} .abs{position:absolute;left:150px;top:5px}</style></head><body>"
         "<div class=card><span>tap</span><span class=abs>abs</span></div>",
         15, 15, true, "a paint group on an ancestor"},
        {".card{padding:10px} .card:hover .t{display:none}</style></head><body><div class=card><span>tap</span> "
         "<span class=t>gone</span></div>",
         15, 15, true, "a rule on a descendant"},
        {"a{display:block;height:20px} a:hover + .tip{display:block} .tip{display:none}</style></head><body><a>link</a>"
         "<div class=tip>tip</div><p>after</p>",
         10, 10, true, "a rule on the next sibling"},
        {"p{color:#333}</style></head><body><p>plain</p>", 10, 10, false, "no rule reads the state"},
    };
    for (const Case& k : cases) {
        RenderEnv env(std::string("<!doctype html><html><head><style>body{margin:0;padding:0} ") + k.page + "</body></html>");
        for (int phase = 0; phase < 2; phase++) {
            const std::string what = std::string(k.what) + (phase == 0 ? ", down" : ", up");
            const uint64_t builds = env.render().buildCount();
            const uint64_t patches = env.render().patchCount();
            if (phase == 0) {
                down(env, k.x, k.y);
            } else {
                up(env, k.x, k.y);
            }
            if (env.render().buildCount() != builds) {
                std::printf("  a new document after: %s\n", what.c_str());
            }
            CHECK_EQ(env.render().buildCount(), builds);
            if (!k.publishes) {
                CHECK_EQ(env.render().patchCount(), patches);
                continue;
            }
            auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
            CHECK_EQ(env.render().layoutDump(), layout);
            CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
        }
    }
}

// Twidget edit 82 (Review Focus 4): after the document element is replaced in place, a tap on the new tree is one patch,
// equal to a rebuild.
WR_TEST(testATapOnAReplacedDocument) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0}</style></head><body><p>old</p></body></html>");
    const uint64_t builds = env.render().buildCount();
    CHECK_EQ(env.env().eval("const h = document.createElement('html'); h.innerHTML = '<head><style>body{margin:0;padding:0}"
                            " .c{display:block;height:30px} .c:hover{color:#c00}</style></head><body><div class=c>tap</div>"
                            "</body>'; document.documentElement.replaceWith(h); 'ok'"),
             std::string("ok"));
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    const uint64_t patches = env.render().patchCount();
    down(env, 10, 10);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK(env.render().layerTree() && env.render().layerTree()->dump() == rebuilt);
    up(env, 10, 10);
}

// A press restyles only what its state reaches: the hover and press chain's elements whose matching the press cannot
// change (the root, the body) are left alone, so the changed rects stay where the pressed element is.
WR_TEST(testAPressChangesOnlyWhatItRestyles) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0} #a{height:200px;background:rgb(0,0,255)}"
                  " #b{height:40px;background:rgb(255,0,0)} #b:active{background:rgb(0,255,0)}</style></head><body>"
                  "<div id=a></div><div id=b></div></body></html>");
    env.render().takeChangedRects();
    down(env, 20, 220);
    const auto rects = env.render().takeChangedRects();
    CHECK(rects && !rects->empty());
    if (rects) {
        for (const auto& rect : *rects) {
            if (rect.y.value() < 199) {
                std::printf("  a changed rect above the pressed element: (%g, %g, %g, %g)\n", double(rect.x.value()),
                            double(rect.y.value()), double(rect.width.value()), double(rect.height.value()));
            }
            CHECK(rect.y.value() >= 199);
        }
    }
}

// A tap's state change patches (twidget edit 75): with :hover in a compound that is not a subject, every element of the
// tapped chain reaches its subtree, and the chain's flips are planned and matched together, shallow or deep.
WR_TEST(testADeepTapPatches) {
    for (int depth : {4, 24}) {
        std::string page = "<!doctype html><html><head><style>body{margin:0} .c{padding:0} .c:hover .x{color:#c00}</style>"
                           "</head><body>";
        for (int d = 0; d < depth; d++) {
            page += "<div class=c>";
        }
        for (int d = 0; d < depth; d++) {
            for (int k = 0; k < 600 / depth; k++) {
                page += "<span class=x>s</span> ";
            }
            page += "</div>";
        }
        RenderEnv env(page + "</body></html>");
        const uint64_t builds = env.render().buildCount();
        const uint64_t patches = env.render().patchCount();
        down(env, 3, 3);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.render().patchCount() > patches);
    }
}

// :focus-within is out of profile 1 (sel.focus, V4 plan, Task 3b), and nothing takes focus (Task 8).
WR_TEST(testFocusWithinNeverMatches) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} #w{width:100px;height:50px}"
                  "#w:focus-within{background:#f00}</style></head><body><div id=w><button id=i>i</button></div><script>"
                  "window.i = document.getElementById('i');</script></body></html>");
    const std::string before = env.render().layerTree()->dump();
    CHECK_EQ(env.env().eval("i.focus(); document.activeElement === document.body"), std::string("true"));
    env.flush();
    CHECK_EQ(env.render().layerTree()->dump(), before);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
}

// Review Focus 5: a tap whose pointerdown listener inserts an element under the tapped one, which a rule reads through
// the tapped element's :hover: the state and the insertion are one patch, as a fresh build agrees.
WR_TEST(testATapBesideAnInsertionUnderIt) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} .c{padding:10px} .c:hover .x{color:#c00}"
                  "</style></head><body><div class=c id=c><span>tap</span></div><script>document.getElementById('c')"
                  ".addEventListener('pointerdown', e => { const x = document.createElement('span'); x.className = 'x';"
                  " x.textContent = 'x'; e.currentTarget.append(x); });</script></body></html>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    down(env, 15, 15);
    CHECK_EQ(env.env().eval("document.querySelectorAll('.x').length"), std::string("1"));
    if (env.render().buildCount() != builds) {
        std::printf("  a new document (%s): a tap beside an insertion under it\n", env.render().lastPatchRefusal());
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
}
