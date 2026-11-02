// The style-change step (V5f plan, Task 2): an element's declared values as the cascade gave them, never its animated
// ones; the style sheets a build applied; and which elements a flush resolved styles for again, which is what CSS
// animations and transitions read.
#include <algorithm>
#include <cstdio>
#include <string>
#include <vector>

#include "Sources/Animation/AnimationState.h"
#include "Sources/DOM/DOMState.h"
#include "Sources/DOM/Document.h"
#include "Sources/DOM/Element.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage =
    "<!doctype html><style>.c { transform: translateX(5px); width: 30px; height: 10px } .d { transform: rotate(10deg) }</style>"
    "<body><div id=a class=c></div><div id=b></div><p id=t>text</p></body>";

wr::Element* byId(RenderEnv& env, const char* id) {
    return wr::DOMState::of(env.ctx()).document().getElementById(env.ctx(), wr::String::fromUTF8(env.ctx(), id));
}

std::string declared(RenderEnv& env, const char* id, const char* property) {
    wr::Element* element = byId(env, id);
    return element ? env.render().declaredValue(*element, property) : std::string("(no element)");
}

/// What one stylesResolved call saw: "all", or the ids (or tag names) of its elements, sorted.
std::string describe(RenderEnv& env, const wr::animation::StyleChange& change) {
    if (change.all) {
        return "all";
    }
    std::vector<std::string> names;
    for (const wr::Ref<wr::Element>& element : change.elements) {
        const std::optional<wr::String> id = element->attributeValue(env.ctx(), wr::DOMState::of(env.ctx()).name(wr::Name::id));
        names.push_back(id ? id->utf8() : element->localName(env.ctx()).utf8());
    }
    std::sort(names.begin(), names.end());
    std::string out;
    for (const std::string& name : names) {
        out += (out.empty() ? "" : ",") + name;
    }
    return out;
}

} // namespace

/// The animated layer opens with twidget's `-lh-anim` marker, so litehtml records none of its declarations as declared
/// values: a transition compares what the cascade gives, and a class flip still changes it.
WR_TEST(testDeclaredValuesIgnoreTheAnimationLayer) {
    RenderEnv env(kPage);
    CHECK_EQ(declared(env, "a", "transform"), std::string("translateX(5px)"));
    CHECK_EQ(declared(env, "a", "width"), std::string("30px"));
    CHECK_EQ(declared(env, "b", "transform"), std::string(""));
    env.env().eval("window.z = document.getElementById('a').animate({transform: ['translateX(0px)', 'translateX(40px)']}, 1000);"
                   " z.pause(); z.currentTime = 500; 1");
    env.flush();
    CHECK_EQ(env.env().eval("getComputedStyle(document.getElementById('a')).transform"), std::string("matrix(1, 0, 0, 1, 20, 0)"));
    CHECK_EQ(declared(env, "a", "transform"), std::string("translateX(5px)"));
    env.env().eval("document.getElementById('a').className = 'd'; 1");
    env.flush();
    CHECK_EQ(declared(env, "a", "transform"), std::string("rotate(10deg)"));
}

WR_TEST(testTheStyleSheetsAreKept) {
    RenderEnv env("<!doctype html><style>.x { color: red }</style><body><style>@keyframes k { to { opacity: 0 } }</style></body>");
    const std::vector<std::string>& sheets = env.render().styleSheets();
    CHECK_EQ(sheets.size(), size_t(2));
    CHECK(sheets.size() == 2 && sheets[0] == ".x { color: red }" && sheets[1] == "@keyframes k { to { opacity: 0 } }");
    env.env().eval("const s = document.createElement('style'); s.textContent = '@keyframes j { to { top: 1px } }'; document.body.append(s); 1");
    env.flush();
    CHECK_EQ(env.render().styleSheets().size(), size_t(3));
}

/// Which elements a flush resolved styles for again: every one after a build; the elements whose DOM attributes changed
/// and every element a patch restyled (twidget edit 77), so after an insertion every element of the inserted subtree and
/// the parent's other children a positional rule matched again (the UA layer's `body>:first-child`); none for a text
/// change or an animation's frame.
WR_TEST(testStylesResolvedSeesWhatWasRestyled) {
    std::vector<std::string> calls;
    RenderEnv* current = nullptr;
    RenderEnv env(kPage, {}, true, [&](wr_test::HostEnv& host) {
        wr::animation::AnimationState::of(host.ctx()).setStyleObserverForTesting(
            [&](const wr::animation::StyleChange& change) { calls.push_back(current ? describe(*current, change) : (change.all ? "all" : "some")); });
    });
    current = &env;
    CHECK(calls.size() == 1 && calls[0] == "all");
    calls.clear();
    env.env().eval("document.getElementById('b').className = 'c'; 1");
    env.flush();
    CHECK(calls.size() == 1 && calls[0] == "b");
    calls.clear();
    env.env().eval("document.getElementById('b').style.width = '7px'; 1");
    env.flush();
    CHECK(calls.size() == 1 && calls[0] == "b");
    calls.clear();
    env.env().eval("const d = document.createElement('div'); d.id = 'n'; d.innerHTML = '<span id=m>x</span>'; document.body.append(d); 1");
    env.flush();
    if (!(calls.size() == 1 && calls[0] == "a,b,m,n,t")) std::printf("  an insertion: %s\n", calls.empty() ? "(none)" : calls[0].c_str());
    CHECK(calls.size() == 1 && calls[0] == "a,b,m,n,t");
    calls.clear();
    env.env().eval("document.getElementById('t').firstChild.data = 'other'; 1");
    env.flush();
    CHECK(calls.empty());
    env.env().eval("window.r = document.getElementById('a').animate({opacity: [1, 0]}, 1000); 1");
    env.env().frame(16);
    env.env().frame(100);
    env.env().frame(100);
    CHECK(calls.empty());
    if (!calls.empty()) {
        for (const std::string& call : calls) {
            std::printf("  unexpected call: %s\n", call.c_str());
        }
    }
}
