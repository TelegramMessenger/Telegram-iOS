// widget-sandbox v0.3.0, limit.batch: at most 10,000 operations in one batch, past which the widget stops ("Ops limit
// exceeded"). An operation is what upstream's shim would send for a DOM change (the plan's R-ops): a node's first
// insertion is two (made, inserted), a later one one, a removal one (a move, removed and inserted in one batch, one in
// all), and an attribute or a text changed in a batch one, once the node was inserted in an earlier batch. A batch is
// one task's changes, cut by a layout query's flush, as upstream's shim flushes before a query.
#include <string>

#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kPage = "<!doctype html><html><head></head><body><div id=box style=\"display:none\"></div>"
                          "<p id=p>t</p><script>window.box = document.getElementById('box');"
                          "window.p = document.getElementById('p');</script></body></html>";

bool stoppedForOps(RenderEnv& env) {
    const std::string& detail = env.env().runtime().stopDetail();
    const bool stopped = env.env().runtime().stopReason() == wr::StopReason::Limit &&
                         detail.rfind("Ops limit exceeded: ", 0) == 0 &&
                         detail.find(" operations in one batch (max 10000)") != std::string::npos;
    if (!stopped) {
        std::printf("    stopped %d: \"%s\"\n", int(env.env().runtime().stopReason()), detail.c_str());
    }
    return stopped;
}

} // namespace

/// auto/33-stop-batch: 5,001 elements made and appended in one task are 10,002 operations.
WR_TEST(testAppendingPastTheBatchCapStops) {
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 5001; i++) box.appendChild(document.createElement('i')); }); 1");
    env.env().drain();
    CHECK(stoppedForOps(env));
}

/// 5,000 of them fit: the cap is reached exactly, not passed.
WR_TEST(testAppendingUpToTheBatchCapRuns) {
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 5000; i++) box.appendChild(document.createElement('i')); }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// Each task is a batch of its own: two tasks of 8,000 operations each run.
WR_TEST(testEachTaskIsABatch) {
    RenderEnv env(kPage);
    env.env().eval("for (let t = 0; t < 2; t++) setTimeout(() => { for (let i = 0; i < 4000; i++) box.appendChild(document.createElement('i')); }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(env.env().eval("String(box.childNodes.length)"), std::string("8000"));
}

/// A layout query flushes the batch, as upstream's shim does before a query: 6,000 operations, a query, 6,000 more.
WR_TEST(testALayoutQueryEndsTheBatch) {
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 3000; i++) box.appendChild(document.createElement('i'));"
                   " p.getBoundingClientRect();"
                   " for (let i = 0; i < 3000; i++) box.appendChild(document.createElement('i')); }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// Upstream's shim sends a flush's difference: an attribute (or the inline style) or a text changed many times in one batch
/// is one operation (capture.ts), so 10,001 writes to each run.
WR_TEST(testAChangeCountsOncePerBatch) {
    for (const char* loop : {"p.setAttribute('data-n', String(i))", "p.style.left = i + 'px'", "p.firstChild.data = String(i)"}) {
        RenderEnv env(kPage);
        env.env().eval(std::string("setTimeout(() => { for (let i = 0; i < 10001; i++) ") + loop + "; }); 1");
        env.env().drain();
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    }
}

namespace {

/// `count` labelled <i> elements in #box, made over tasks of 2,000 (four operations each: the element, its text), each with
/// an inline style when `styled`.
void fillBox(RenderEnv& env, int count, bool styled = false) {
    env.env().eval("for (let t = 0; t < " + std::to_string(count) + "; t += 2000) setTimeout(() => { for (let i = t; i < Math.min(t + 2000, " +
                   std::to_string(count) + "); i++) { const e = document.createElement('i'); e.textContent = 'x';" +
                   (styled ? " e.style.left = '0px';" : "") + " box.appendChild(e); } }); 1");
    env.env().drain();
}

} // namespace

/// Distinct changes count one each: 5,001 elements given two attributes in one task are 10,002 operations.
WR_TEST(testDistinctChangesCountOneEach) {
    for (const int count : {5000, 5001}) {
        RenderEnv env(kPage);
        fillBox(env, count);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        env.env().eval("setTimeout(() => { for (const e of box.children) { e.setAttribute('a', '1'); e.setAttribute('b', '1'); } }); 1");
        env.env().drain();
        if (count == 5000) {
            CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        } else {
            CHECK(stoppedForOps(env));
        }
    }
}

/// An inline style's properties count one each once the renderer has the style, as upstream's shim sends a `style`
/// operation per changed property of a style attribute it sent before (capture.ts): 2,501 styled elements given four
/// properties in one task are 10,003 operations (the first element's `left` is already 0px).
WR_TEST(testInlineStylePropertiesCountOneEach) {
    for (const int count : {2500, 2501}) {
        RenderEnv env(kPage);
        fillBox(env, count, true);
        env.env().eval("setTimeout(() => { let i = 0; for (const e of box.children) { e.style.left = i + 'px'; e.style.top = i + 'px';"
                       " e.style.setProperty('opacity', '0.5'); e.style.color = 'red'; i++; } }); 1");
        env.env().drain();
        if (count == 2500) {
            CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        } else {
            CHECK(stoppedForOps(env));
        }
    }
}

/// An element's first inline style is one operation however many properties it gets, as upstream sends the new style
/// attribute whole (style.ts, capture.ts): 10,000 elements given four properties each in one task run, 10,001 stop.
WR_TEST(testAFirstInlineStyleIsOneOperation) {
    for (const int count : {10000, 10001}) {
        RenderEnv env(kPage);
        fillBox(env, count);
        env.env().eval("setTimeout(() => { let i = 0; for (const e of box.children) { e.style.left = i + 'px'; e.style.top = i + 'px';"
                       " e.style.setProperty('opacity', '0.5'); e.style.color = 'red'; i++; } }); 1");
        env.env().drain();
        if (count == 10000) {
            CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        } else {
            CHECK(stoppedForOps(env));
        }
    }
}

/// A Text swapped out by a relabel is a new node when it is put back somewhere (capture.ts: reuseSoleText across
/// flushes; in one flush each new text is new anyway): 5,001 relabels, each putting the old text into #box, are 10,003
/// operations.
WR_TEST(testASwappedOutTextIsANewNode) {
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 5001; i++) { const t = p.firstChild; p.textContent = 'v' + i; box.appendChild(t); } }); 1");
    env.env().drain();
    CHECK(stoppedForOps(env));
}

/// Nodes put in through a fragment count as inserted once, as upstream's shim never sees the fragment: 5,000 new
/// elements appended at once (append, replaceChildren) are their 10,000 insertions and run; 5,001 stop.
WR_TEST(testAFragmentsNodesCountOnce) {
    for (const char* insert : {"box.append(...rows)", "box.replaceChildren(...rows)"}) {
        for (const int count : {5000, 5001}) {
            RenderEnv env(kPage);
            env.env().eval("setTimeout(() => { const rows = []; for (let i = 0; i < " + std::to_string(count) +
                           "; i++) rows.push(document.createElement('i')); " + insert + "; }); 1");
            env.env().drain();
            if (count == 5000) {
                CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
                CHECK_EQ(env.env().eval("String(box.children.length)"), std::string("5000"));
            } else {
                CHECK(stoppedForOps(env));
            }
        }
    }
}

/// A node that comes back into the document from a detached holder in a later batch counts one: 10,001 of them, put in
/// a holder over three tasks, then all put back in one, stop (upstream: two per node and its text, past it at 2,501).
WR_TEST(testNodesBackFromADetachedHolderCountOneEach) {
    RenderEnv env(kPage);
    fillBox(env, 10001);
    env.env().eval("window.h = document.createElement('div');"
                   " for (let t = 0; t < 3; t++) setTimeout(() => { for (const e of [...box.children].slice(0, 3400)) h.appendChild(e); }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK_EQ(env.env().eval("String(h.children.length)"), std::string("10001"));
    env.env().eval("setTimeout(() => { for (const e of [...h.children]) box.appendChild(e); }); 1");
    env.env().drain();
    CHECK(stoppedForOps(env));
}

/// Distinct relabels and moves count one each: 10,002 of either in one task stop (a reversal is one fewer upstream, whose
/// diff leaves the last child in place).
WR_TEST(testDistinctRelabelsAndMovesStop) {
    for (const char* change : {"for (const e of [...box.children]) e.textContent = 'y'", "for (const e of [...box.children].reverse()) box.appendChild(e)"}) {
        RenderEnv env(kPage);
        fillBox(env, 10002);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        env.env().eval(std::string("setTimeout(() => { ") + change + "; }); 1");
        env.env().drain();
        CHECK(stoppedForOps(env));
    }
}

/// A node's state travels with it in its first batch: 3,334 elements appended and then given a class, an attribute and
/// an inline style are their 6,668 insertions only. (A text made for one is a node of its own, upstream's too.)
WR_TEST(testANodesFirstBatchCarriesItsState) {
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 3334; i++) { const e = document.createElement('i'); box.appendChild(e);"
                   " e.className = 'c'; e.setAttribute('data-n', String(i)); e.style.left = i + 'px'; } }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

/// A move is one operation, as upstream's single `ins`: 6,000 children re-appended in reverse order, and taken out and
/// put back, in one task.
WR_TEST(testAMoveCountsOne) {
    for (const char* move : {"box.appendChild(kids[i])", "box.removeChild(kids[i]); box.appendChild(kids[i])"}) {
        RenderEnv env(kPage);
        fillBox(env, 6000);
        env.env().eval("window.kidsBefore = [...box.children]; 1");
        env.env().eval(std::string("setTimeout(() => { const kids = [...box.children].reverse(); for (let i = 0; i < kids.length; i++) { ") +
                       move + "; } }); 1");
        env.env().drain();
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK_EQ(env.env().eval("box.children.length + ':' + (box.firstChild === kidsBefore.at(-1))"), std::string("6000:true"));
    }
}

/// A sole text replaced by a new one (textContent, replaceChildren with a string) is one `data` operation upstream
/// (capture.ts reuseSoleText): 6,000 labels relabelled in one task run; the DOM still gets a new Text node.
WR_TEST(testRelabellingASoleTextCountsOne) {
    for (const char* relabel : {"e.textContent = 'y' + i", "e.replaceChildren('y' + i)"}) {
        RenderEnv env(kPage);
        fillBox(env, 6000);
        env.env().eval("window.firstText = box.firstChild.firstChild; 1");
        env.env().eval(std::string("setTimeout(() => { let i = 0; for (const e of box.children) { ") + relabel + "; i++; } }); 1");
        env.env().drain();
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK_EQ(env.env().eval("(box.firstChild.firstChild !== firstText) + ':' + box.lastChild.textContent"),
                 std::string("true:y5999"));
    }
}

/// The parse's batch: a document of 4,000 parsed elements boots.
WR_TEST(testALargeParsedDocumentBoots) {
    std::string body;
    for (int i = 0; i < 4000; i++) {
        body += "<i></i>";
    }
    RenderEnv env("<!doctype html><html><head></head><body>" + body + "</body></html>");
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    CHECK(env.render().layerTree() != nullptr);
}

/// Compat has no batch cap.
WR_TEST(testCompatHasNoBatchCap) {
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kPage);
    env.env().eval("setTimeout(() => { for (let i = 0; i < 20000; i++) box.appendChild(document.createElement('i')); }); 1");
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}
