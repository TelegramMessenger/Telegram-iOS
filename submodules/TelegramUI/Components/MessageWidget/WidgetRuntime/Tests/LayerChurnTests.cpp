// The flush probe (RenderTree::FlushProbe) and the churn metric it feeds (Tests/LayerChurn.h): the layers a flush
// re-creates though their element did not change.
#include <cstdio>
#include <memory>
#include <set>
#include <string>
#include <vector>

#include <litehtml/document.h>

#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Tests/LayerChurn.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

struct RecordingProbe final : wr::RenderTree::FlushProbe {
    int before = 0;
    int after = 0;
    void beforeFlush(const wr::RenderTree&) override { before++; }
    void afterPublish(const wr::RenderTree&) override { after++; }
};

void run(RenderEnv& env, const std::string& script) {
    CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
}

// The NodeKey of the rendered element whose id is `id`, 0 when there is none.
wr::NodeKey keyOfId(RenderEnv& env, const char* id) {
    for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
        if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
            return entry.key;
        }
    }
    return 0;
}

// The litehtml element of the rendered element whose id is `id`, null when there is none.
std::shared_ptr<litehtml::element> elementOfId(RenderEnv& env, const char* id) {
    for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
        if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
            return entry.element;
        }
    }
    return nullptr;
}

// The live render items of the rendered elements whose ids are `ids`, in order (null for none). Held, so that an item
// made again cannot take a kept one's address.
std::vector<std::shared_ptr<litehtml::render_item>> itemsOf(RenderEnv& env, std::initializer_list<const char*> ids) {
    std::vector<std::shared_ptr<litehtml::render_item>> out;
    for (const char* id : ids) {
        std::shared_ptr<litehtml::render_item> item;
        for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
            if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
                item = env.render().document()->live_item(*entry.element);
                break;
            }
        }
        CHECK(item != nullptr);
        out.push_back(std::move(item));
    }
    return out;
}

const char* const kList = "<!doctype html><body><ul id=l><li id=a>a</li><li id=b>b</li><li id=c>c</li></ul></body>";

// The churn of one script and flush on a fresh env of `page`, measured by a probe installed after the boot.
struct Measured {
    wr_test::ChurnProbe probe;
    std::set<wr::NodeKey> keys(RenderEnv& env, std::initializer_list<const char*> ids) {
        std::set<wr::NodeKey> out;
        for (const char* id : ids) {
            out.insert(keyOfId(env, id));
        }
        return out;
    }
};

} // namespace

// The probe is told before each flush after the boot that has a journal to apply, and after it published; a flush with
// nothing to apply tells it nothing, and one that stops the widget only before.
WR_TEST(testTheFlushProbeSeesEveryFlushAfterTheBoot) {
    RenderEnv env("<!doctype html><body><p id=p>t</p><p id=i title=abc>abc</p></body>");
    RecordingProbe probe;
    env.render().setFlushProbeForTesting(&probe);
    run(env, "document.getElementById('p').firstChild.data = 'u'");
    env.flush();
    CHECK_EQ(probe.before, 1);
    CHECK_EQ(probe.after, 1);
    env.flush();
    CHECK_EQ(probe.before, 1);
    CHECK_EQ(probe.after, 1);
    env.render().setPatchStepCapForTesting(0);
    run(env, "document.getElementById('i').setAttribute('title', 'abcdef')");
    try {
        env.flush();
    } catch (const wr::Aborted&) {
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Internal);
    CHECK_EQ(probe.before, 2);
    CHECK_EQ(probe.after, 1);
    env.render().setFlushProbeForTesting(nullptr);
}

// A block-level item appended to a list links its own render subtree (twidget edit 89): the list and its other items
// keep their render items and layers.
WR_TEST(testAppendingAListItemChurnsNothing) {
    RenderEnv env(kList);
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'd'; document.getElementById('l').append(li)");
    env.flush();
    CHECK_EQ(m.probe.flushes(), size_t(1));
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(m.probe.last().inserted > 0);
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// A removed item's layers go (no churn: it renders no more); the rest keep theirs, and their render items.
WR_TEST(testRemovingAListItemChurnsNothing) {
    RenderEnv env(kList);
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "c"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.getElementById('b').remove()");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK(m.probe.last().removed > 0);
    CHECK(itemsOf(env, {"l", "a", "c"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// A node the structure patch builds again where it moves keeps its NodeKey, as a node kept by a replaced document
// element does: the selectable text follows Text nodes by key, and the churn metric elements.
WR_TEST(testAMovedNodeKeepsItsKey) {
    RenderEnv env(kList);
    const wr::NodeKey before = keyOfId(env, "c");
    CHECK(before != 0);
    run(env, "const l = document.getElementById('l'); l.insertBefore(document.getElementById('c'), document.getElementById('a'))");
    env.flush();
    CHECK_EQ(keyOfId(env, "c"), before);
}

// A moved node keeps its NodeKey, so its re-created layers count (the design's Goal 4): a moved item is unlinked and
// linked again, its siblings keep their layers and render items.
WR_TEST(testMovingAListItemChurnsOnlyIt) {
    RenderEnv env(kList);
    Measured m;
    const std::set<wr::NodeKey> moved = m.keys(env, {"c"});
    const auto items = itemsOf(env, {"l", "a", "b"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const l = document.getElementById('l'); l.insertBefore(document.getElementById('c'), document.getElementById('a'))");
    env.flush();
    CHECK(m.probe.last().churnedKeys == moved);
    CHECK(itemsOf(env, {"l", "a", "b"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// An item inserted first into an ordered list numbers the others again in place: their markers are re-captured, their
// layers and render items kept.
WR_TEST(testInsertingIntoAnOrderedListChurnsNothing) {
    RenderEnv env("<!doctype html><body><ol id=l start=3><li id=a>a</li><li id=b>b</li><li id=c>c</li></ol></body>");
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'z'; document.getElementById('l').prepend(li)");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// A child appended under <html> beside the body links under the root render item, which stays, as does the body's.
WR_TEST(testAnHtmlChildIsLinked) {
    RenderEnv env("<!doctype html><body id=y><p id=p>t</p></body>");
    Measured m;
    const std::shared_ptr<litehtml::render_item> root = env.render().document()->root_render();
    const auto items = itemsOf(env, {"y", "p"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.documentElement.append(document.createElement('div'))");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(env.render().document()->root_render() == root);
    CHECK(itemsOf(env, {"y", "p"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// An element whose outer box changes is excused with its subtree (the <span>); its sibling under the replaced boundary
// is not; the anonymous block around the new inline-block (NodeKey 0) counts nothing.
WR_TEST(testABoxChangeExcusesItsSubtree) {
    RenderEnv env("<!doctype html><body><div id=a>a</div><div id=b><span id=s>b</span></div></body>");
    Measured m;
    const std::set<wr::NodeKey> sibling = m.keys(env, {"a"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.getElementById('b').style.display = 'inline-block'");
    env.flush();
    CHECK(m.probe.last().removed > 0);
    CHECK(m.probe.last().churnedKeys == sibling);
    env.render().setFlushProbeForTesting(nullptr);
}

// The box rule alone excuses what is under a changed element: a <p> in a bordered wrapper (the wrapper has a key) and in
// a plain one (no layer of its own, so no key) is excused when the wrapper's display changes, its sibling is not.
WR_TEST(testABoxChangeExcusesAWrappersSubtree) {
    for (const char* wrapper : {"<div id=b style='border:1px solid'>", "<div id=b>"}) {
        RenderEnv env(std::string("<!doctype html><body><div id=a>a</div>") + wrapper + "<p id=p>b</p></div></body>");
        Measured m;
        const std::set<wr::NodeKey> sibling = m.keys(env, {"a"});
        env.render().setFlushProbeForTesting(&m.probe);
        run(env, "document.getElementById('b').style.display = 'inline-block'");
        env.flush();
        CHECK(m.probe.last().removed > 0);
        if (m.probe.last().churnedKeys != sibling) {
            std::printf("  %s: %zu churned elements, not only the sibling\n", wrapper, m.probe.last().churnedKeys.size());
        }
        CHECK(m.probe.last().churnedKeys == sibling);
        env.render().setFlushProbeForTesting(nullptr);
    }
}

// A change of an inline context's children excuses its runs (here re-created with the paragraph's boundary).
WR_TEST(testAChildChangeExcusesItsInlineContext) {
    RenderEnv env("<!doctype html><body><p id=p>one <b>two</b></p><p id=q>q</p></body>");
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const s = document.createElement('span'); s.textContent = ' three'; document.getElementById('p').append(s)");
    env.flush();
    CHECK(m.probe.last().removed > 0);
    CHECK_EQ(m.probe.last().churned, size_t(0));
    env.render().setFlushProbeForTesting(nullptr);
}

// A restyle of an inline element is no change of its inline context's content: the line's runs re-created with the
// paragraph's boundary count.
WR_TEST(testARestyledInlineChurnsItsLine) {
    RenderEnv env("<!doctype html><body><p id=p>one <b id=b>two</b></p><p id=q>q</p></body>");
    Measured m;
    const std::set<wr::NodeKey> line = m.keys(env, {"p"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.getElementById('b').style.fontSize = '20px'");
    env.flush();
    CHECK(m.probe.last().removed > 0);
    CHECK(m.probe.last().churnedKeys == line);
    env.render().setFlushProbeForTesting(nullptr);
}

// A layer that goes and is not made again (a background removed, a group that ends) is no churn.
WR_TEST(testADroppedLayerIsNotChurn) {
    const char* const cases[][2] = {
        {"<div id=d style='background:red'>text</div>", "document.getElementById('d').style.background = 'none'"},
        {"<div id=d style='opacity:.5'>text</div>", "document.getElementById('d').style.opacity = '1'"},
    };
    for (const auto& c : cases) {
        RenderEnv env(std::string("<!doctype html><body>") + c[0] + "</body>");
        Measured m;
        env.render().setFlushProbeForTesting(&m.probe);
        run(env, c[1]);
        env.flush();
        CHECK(m.probe.last().removed > 0);
        if (m.probe.last().churned != 0) {
            std::printf("  %s: %zu churned\n", c[1], m.probe.last().churned);
        }
        CHECK_EQ(m.probe.last().churned, size_t(0));
        env.render().setFlushProbeForTesting(nullptr);
    }
}

// A change that renders nothing re-creates nothing.
WR_TEST(testAScriptChurnsNothing) {
    RenderEnv env(kList);
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const s = document.createElement('script'); s.textContent = '1'; document.body.append(s)");
    env.flush();
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK_EQ(m.probe.last().inserted, size_t(0));
    CHECK_EQ(m.probe.last().churned, size_t(0));
    env.render().setFlushProbeForTesting(nullptr);
}

// A flush that stops the widget adds nothing to the measure.
WR_TEST(testAStoppedFlushCountsNothing) {
    RenderEnv env(kList);
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'd'; document.getElementById('l').append(li)");
    env.flush();
    CHECK_EQ(m.probe.flushes(), size_t(1));
    const size_t churned = m.probe.total().churned;
    const size_t removed = m.probe.total().removed;
    env.render().setPatchStepCapForTesting(0);
    run(env, "document.getElementById('a').setAttribute('title', 'abcdef')");
    try {
        env.flush();
    } catch (const wr::Aborted&) {
    }
    CHECK_EQ(m.probe.flushes(), size_t(1));
    CHECK_EQ(m.probe.total().churned, churned);
    CHECK_EQ(m.probe.total().removed, removed);
    env.render().setFlushProbeForTesting(nullptr);
}

// The churn is summed by the fork's reason for replacing render subtrees: a floated item is not linked yet (twidget
// edit 89's refusals), so the list is replaced and its other items' layers re-created under that reason.
WR_TEST(testChurnIsBucketedByReason) {
    RenderEnv env(kList);
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'd'; li.style.cssFloat = 'left';"
             " document.getElementById('l').append(li)");
    env.flush();
    const char* const reason = "structure: insert: a float or an out-of-flow box";
    CHECK_EQ(m.probe.byReason().count(reason), size_t(1));
    CHECK(m.probe.total().churned > 0);
    if (m.probe.byReason().count(reason)) {
        CHECK_EQ(m.probe.byReason().at(reason).churned, m.probe.total().churned);
    }
    env.render().setFlushProbeForTesting(nullptr);
}

// A moved node's re-created layers are counted apart, under "(moved)" (the design's Step 5), whatever the flush's reason.
WR_TEST(testAMoveIsBucketedAsMoved) {
    RenderEnv env(kList);
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const l = document.getElementById('l'); l.insertBefore(document.getElementById('c'), document.getElementById('a'))");
    env.flush();
    CHECK(m.probe.total().churned > 0);
    CHECK_EQ(m.probe.byReason().count("(moved)"), size_t(1));
    if (m.probe.byReason().count("(moved)")) {
        CHECK_EQ(m.probe.byReason().at("(moved)").churned, m.probe.total().churned);
    }
    env.render().setFlushProbeForTesting(nullptr);
}

// An element's own attribute change beside structure (a mixed journal) is set in place: it keeps its litehtml element,
// and it, the list and the other items keep their render items and layers.
WR_TEST(testAnOwnAttributeBesideStructureKeepsItsLayers) {
    RenderEnv env("<!doctype html><style>li{background:#eee} .k{color:#c00}</style><body><ul id=l><li id=a>a</li>"
                  "<li id=b>b</li><li id=c>c</li></ul></body>");
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    const std::weak_ptr<litehtml::element> a = elementOfId(env, "a");
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.getElementById('a').className = 'k'; const li = document.createElement('li'); li.textContent = 'd';"
             " document.getElementById('l').append(li)");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    CHECK(a.lock() == elementOfId(env, "a"));
    env.render().setFlushProbeForTesting(nullptr);
}

// A parent whose own attributes and children change in one flush is set in place and reconciled: it and its items keep
// their render items and layers.
WR_TEST(testAParentsOwnAttributeBesideStructureKeepsItsLayers) {
    RenderEnv env("<!doctype html><style>li{background:#eee} .k{color:#c00}</style><body><ul id=l><li id=a>a</li>"
                  "<li id=b>b</li><li id=c>c</li></ul></body>");
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    const std::weak_ptr<litehtml::element> l = elementOfId(env, "l");
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const l = document.getElementById('l'); l.className = 'k'; const li = document.createElement('li');"
             " li.textContent = 'd'; l.append(li)");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    CHECK(l.lock() == elementOfId(env, "l"));
    env.render().setFlushProbeForTesting(nullptr);
}

// An animation frame journals its element's attributes (RenderTree::animatedStyleChanged); beside structure in the same
// flush the frame is set in place, and the animated element keeps its render items and layers.
WR_TEST(testAnAnimatedElementBesideStructureKeepsItsLayers) {
    RenderEnv env("<!doctype html><style>@keyframes f{from{background-color:#eee}to{background-color:#333}}"
                  " #a{animation:f 1s infinite} li{background:#eee}</style><body><ul id=l><li id=a>a</li>"
                  "<li id=b>b</li><li id=c>c</li></ul></body>");
    env.env().frame(16);
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    const std::weak_ptr<litehtml::element> a = elementOfId(env, "a");
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'd'; document.getElementById('l').append(li)");
    env.env().frame(100);
    CHECK(m.probe.flushes() > 0);
    CHECK_EQ(m.probe.total().churned, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    CHECK(a.lock() == elementOfId(env, "a"));
    env.render().setFlushProbeForTesting(nullptr);
}

// A Text's own change beside structure is replaced in place (twidget edit 16): its item keeps its render item, and so
// do the list and the other items, with their layers.
WR_TEST(testAnOwnTextBesideStructureKeepsItsLayers) {
    RenderEnv env("<!doctype html><style>li{background:#eee}</style><body><ul id=l><li id=a>a</li><li id=b>b</li>"
                  "<li id=c>c</li></ul></body>");
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "document.getElementById('a').firstChild.data = 'changed'; const li = document.createElement('li');"
             " li.textContent = 'd'; document.getElementById('l').append(li)");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// Under a sibling rule an appended item is linked and the reached siblings matched again in place (twidget edit 90): the
// list and its other items keep their render items and layers.
WR_TEST(testAppendingUnderSiblingSelectorsChurnsNothing) {
    RenderEnv env("<!doctype html><style>li + li{color:#c00}</style><body><ul id=l><li id=a>a</li><li id=b>b</li>"
                  "<li id=c>c</li></ul></body>");
    Measured m;
    const auto items = itemsOf(env, {"l", "a", "b", "c"});
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'd'; document.getElementById('l').append(li)");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    CHECK(itemsOf(env, {"l", "a", "b", "c"}) == items);
    env.render().setFlushProbeForTesting(nullptr);
}

// Generated elements (::before, ::after, a form control's lh-* parts) are keyed by their owner and their slot: the key
// stays while the owner does, and their text pieces have none (selectable text skips them).
WR_TEST(testAPseudoElementHasItsOwnersKey) {
    RenderEnv env("<!doctype html><style>li::before{content:'\\2022';display:block;background:#eee}</style>"
                  "<body><ul id=l><li id=a>a</li><li id=b>b</li><li id=c>c</li></ul></body>");
    const auto beforeOf = [&](const char* id) -> litehtml::element::ptr {
        for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
            if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
                const auto& kids = entry.element->children();
                return !kids.empty() && kids.front()->tag() == litehtml::__tag_before_ ? kids.front() : nullptr;
            }
        }
        return nullptr;
    };
    const auto a = beforeOf("a"), b = beforeOf("b"), c = beforeOf("c");
    CHECK(a && b && c);
    if (!a || !b || !c) {
        return;
    }
    const wr::NodeKey ka = env.render().keyOfForTesting(*a);
    const wr::NodeKey kb = env.render().keyOfForTesting(*b);
    const wr::NodeKey kc = env.render().keyOfForTesting(*c);
    CHECK(ka != 0 && kb != 0 && kc != 0);
    CHECK(ka != kb && kb != kc && ka != kc);
    CHECK_EQ(env.render().ownerKeyOfGenerated(ka), keyOfId(env, "a"));
    CHECK_EQ(env.render().ownerKeyOfGenerated(keyOfId(env, "a")), wr::NodeKey(0));
    CHECK(!a->children().empty());
    if (!a->children().empty()) {
        CHECK_EQ(env.render().keyOfForTesting(*a->children().front()), wr::NodeKey(0));
    }
    run(env, "document.getElementById('b').firstChild.data = 'bb'");
    env.flush();
    const auto again = beforeOf("a");
    CHECK(again != nullptr);
    if (again) {
        CHECK_EQ(env.render().keyOfForTesting(*again), ka);
    }
}

// Twidget edit 91: an item inserted at 1 under li + li matches b and c again to no change, and their ::before layers stay.
WR_TEST(testAnUnchangedReMatchKeepsPseudoLayers) {
    RenderEnv env("<!doctype html><style>li::before{content:'\\2022';display:block;background:#eee} li + li{color:#c00}"
                  "</style><body><ul id=l><li id=a>a</li><li id=b>b</li><li id=c>c</li></ul></body>");
    Measured m;
    env.render().setFlushProbeForTesting(&m.probe);
    run(env, "const li = document.createElement('li'); li.textContent = 'n'; const l = document.getElementById('l');"
             " l.insertBefore(li, l.children[1])");
    env.flush();
    CHECK_EQ(m.probe.last().churned, size_t(0));
    CHECK_EQ(m.probe.last().removed, size_t(0));
    env.render().setFlushProbeForTesting(nullptr);
}
