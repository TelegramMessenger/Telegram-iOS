// The corpus and attack gates (M1c plan, Task 11). Every non-attack corpus document is booted with a render tree at width
// 360, run to idle and through one virtual second, and flushed; the 105 attack documents are booted, run a virtual second
// and flushed, and may load nothing. The gates:
// - the render layer never makes a document stop that does not stop without it;
// - the build path (litehtml's own parse of the render input) and the mirror (Task 10b) paint what the published
//   document paints;
// - a widget's image loads reach the container, which refuses every URL, and the host only ever gets decoded bytes.
// Each step runs in the harness's slice on its fake clock, which stops only a runaway. Run with WR_CORPUS_FILES set (the
// Bazel target does).
#include <malloc/malloc.h>
#include <pthread.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include <litehtml.h>
#include <litehtml/telegram_master_css.h>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/Profile.h"
#include "Sources/Render/Builder.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderCut.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/WidgetContainer.h"
#include "Sources/Support/Errors.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"
#include "Tests/VirtualTime.h"

namespace {

using wr_test::RenderEnv;

constexpr double kWidth = 360;

std::vector<std::string> corpusFiles(bool attacks) {
    std::vector<std::string> files;
    const char* list = std::getenv("WR_CORPUS_FILES");
    std::istringstream paths(list ? list : "");
    std::string path;
    while (paths >> path) {
        if ((path.find("/attacks/") != std::string::npos) == attacks) {
            files.push_back(path);
        }
    }
    std::sort(files.begin(), files.end());
    return files;
}

std::string readFile(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::stringstream s;
    s << in.rdbuf();
    return s.str();
}

std::string shortName(const std::string& file) {
    const size_t at = file.find("corpus/");
    return at == std::string::npos ? file : file.substr(at + 7);
}

const char* stopName(wr::StopReason reason) {
    switch (reason) {
    case wr::StopReason::None: return "-";
    case wr::StopReason::Memory: return "memory";
    case wr::StopReason::Internal: return "internal";
    case wr::StopReason::LayoutQuery: return "layout-query";
    case wr::StopReason::Limit: return "limit";
    case wr::StopReason::Cpu: return "cpu";
    }
    return "?";
}

/// Boot (to idle at time 0) then one virtual second. Returns false when a drive ran out of steps.
bool run(wr_test::HostEnv& env) {
    wr_test::DriveEnd boot = wr_test::driveVirtualTime(env, 0, {}, 1000000);
    if (boot == wr_test::DriveEnd::StepLimit) {
        return false;
    }
    if (env.runtime().stopReason() == wr::StopReason::None) {
        if (wr_test::driveVirtualTime(env, 1000, {}, 1000000) == wr_test::DriveEnd::StepLimit) {
            return false;
        }
    }
    return true;
}

/// The runtime's boot with no render tree: the control run, and the CPU time the parse alone takes.
struct PlainRun {
    wr::StopReason stop = wr::StopReason::None;
    double bootCpuMs = 0;
};

PlainRun runWithoutTree(const std::string& html) {
    PlainRun result;
    wr::BootOptions boot;
    boot.html = html;
    const double start = wr_test::threadCpuMs();
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(boot, 1);
    result.bootCpuMs = wr_test::threadCpuMs() - start;
    run(*env);
    result.stop = env->runtime().stopReason();
    return result;
}

/// Whether the render input survives a re-parse: DOMEnv(input)'s document element serializes to what follows the
/// input's doctype.
bool survivesReparse(const std::string& input) {
    static const std::string kDoctype = "<!doctype html>";
    if (input.compare(0, kDoctype.size(), kDoctype) != 0) {
        return false;
    }
    wr_test::DOMEnv dom(input);
    const std::string outer = dom.eval("document.documentElement.outerHTML");
    return outer == input.substr(kDoctype.size());
}

size_t firstDifference(const std::string& a, const std::string& b) {
    size_t at = 0;
    while (at < a.size() && at < b.size() && a[at] == b[at]) {
        at++;
    }
    return at;
}

/// The first differing line of two dumps, with 2 lines before it and 3 after, each side cut to 260 columns.
std::string lineDifference(const std::string& a, const std::string& b) {
    auto split = [](const std::string& text) {
        std::vector<std::string> lines;
        std::istringstream in(text);
        for (std::string line; std::getline(in, line);) {
            lines.push_back(line.substr(0, 260));
        }
        return lines;
    };
    const std::vector<std::string> x = split(a), y = split(b);
    size_t at = 1;   // the header holds the item count
    while (at < x.size() && at < y.size() && x[at] == y[at]) {
        at++;
    }
    std::string out = "    first differing line " + std::to_string(at) + " of " + std::to_string(x.size()) + " / " +
                      std::to_string(y.size()) + "\n";
    for (size_t i = at > 2 ? at - 2 : 0; i < at + 4; i++) {
        out += "    mirror| " + (i < x.size() ? x[i] : std::string("<end>")) + "\n    record| " +
               (i < y.size() ? y[i] : std::string("<end>")) + "\n";
    }
    return out;
}

/// Profile 1's image types, and the 48 px placeholder's image/svg+xml (V4 plan, Task 6): the host is handed nothing else.
bool onlyImageTypes(const wr_test::FakeRenderHost& host) {
    for (const std::string& type : host.decodedMimeTypes) {
        if (!wr::profile::contains(wr::profile::CSSTable::ImageTypes, type) && type != "image/svg+xml") {
            return false;
        }
    }
    return host.foreignSVGs == 0;
}

size_t heapInUse() {
    malloc_statistics_t stats{};
    malloc_zone_statistics(nullptr, &stats);
    return stats.size_in_use;
}

template <class T>
T percentile(std::vector<T> v, double p) {
    if (v.empty()) {
        return T();
    }
    std::sort(v.begin(), v.end());
    return v[std::min(v.size() - 1, size_t(p * double(v.size())))];
}

} // namespace

WR_TEST(testCorpusRenders) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    const std::vector<std::string> files = corpusFiles(false);
    CHECK(files.size() >= 200);
    std::vector<std::string> stopped, stopsOnlyWithTree, skipped, emptyTree, nonImage, buildMismatch, mirrorMismatch;
    std::vector<double> firstFlush;
    size_t parityChecked = 0;
    size_t maxStyleCharge = 0, totalStyleCharge = 0;
    std::string maxStyleFile;
    std::vector<std::string> styleBytesHit;
    // Profile 1's strict text and node limits (V4 plan, Task 7): no honest document reaches one.
    std::vector<std::string> textLimitsHit;
    for (const std::string& file : files) {
        const std::string name = shortName(file);
        const std::string html = readFile(file);
        wr::RenderOptions options;
        options.width = kWidth;
        const double start = wr_test::threadCpuMs();
        RenderEnv env(html, options, false);
        const double afterBoot = wr_test::threadCpuMs();
        const bool finished = run(env.env());
        if (!finished) {
            std::printf("  %s: a drive ran out of steps\n", name.c_str());
        }
        CHECK(finished);
        try {
            env.render().flushForQuery(env.ctx());
        } catch (const wr::Aborted&) {
        }
        const wr::StopReason stop = env.env().runtime().stopReason();
        CHECK(stop == wr::StopReason::None || stop == wr::StopReason::Cpu);
        if (stop != wr::StopReason::None) {
            stopped.push_back(name + " (" + stopName(stop) + ")");
        }

        // A build's first publish is Inserts that replay into its tree (a fresh tree over the document as it ends).
        if (stop == wr::StopReason::None) {
            wr::RenderTree fresh(env.ctx(), env.host(), env.render().options());
            fresh.build(env.ctx());
            const std::string why = wr_test::insertsMismatch(*fresh.layerTree(), fresh.layerOps());
            if (!why.empty()) {
                std::printf("  %s: a build's publish: %s\n", name.c_str(), why.c_str());
            }
            CHECK(why.empty());
        }

        // The control: the same document with no render tree.
        const PlainRun plain = runWithoutTree(html);
        if (stop != wr::StopReason::None && plain.stop == wr::StopReason::None) {
            stopsOnlyWithTree.push_back(name + " (" + stopName(stop) + ")");
        }
        // The first flush runs inside the boot after the parse, scripts queued; the control's boot is the parse alone.
        const double flushCpuMs = std::max(0.0, afterBoot - start - plain.bootCpuMs);
        firstFlush.push_back(flushCpuMs);

        // Edit 21: the style-byte budget. No corpus file may reach it.
        if (env.render().document()) {
            const size_t charge = env.render().document()->style_bytes_charged();
            totalStyleCharge += charge;
            if (charge > maxStyleCharge) {
                maxStyleCharge = charge;
                maxStyleFile = name;
            }
        }
        for (const std::string& limit : env.render().renderLimits()) {
            if (limit == "style-bytes") {
                styleBytesHit.push_back(name);
            }
            if (limit == "text-node" || limit == "text-budget" || limit == "nodes") {
                textLimitsHit.push_back(name + " (" + limit + ")");
            }
        }

        // Animations are render-only (V5e, V5f): their values reach litehtml in the "animated style" attribute, which no
        // markup can carry, so the parity gates below compare the page without them: cancelled, then flushed.
        if (env.env().eval("document.getAnimations().length") != "0") {
            env.env().eval("document.getAnimations().forEach(a => a.cancel()); 1");
            try {
                env.render().flushForQuery(env.ctx());
            } catch (const wr::Aborted&) {
            }
        }

        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const bool nonEmpty = tree && !tree->root().entries.empty();
        if (!nonEmpty) {
            emptyTree.push_back(name);
        }
        if (!onlyImageTypes(env.host())) {
            nonImage.push_back(name);
        }

        // Parity, where the render input is one a re-parse reproduces.
        bool parity = false;
        if (tree && env.render().document()) {
            const std::string input = env.render().renderInput();
            parity = survivesReparse(input);
            if (!parity) {
                skipped.push_back(name);
            } else {
                parityChecked++;
                // Build path: litehtml's own parse of the render input lays out as the built document.
                // litehtml reads the mode from the markup's doctype, and the render input always opens with a no-quirks
                // one: a quirks document (most of the corpus has no doctype) is parsed without it, as the document was.
                const bool quirks = env.env().eval("document.compatMode") == "BackCompat";
                const std::string parseInput = quirks ? input.substr(std::string("<!doctype html>").size()) : input;
                wr::WidgetContainer container(env.host(), env.render().options());
                std::string theirs;
                {
                    // The root's declarations (twidget edit 26: the theme's and the content safe area's), which the UA
                    // layer's values read, as a user rule on the root: a parse cannot set them before it finalizes.
                    litehtml::document::ptr parsed = litehtml::document::createFromString(
                        litehtml::estring(parseInput), &container, wr::masterWithHostCSS(env.render().options().hostCSS),
                        "html{" + wr::rootDeclarationsOf(env.render().options()) + "}");
                    parsed->render(litehtml::pixel_t(float(env.render().options().width)));
                    theirs = wr::dumpLayout(*parsed);
                }
                const std::string ours = env.render().layoutDump();
                if (ours != theirs) {
                    const size_t at = firstDifference(ours, theirs);
                    const size_t from = at > 200 ? at - 200 : 0;
                    std::printf("  %s: the build path differs at byte %zu\n  built: %s\n  parsed: %s\n", name.c_str(), at,
                                ours.substr(from, 600).c_str(), theirs.substr(from, 600).c_str());
                    buildMismatch.push_back(name);
                }
                // Mirror: the published tree flattens as record() paints, normalised.
                std::shared_ptr<const wr::LayerTree> recorded = env.render().recordForTesting();
                if (!recorded || !tree->mirror()) {
                    std::printf("  %s: no mirror or no record\n", name.c_str());
                    mirrorMismatch.push_back(name);
                } else {
                    // Both sides normalised: a clipper whose clip holds nothing painted keeps its node (and so its set-clip/del-clip
                    // pair) in the mirror, as record() draws one, and E37 drops such pairs from the oracle for the same reason.
                    const std::string mine = wr_test::normalized(*tree)->dump();
                    const std::string oracle = wr_test::normalized(*recorded)->dump();
                    if (mine != oracle) {
                        std::printf("  %s: the mirror flattens differently\n%s", name.c_str(), lineDifference(mine, oracle).c_str());
                        mirrorMismatch.push_back(name);
                    }
                }
            }
        }
        std::printf("%10.3f CPU ms  %4llu refused  %s%s\n", flushCpuMs,
                    (unsigned long long)env.render().refusedLoads(), name.c_str(), parity ? "" : "  (parity skipped)");
    }

    auto list = [](const char* title, const std::vector<std::string>& names) {
        std::printf("\n%s: %zu\n", title, names.size());
        for (const std::string& n : names) {
            std::printf("  %s\n", n.c_str());
        }
    };
    list("documents that stopped", stopped);
    list("documents that stop only with the render tree", stopsOnlyWithTree);
    list("documents with an empty layer tree", emptyTree);
    list("documents whose render input a re-parse does not reproduce (parity skipped; counted for Task 12)", skipped);
    std::printf("\nstyle bytes: the corpus maximum charge is %zu (%s), its total %zu over %zu documents; the budget is %zu\n",
                maxStyleCharge, maxStyleFile.c_str(), totalStyleCharge, files.size(), size_t(litehtml::document::max_style_bytes));
    list("documents that hit the style-byte budget", styleBytesHit);
    CHECK(styleBytesHit.empty());
    list("documents that hit profile 1's text or node limits", textLimitsHit);
    for (const std::string& hit : textLimitsHit) {
        CHECK(hit.starts_with("attacks/"));
    }
    std::printf("\nparity checked on %zu of %zu documents\n", parityChecked, files.size());
    std::printf("first flush: median %.3f CPU ms, p90 %.3f, max %.3f\n", percentile(firstFlush, 0.5), percentile(firstFlush, 0.9),
                percentile(firstFlush, 1.0));
    // Nothing is skipped silently: a document that cannot survive a re-parse must be named in an explicit list, with its
    // reason, before it may skip parity. Today there is none.
    CHECK(skipped.empty());
    CHECK_EQ(parityChecked, files.size());
    CHECK(stopsOnlyWithTree.empty());
    CHECK(emptyTree.empty());
    CHECK(nonImage.empty());
    CHECK(buildMismatch.empty());
    CHECK(mirrorMismatch.empty());
}

// The cut walk (RenderCut.h) over every corpus document, the attacks included, after its boot: it finds no node that
// differs from the build and posts the build's limits.
WR_TEST(testTheCutWalkAgreesOverTheCorpus) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    std::vector<std::string> files = corpusFiles(false);
    const std::vector<std::string> attacks = corpusFiles(true);
    files.insert(files.end(), attacks.begin(), attacks.end());
    CHECK(files.size() >= 200 && !attacks.empty());
    size_t walked = 0;
    std::vector<std::string> differ;
    for (const std::string& file : files) {
        wr::RenderOptions options;
        options.width = kWidth;
        RenderEnv env(readFile(file), options, false);
        try {
            env.render().flushForQuery(env.ctx());
        } catch (const wr::Aborted&) {
        }
        if (env.env().runtime().stopReason() != wr::StopReason::None || !env.render().document()) {
            continue;
        }
        const wr::RenderBuild& built = env.render().publishedBuild();
        const wr::RenderCutDiff diff = wr::renderCutDiff(env.ctx(), env.render().container(), built, {});
        walked++;
        if (!diff.nodes.empty() || diff.limits != built.limits || diff.end.bytes != built.bytes ||
            diff.end.elements != built.elementCount || diff.end.nodes != built.nodeCount) {
            differ.push_back(shortName(file) + " (" + std::to_string(diff.nodes.size()) + " nodes)");
        }
    }
    std::printf("  the cut walk over %zu documents; %zu differ from their build\n", walked, differ.size());
    for (const std::string& name : differ) {
        std::printf("    %s\n", name.c_str());
    }
    CHECK(walked >= 200);
    CHECK(differ.empty());
}

WR_TEST(testDeclarationAmplificationIsMeasured) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    // Ruling E13: litehtml copies each declaration's tokens into every element's style, so a large value applied to many
    // elements multiplies. Printed, never asserted on size: the fix is the owner's decision. Each case must build.
    constexpr int kElements = 9000;
    std::string elements;
    for (int i = 0; i < kElements; i++) {
        elements += "<b></b>";
    }
    std::string fonts = "font-family:";
    for (int i = 0; i < 40; i++) {
        fonts += (i ? "," : "") + std::string("Family") + std::to_string(i);
    }
    auto repeated = [](const std::string& unit, size_t bytes) {
        std::string out;
        while (out.size() < bytes) {
            out += unit;
        }
        return out;
    };
    const std::string ff = repeated("aa,", 16 * 1024);
    const std::string tr = repeated("color 1s,", 16 * 1024);
    std::string chain = ":root{--a0:" + ff + "}";
    for (int i = 1; i <= 10; i++) {
        chain += ":root{--a" + std::to_string(i) + ":var(--a" + std::to_string(i - 1) + ") var(--a" + std::to_string(i - 1) + ")}";
    }
    std::string inlineElements;
    for (int i = 0; i < kElements; i++) {
        inlineElements += "<b style='--y:var(--x)'></b>";
    }
    std::string tenThousand;
    for (int i = 0; i < 10000; i++) {
        tenThousand += "<b></b>";
    }
    const struct {
        const char* name;
        std::string css;
        std::string markup;
    } cases[] = {
        {"none (baseline)", "", elements},
        {"16 KiB content on *::before", "*::before { content: \"" + std::string(16 * 1024, 'x') + "\" }", elements},
        {"40-entry font-family on *", "* { " + fonts + " }", elements},
        {"16 KiB --x custom property on *", "* { --x: " + std::string(16 * 1024, 'x') + " }", elements},
        // Ruling E47: a var() splice copies the value onto each element.
        {"var: --y:var(--x) on *", ":root{--x:" + ff + "} *{--y:var(--x)}", elements},
        {"var: transition:var(--x) on *", ":root{--x:" + tr + "} *{transition:var(--x)}", elements},
        {"var: font-family:var(--x) on *", ":root{--x:" + ff + "} *{font-family:var(--x)}", elements},
        {"var: inline style --y:var(--x)", ":root{--x:" + ff + "}", inlineElements},
        {"var: 10-level doubling chain", chain + "*{--z:var(--a10)}", elements},
        // An unresolved var() leaves a token list, not a string: the element inherits the parent's string, cut at 1 KiB.
        {"inherited: cursor var(--nope), 60 KiB, 10,000 elements",
         "html{cursor:" + std::string(60 * 1024, 'a') + "} *{cursor:var(--nope)}", tenThousand},
    };
    size_t baseline = 0;
    for (const auto& c : cases) {
        const std::string html = "<!doctype html><style>" + c.css + "</style><body>" + c.markup + "</body>";
        const size_t before = heapInUse();
        {
            RenderEnv env(html);
            try {
                env.render().flushForQuery(env.ctx());
            } catch (const wr::Aborted&) {
            }
            const size_t grown = heapInUse() - before;
            const size_t charged = env.render().document() ? env.render().document()->style_bytes_charged() : 0;
            const bool built = env.render().layerTree() && env.render().buildCount() >= 1 &&
                               env.render().layoutDump().size() > size_t(kElements);
            if (!built) {
                std::printf("  %s: nothing was built (stop %s)\n", c.name, stopName(env.env().runtime().stopReason()));
            }
            CHECK(built);
            if (baseline == 0) {
                baseline = grown;
            }
            // Edit 21: the style-byte budget bounds what a declaration can multiply, whatever the declaration. Past it the
            // elements get no more author declarations, so growth over the baseline stays within twice the budget (the
            // charge counts the values copied onto elements; the base-style snapshot and the cut elements' rest are the
            // other half).
            if (std::string(c.name).rfind("var:", 0) == 0) {
                size_t posts = 0;
                for (const std::string& limit : env.render().renderLimits()) {
                    posts += limit == "style-bytes" ? 1 : 0;
                }
                CHECK_EQ(posts, size_t(1));
            }
            if (grown > baseline) {
                CHECK(double(grown - baseline) < 2.0 * double(litehtml::document::max_style_bytes));
            }
            std::printf("  style bytes charged: %zu\n", charged);
            std::printf("amplification: %-34s heap grew %8.1f MB (%+.1f MB over the baseline); %d elements; stop %s\n", c.name,
                        double(grown) / 1048576, (double(grown) - double(baseline)) / 1048576, kElements,
                        stopName(env.env().runtime().stopReason()));
        }
    }
}

WR_TEST(testPlainDocumentStyleCharge) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    // Edit 21's measurement: what a plainly styled 10,000-element document charges (it sizes the budget).
    const std::string css =
        "* { margin:0; padding:0; box-sizing:border-box }"
        "body { font-family:-apple-system,Helvetica,Arial,sans-serif; font-size:14px; color:#222; line-height:1.4 }"
        "div { display:block; background:#fff; border:1px solid #ddd; padding:4px 8px; margin:2px; border-radius:4px }"
        "span { color:#555; font-weight:600; font-family:Georgia,serif; text-transform:uppercase }";
    std::string elements;
    for (int i = 0; i < 5000; i++) {
        elements += "<div><span></span></div>";
    }
    RenderEnv env("<!doctype html><style>" + css + "</style><body>" + elements + "</body>");
    try {
        env.render().flushForQuery(env.ctx());
    } catch (const wr::Aborted&) {
    }
    CHECK(env.render().document() != nullptr);
    if (env.render().document()) {
        std::printf("plain 10,000-element document: %zu style bytes charged\n", env.render().document()->style_bytes_charged());
    }
    for (const std::string& limit : env.render().renderLimits()) {
        CHECK(limit != "style-bytes");
    }
}

WR_TEST(testAttackCorpusLoadsNothing) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    const std::vector<std::string> files = corpusFiles(true);
    CHECK_EQ(files.size(), size_t(110));
    std::set<std::string> seen;
    for (const std::string& file : files) {
        const std::string name = shortName(file);
        wr::RenderOptions options;
        options.width = kWidth;
        RenderEnv env(readFile(file), options, false);
        bool finished = wr_test::driveVirtualTime(env.env(), 1000, {}, 1000000) != wr_test::DriveEnd::StepLimit;
        CHECK(finished);
        try {
            env.render().flushForQuery(env.ctx());
        } catch (const wr::Aborted&) {
        }
        const bool images = onlyImageTypes(env.host());
        CHECK(images);
        const uint64_t refused = env.render().refusedLoads();
        std::printf("%4llu refused  %2zu decoded  %-8s %s%s\n", (unsigned long long)refused,
                    env.host().decodedMimeTypes.size(), stopName(env.env().runtime().stopReason()), name.c_str(),
                    images ? "" : "  NON-IMAGE DECODE");
        seen.insert(name);
        const std::string leaf = name.substr(name.rfind('/') + 1);
        // V4 plan, Task 3b: profile 1 drops a remote url() declaration before litehtml asks for anything.
        if (leaf == "css-background-url.html") {
            CHECK_EQ(refused, uint64_t(0));
            CHECK(env.host().decodedMimeTypes.empty());
        }
        // V4 plan, Task 6: a planted image URL never reaches litehtml; the <img> renders the 48 px placeholder.
        if (leaf == "markup-img-src.html" || leaf == "api-setattribute-src.html") {
            const bool planted = env.render().renderInput().find("127.0.0.1") != std::string::npos;
            if (planted || refused != 0) {
                std::printf("  %s: a planted URL reached the renderer (%llu refused)\n", name.c_str(), (unsigned long long)refused);
            }
            CHECK(!planted);
            CHECK_EQ(refused, uint64_t(0));
        }
        if (leaf == "markup-svg-image.html") {
            // The brief expects the nested data: SVG to reach decodeImage as image/svg+xml. The fork's svg painter never
            // loads an <image> (el_svg.cpp skips "image" in its cache walks and paints no raster), so nothing reaches the
            // host: recorded here and reported for M1d (the host's SVG renderer owns whether an inner http image could
            // load). What stays asserted is that no URL is loaded and nothing but image bytes was decoded.
            const auto& types = env.host().decodedMimeTypes;
            const bool svg = std::find(types.begin(), types.end(), "image/svg+xml") != types.end();
            std::printf("  %s: the nested data: SVG %s decodeImage as image/svg+xml (%zu decodes, %llu refused loads)\n",
                        name.c_str(), svg ? "reached" : "did NOT reach", types.size(), (unsigned long long)refused);
        }
    }
    for (const char* leaf : {"markup-img-src.html", "css-background-url.html", "api-setattribute-src.html", "markup-svg-image.html"}) {
        bool found = false;
        for (const std::string& n : seen) {
            found = found || (n.size() >= std::string(leaf).size() &&
                             n.compare(n.size() - std::string(leaf).size(), std::string::npos, leaf) == 0);
        }
        CHECK(found);
    }
}
