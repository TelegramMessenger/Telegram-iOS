// The headless WPT runner (M1b plan, Task 17; spec section 9 item 3). Every vendored testharness page in kDirs that
// wpt-skip.txt does not list is booted with wr::boot on a virtual clock, with the harness's report replaced by
// wpt-report.js. Each page runs until the harness completes, until its harness timeout (10 s, or 60 s for a long
// test) plus a second of grace has passed in virtual time, or until it stops (each step runs in the harness's slice on
// its fake clock, which stops a runaway). The results are compared with wpt-expectations.txt, which only ratchets up.
//
//   ./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWPTTests
//   ./build-input/bazel-9.2.0-darwin-arm64 run //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWPTTests -- --update
//
// Flags:
//   --update               write the results to wpt-expectations.txt. Under `bazel run` that is the file in the source
//                          tree; under `bazel test`, the test's undeclared outputs.
//   --allow-regressions    let --update lower a result.
//   --filter=<text>        run only the tests whose key contains <text>, and compare only those.
//   --verbose              print every page's diagnostics, not only those of a page whose harness status is not OK.
//
// A page that crashes the process is named by the last "RUN" line printed. Under a page whose harness status is not
// OK, the runner prints what the host was told (script-skipped, uncaught-exception, …) and the srcs the loader
// refused, so a helper that failed to load states why.
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <vector>

#include "Tests/HostHarness.h"
#include "Tests/VirtualTime.h"
#include "Tests/WPT/WPTSupport.h"

namespace {

constexpr double kNormalTimeoutMs = 10000;
constexpr double kLongTimeoutMs = 60000;
constexpr double kGraceMs = 1000;
constexpr uint64_t kMaxSteps = 1000000;
/// The most diagnostic lines printed for one page, and the most bytes of each.
constexpr size_t kMaxDiagnosticLines = 20;
constexpr size_t kMaxDiagnosticBytes = 200;
constexpr const char* kExpectationsInSource = "submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/wpt-expectations.txt";

const std::vector<std::string> kDirs = {
    "dom/nodes",
    "dom/events",
    "dom/collections",
    "dom/lists",
    "html/webappapis/timers",
    "html/webappapis/microtask-queuing",
    "html/webappapis/animation-frames",
    "html/webappapis/scripting/event-loops",
    // The inline style declaration block (element.style).
    "css/cssom",
    // Web Animations (V5e plan, Task 5): the API and the timing model.
    "web-animations/interfaces",
    "web-animations/timing-model",
    // CSS animations' and transitions' event interfaces (V5f plan, Task 8): the pages that need no rendering, as the
    // runner installs none.
    "css/css-animations",
    "css/css-transitions",
};

struct Options {
    bool update = false;
    bool allowRegressions = false;
    std::string filter;
    bool verbose = false;
};

/// What wpt-report.js reported for the page running.
struct Report {
    bool done = false;
    int harness = -1;
    std::string harnessMessage;
    std::vector<std::pair<std::string, int>> subtests;
    std::vector<std::string> messages;
};
Report* g_report = nullptr;

std::string stringArg(JSContext* ctx, int argc, JSValueConst* argv, int i) {
    if (i >= argc) {
        return {};
    }
    const char* s = JS_ToCString(ctx, argv[i]);
    std::string out = s ? s : "";
    JS_FreeCString(ctx, s);
    return out;
}

int intArg(JSContext* ctx, int argc, JSValueConst* argv, int i) {
    int32_t v = -1;
    if (i < argc) {
        JS_ToInt32(ctx, &v, argv[i]);
    }
    return v;
}

JSValue wptSubtest(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    if (g_report && !g_report->done) {
        g_report->subtests.emplace_back(stringArg(ctx, argc, argv, 0), intArg(ctx, argc, argv, 1));
        g_report->messages.push_back(stringArg(ctx, argc, argv, 2));
    }
    return JS_UNDEFINED;
}

JSValue wptDone(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    if (g_report && !g_report->done) {
        g_report->harness = intArg(ctx, argc, argv, 0);
        g_report->harnessMessage = stringArg(ctx, argc, argv, 1);
        g_report->done = true;
    }
    return JS_UNDEFINED;
}

std::string dirnameOf(const std::string& path) {
    size_t slash = path.rfind('/');
    return slash == std::string::npos ? std::string(".") : path.substr(0, slash);
}

/// `path` with every symlink resolved, or "" when it does not resolve. Bazel's runfiles tree is made of symlinks to
/// the source files, and readFile and the loader serve regular files only.
std::string realPath(const std::string& path) {
    std::error_code ec;
    std::filesystem::path real = std::filesystem::canonical(path, ec);
    return ec ? std::string() : real.string();
}

/// The vendored root: the directory of the LICENSE.md the BUILD passes, or third-party/wpt under the runfiles, as the
/// real directory its LICENSE.md resolves to (the tree's files are regular there).
std::string findRoot() {
    std::vector<std::string> candidates;
    if (const char* license = std::getenv("WR_WPT_LICENSE")) {
        candidates.push_back(dirnameOf(license));
    }
    candidates.push_back("third-party/wpt");
    for (const char* var : {"TEST_SRCDIR", "RUNFILES_DIR"}) {
        if (const char* dir = std::getenv(var)) {
            candidates.push_back(std::string(dir) + "/_main/third-party/wpt");
        }
    }
    for (const std::string& candidate : candidates) {
        std::string license = realPath(candidate + "/LICENSE.md");
        if (!license.empty()) {
            std::string root = dirnameOf(license);
            if (wr_wpt::readFile(root + "/LICENSE.md")) {
                return root;
            }
        }
    }
    return {};
}

std::string runfile(const char* variable, const char* fallback) {
    const char* path = std::getenv(variable);
    return path ? std::string(path) : std::string(fallback);
}

/// One of the runner's own inputs (the shim, the skip list, the expectations), through its runfiles symlink.
std::optional<std::string> readInput(const std::string& path) {
    std::string real = realPath(path);
    return real.empty() ? std::nullopt : wr_wpt::readFile(real);
}

struct PageResult {
    std::vector<wr_wpt::Record> records;
    std::map<std::string, std::string> messages;  // subtest -> message, for non-passing subtests
    /// The host's diagnostics ("<kind>: <detail>"), then the srcs the loader refused for this page, in order.
    std::vector<std::string> diagnostics;
    double cpuMs = 0;
    double virtualMs = 0;
    std::string end;
};

PageResult runPage(const wr_wpt::Page& page, wr_wpt::WPTLoader& loader, const Options& options) {
    Report report;
    g_report = &report;
    loader.setPageURL(page.url);
    size_t refusedBefore = loader.refused().size();
    wr::BootOptions boot;
    boot.html = page.html;
    boot.url = page.url;
    const double start = wr_test::threadCpuMs();
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(boot, 1, [&](wr_test::HostEnv& e) {
        JSContext* ctx = e.ctx();
        e.host().loader = &loader;
        e.runtime().setGlobal("__wptSubtest", JS_NewCFunction(ctx, wptSubtest, "__wptSubtest", 3));
        e.runtime().setGlobal("__wptDone", JS_NewCFunction(ctx, wptDone, "__wptDone", 2));
    });
    double limit = (page.longTimeout ? kLongTimeoutMs : kNormalTimeoutMs) + kGraceMs;
    wr_test::DriveEnd end = wr_test::driveVirtualTime(*env, limit, [&] { return report.done; }, kMaxSteps);

    PageResult result;
    result.cpuMs = wr_test::threadCpuMs() - start;
    result.virtualMs = env->host().now;
    result.end = wr_test::driveEndName(end);
    wr_wpt::Record harness{page.test, true, "", ""};
    if (report.done) {
        harness.status = wr_wpt::harnessStatusName(report.harness);
        std::map<std::string, int> seen;
        for (size_t i = 0; i < report.subtests.size(); i++) {
            std::string name = report.subtests[i].first;
            int count = ++seen[name];
            if (count > 1) {
                name += " (" + std::to_string(count) + ")";
            }
            std::string status = wr_wpt::subtestStatusName(report.subtests[i].second);
            if (status != "PASS") {
                result.messages[name] = report.messages[i];
            }
            result.records.push_back({page.test, false, name, status});
        }
    } else {
        harness.status = end == wr_test::DriveEnd::Stopped ? "STOPPED" : "NOCOMPLETE";
    }
    if (!report.harnessMessage.empty()) {
        result.messages[std::string(wr_wpt::kHarness)] = report.harnessMessage;
    }
    result.records.insert(result.records.begin(), harness);
    for (const auto& [kind, detail] : env->host().diagnostics) {
        result.diagnostics.push_back(kind + ": " + detail.substr(0, kMaxDiagnosticBytes));
    }
    for (size_t i = refusedBefore; i < loader.refused().size(); i++) {
        result.diagnostics.push_back("loader refused: " + loader.refused()[i].substr(0, kMaxDiagnosticBytes));
    }
    g_report = nullptr;
    return result;
}

bool writeText(const std::string& path, const std::string& text) {
    std::ofstream out(path, std::ios::binary | std::ios::trunc);
    out << text;
    return bool(out);
}

} // namespace

int main(int argc, char** argv) {
    Options options;
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--update") {
            options.update = true;
        } else if (arg == "--allow-regressions") {
            options.allowRegressions = true;
        } else if (arg.rfind("--filter=", 0) == 0) {
            options.filter = arg.substr(9);
        } else if (arg == "--verbose") {
            options.verbose = true;
        } else {
            std::fprintf(stderr, "unknown flag %s\n", arg.c_str());
            return 2;
        }
    }
    std::string root = findRoot();
    std::optional<std::string> shim = readInput(runfile("WR_WPT_REPORT_SHIM", "submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/Tests/WPT/wpt-report.js"));
    std::optional<std::string> skipText = readInput(runfile("WR_WPT_SKIP", "submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/wpt-skip.txt"));
    std::optional<std::string> expectedText = readInput(runfile("WR_WPT_EXPECTATIONS", kExpectationsInSource));
    if (root.empty() || !shim || !skipText || !expectedText) {
        std::fprintf(stderr, "missing input: root '%s', shim %d, skip list %d, expectations %d\n", root.c_str(), bool(shim), bool(skipText), bool(expectedText));
        return 2;
    }
    std::string error;
    std::vector<wr_wpt::SkipEntry> skips;
    std::vector<wr_wpt::Record> expected;
    if (!wr_wpt::parseSkipList(*skipText, &skips, &error) || !wr_wpt::parseExpectations(*expectedText, &expected, &error)) {
        std::fprintf(stderr, "%s\n", error.c_str());
        return 2;
    }
    auto inScope = [&](std::string_view test) { return options.filter.empty() || test.find(options.filter) != std::string_view::npos; };

    std::vector<wr_wpt::Page> pages = wr_wpt::discoverPages(root, kDirs, skips);
    for (const wr_wpt::SkipEntry& skip : skips) {
        std::string file = skip.test.substr(0, skip.test.find_first_of("?#"));
        if (!wr_wpt::readFile(root + "/" + file)) {
            std::printf("warning: wpt-skip.txt names %s, which is not vendored\n", skip.test.c_str());
        }
    }
    wr_wpt::WPTLoader loader(root, *shim);
    std::vector<wr_wpt::Record> actual;
    std::map<std::string, std::string> messages;  // "<test> | <subtest>" -> message
    std::map<std::string, int> statusCounts;
    int ran = 0;
    for (const wr_wpt::Page& page : pages) {
        if (!inScope(page.test)) {
            continue;
        }
        std::printf("RUN %s\n", page.test.c_str());
        std::fflush(stdout);
        PageResult result = runPage(page, loader, options);
        int passed = 0, total = 0;
        for (const wr_wpt::Record& r : result.records) {
            statusCounts[(r.harness ? "harness " : "") + r.status]++;
            if (!r.harness) {
                total++;
                passed += r.status == "PASS";
            }
        }
        std::printf("  %s, %d/%d pass, %.1f CPU ms, %.0f ms virtual, %s\n", result.records[0].status.c_str(), passed, total, result.cpuMs,
                    result.virtualMs, result.end.c_str());
        if (options.verbose || result.records[0].status != "OK") {
            for (size_t i = 0; i < result.diagnostics.size() && i < kMaxDiagnosticLines; i++) {
                std::printf("    %s\n", result.diagnostics[i].c_str());
            }
            if (result.diagnostics.size() > kMaxDiagnosticLines) {
                std::printf("    (%zu more)\n", result.diagnostics.size() - kMaxDiagnosticLines);
            }
        }
        for (const auto& [subtest, message] : result.messages) {
            messages[page.test + " | " + subtest] = message;
        }
        actual.insert(actual.end(), result.records.begin(), result.records.end());
        ran++;
    }

    std::printf("\n%d pages;", ran);
    for (const auto& [status, count] : statusCounts) {
        std::printf(" %s %d;", status.c_str(), count);
    }
    std::printf("\n");
    wr_wpt::Comparison comparison = wr_wpt::compare(expected, actual, inScope);
    auto list = [&](const char* title, const std::vector<std::string>& lines) {
        if (lines.empty()) {
            return;
        }
        std::printf("\n%s (%zu):\n", title, lines.size());
        for (const std::string& line : lines) {
            std::string key = line.substr(0, line.find(": "));
            auto message = messages.find(key);
            std::printf("  %s%s%s\n", line.c_str(), message == messages.end() ? "" : " — ", message == messages.end() ? "" : message->second.substr(0, 300).c_str());
        }
    };
    list("REGRESSIONS", comparison.regressions);
    list("IMPROVEMENTS (update the expectations)", comparison.improvements);
    list("CHANGES (update the expectations)", comparison.changes);

    if (!options.update) {
        std::printf("\n%s\n", comparison.matches() ? "expectations match" : "expectations do not match: run with --update (see the header of this file)");
        return comparison.matches() ? 0 : 1;
    }
    if (!comparison.regressions.empty() && !options.allowRegressions) {
        std::printf("\nrefusing to lower %zu result(s): fix them, or pass --allow-regressions\n", comparison.regressions.size());
        return 1;
    }
    std::vector<wr_wpt::Record> merged;
    for (const wr_wpt::Record& r : expected) {
        if (!inScope(r.test)) {
            merged.push_back(r);
        }
    }
    merged.insert(merged.end(), actual.begin(), actual.end());
    std::string path;
    if (const char* workspace = std::getenv("BUILD_WORKSPACE_DIRECTORY")) {
        path = std::string(workspace) + "/" + kExpectationsInSource;
    } else if (const char* outputs = std::getenv("TEST_UNDECLARED_OUTPUTS_DIR")) {
        path = std::string(outputs) + "/wpt-expectations.txt";
    } else {
        std::fprintf(stderr, "--update needs bazel run (BUILD_WORKSPACE_DIRECTORY) or bazel test outputs\n");
        return 2;
    }
    if (!writeText(path, wr_wpt::formatExpectations(merged))) {
        std::fprintf(stderr, "could not write %s\n", path.c_str());
        return 2;
    }
    std::printf("\nwrote %s\n", path.c_str());
    return 0;
}
