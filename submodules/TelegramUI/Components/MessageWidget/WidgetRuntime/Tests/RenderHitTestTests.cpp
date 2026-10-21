// Hit-testing and boxes (M1c plan, Task 10): a point to its node, an svg shape, an inline element's boxes, and nodes
// that render nothing.
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

wr::Node* byId(RenderEnv& env, const char* id) {
    return wr::DOMState::of(env.ctx()).document().getElementById(env.ctx(), wr::String::fromUTF8(env.ctx(), id));
}

// The id of the element at the point; "html" for the document element, "<none>" for anything else.
std::string idAt(RenderEnv& env, double x, double y) {
    wr::Node* node = env.render().nodeAt(x, y);
    if (node && node == wr::DOMState::of(env.ctx()).document().documentElementNode()) {
        return "html";
    }
    for (const char* id : {"b", "s", "none", "v", "r"}) {
        if (node && node == byId(env, id)) {
            return id;
        }
    }
    return "<none>";
}

} // namespace

WR_TEST(testPointToNode) {
    RenderEnv env("<!doctype html><body style='margin:0'><button id=b style='width:80px;height:30px'>Go</button>"
                  "<p style='margin:0'><span id=s>hello</span></p>"
                  "<div id=none style='pointer-events:none;width:100px;height:40px;background:#ccc'></div></body>");
    env.flush();
    auto b = env.render().borderBox(*byId(env, "b"));
    CHECK(b.has_value());
    CHECK_EQ(idAt(env, b->x + b->width / 2, b->y + b->height / 2), std::string("b"));
    auto s = env.render().borderBox(*byId(env, "s"));
    CHECK(s.has_value());
    CHECK_EQ(idAt(env, s->x + 2, s->y + s->height / 2), std::string("s"));
    // Under pointer-events:none the element beneath answers (the body, whose box holds it).
    auto n = env.render().borderBox(*byId(env, "none"));
    CHECK(n.has_value());
    CHECK(idAt(env, n->x + 5, n->y + 5) != std::string("none"));
    // Far outside everything: the document element.
    CHECK_EQ(idAt(env, 5000, 5000), std::string("html"));
}

WR_TEST(testSvgShapeHit) {
    RenderEnv env("<!doctype html><body style='margin:0'><svg id=v width=100 height=100 viewBox='0 0 100 100'>"
                  "<rect id=r x=20 y=20 width=40 height=40 fill='red'/></svg></body>");
    env.flush();
    auto v = env.render().borderBox(*byId(env, "v"));
    CHECK(v.has_value());
    CHECK_EQ(idAt(env, v->x + 40, v->y + 40), std::string("r"));
    CHECK_EQ(idAt(env, v->x + 90, v->y + 90), std::string("v"));
}

WR_TEST(testInlineBoxIsTheUnionOfItsLines) {
    RenderEnv env("<!doctype html><body style='margin:0;width:100px;font:16px monospace'>"
                  "<span id=s>aaaa bbbb cccc dddd eeee ffff</span></body>",
                  [] {
                      wr::RenderOptions o;
                      o.width = 100;
                      return o;
                  }());
    env.flush();
    wr::Node* s = byId(env, "s");
    auto rects = env.render().clientRects(*s);
    CHECK(rects.size() >= 2);
    auto box = env.render().borderBox(*s);
    CHECK(box.has_value());
    if (box && rects.size() >= 2) {
        for (const auto& r : rects) {
            CHECK(r.x >= box->x - 0.01 && r.y >= box->y - 0.01);
            CHECK(r.x + r.width <= box->x + box->width + 0.01);
            CHECK(r.y + r.height <= box->y + box->height + 0.01);
        }
        CHECK(box->height > rects.front().height);
    }
}

WR_TEST(testUnrenderedNodeHasNoBox) {
    RenderEnv env("<!doctype html><body><script id=sc>1</script><template id=t><i>x</i></template><p id=p>p</p></body>");
    env.flush();
    for (const char* id : {"sc", "t"}) {
        wr::Node* n = byId(env, id);
        CHECK(n != nullptr);
        CHECK(!env.render().borderBox(*n).has_value());
        CHECK(env.render().clientRects(*n).empty());
    }
    wr::Node* p = byId(env, "p");
    CHECK(env.render().borderBox(*p).has_value());
    // A Text node has no box either.
    CHECK(!env.render().borderBox(*p->firstChildNode()).has_value());
}
